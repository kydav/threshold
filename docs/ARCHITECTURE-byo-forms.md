# Architecture: bring-your-own forms

_Status: PoC shipped in v1.2.0. This describes what exists and the planned changes (marked **Planned**)._

## Goal

An agent turns any paper or PDF buyer agreement into a reusable, signable
template once. Each deal after that is: agent terms, then buyer signs on the
phone, then a stamped PDF with an audit page is delivered. The form's text is never
retyped or re-laid-out; we stamp onto an image of the agent's own form, so the
signed document looks exactly like the original.

## Pipeline

```
 capture ──► prepare ──► map (server) ──► clean ──► review ──► template
                                                                  │
                                       deal terms ◄───────────────┘
                                           │
                                       sign (in person)  ──► render PDF ──► store + deliver
```

### 1. Capture (`form_capture_service.dart`)
- `scan()`: `cunning_document_scanner` (VisionKit / ML Kit document scanner). Gives perspective-corrected, flattened page photos.
- `pickPdf()`: `file_picker` + `Printing.raster`, so each PDF page becomes an image. A blank PDF exported from the brokerage's forms system is the best input: no ink to clean, perfect geometry.

### 2. Prepare
- Bake EXIF orientation, resize so the long edge is at most **1568 px** (`kPageMaxEdge`), JPEG q88.
  1568 is Claude's native vision resolution, so the model, the stored template and the stamping all share **one pixel space**. Boxes never need rescaling.
- On-device OCR (ML Kit text recognition) produces text lines with pixel boxes. The model uses them to anchor field positions to real printed labels, which was the main accuracy win in the prototype.
- **Planned:** OCR moves server-side to Google Cloud Vision (`DOCUMENT_TEXT_DETECTION`) inside `mapFormFields`. Reasons:
  - ML Kit has no arm64 iOS simulator slice;
  - it's better on photos;
  - one less native dependency.

  The callable's input drops `ocr`.

### 3. Map: `mapFormFields` (`functions/src/mapFields.ts`)
- Callable, v2, Node 22, `us-central1`, 300 s timeout, secret `ANTHROPIC_API_KEY`. Unauthenticated calls are rejected.
- Model: **`claude-opus-5`** with adaptive thinking. Mapping happens once per template, so accuracy beats cost (about $0.13 per 3-page form).
- Input: `pages[] = {jpegBase64, width, height, ocr[]}`. The prompt states each image's exact pixel size and asks for pixel coordinates.
- Output (structured `json_schema`):
  - `form_title` and `form_id`;
  - `fields[]`, each with:
    - `id` (stable snake_case, e.g. `buyer_signature_2`);
    - `page`;
    - `section`;
    - `label`;
    - `kind`: `text | date | number | currency | percent | checkbox | signature | initials`;
    - `filled_by`: `agent_once | agent_per_deal | buyer | agent_sign`;
    - `choice_group`: checkboxes that are mutually exclusive;
    - `box`: `[x0,y0,x1,y1]` in px;
    - `currently_filled`: whether this copy already has something written in it.
- **Planned:** after the model returns, snap each box to the nearest printed underline or checkbox square found in the image (horizontal-run detection on a binarized page). This fixes the remaining roughly 20% of loose or clipped boxes.

### 4. Clean (`template_repository.dart` › `cleanPage`)
Lets a *filled* copy become a blank template:
1. Pen ink: pixels where blue clearly dominates (`b > 60 && b − max(r,g) > 18`) turn white, grown 2 px for anti-aliasing. Print is neutral black or grey, so it survives.
2. Each `currently_filled` field's box is whited out, keeping the bottom 4 px so the printed underline stays. Checkboxes are whited inside a 22% inset, so the square outline stays.

### 5. Review (`template_review_screen.dart`)
Page images with color-coded boxes by `filled_by`. Tap a box to edit its label, kind, filler and group; drag to move it. The agent confirms before the template is used. **Planned:** resize handles, add/delete a field, and "agent once" values entered here.

### 6. Template model (`form_template.dart`)
```
FormTemplate { id, title, formId, pages: [TemplatePage{file,width,height}], fields: [TemplateField], createdAt }
TemplateField { id, page, section, label, kind, filledBy, choiceGroup, box: Rect(px), currentlyFilled }
```
Today it's stored on-device at `<app docs>/templates/<id>/template.json` plus `page_N.jpg`.
**Planned:** Firestore `templates/{uid}/items/{id}` (the JSON) plus Storage `templates/{uid}/{id}/page_N.jpg`, with local caching. Rules: read and write only when `request.auth.uid == uid`. Team templates later via `teams/{teamId}/templates`.

### 7. Deal (`template_deal.dart`, `template_deal_screen.dart`)
`TemplateDeal` holds the values for one signing.
- `active(filler)`: fields for a role, in reading order (top to bottom, then left to right on a row). Second-buyer fields are dropped unless `hasBuyer2`. The buyer index comes from the id or label (`_2`, "second buyer").
- `autofill()`: buyer names go into name blanks and today's date into date fields; agent-once fields are untouched.
- `SplitDate`: groups `*_day / *_month / *_year` fields and fills "8th" / "June" / "26". The year is 2 digits when the blank follows a printed "20".

### 8. Sign (`template_sign_screen.dart`)
1. **Review and consent:**
   - the buyer sees the form (later, the approved plain-English summary too);
   - each buyer ticks the ESIGN/UETA electronic-records consent, and the time is recorded.
2. Buyer details: name and email.
3. Initials and signatures per buyer (signature pad), placed into every `initials` / `signature` field for that buyer.
4. Agent signature.
5. Render, save, deliver.

### 9. Render (`template_pdf_service.dart`)
- Each page is the cleaned background image; values are stamped into boxes. Text is fitted to the box height; checkboxes get an ✓; ink is PNG.
- Pages are rendered once alone to compute a **SHA-256** of exactly the signed content.
- A **signature certificate** page is appended with:
  - the agreement id;
  - the template title;
  - each signer's name, role and email, with consent and signing times;
  - the fingerprint.
- Output goes into the existing `AgreementRepository` (local JSON + PDF) and `DeliveryService` → `sendAgreementEmail` (SendGrid). The existing retry-on-reconnect path covers offline signings.

## Security and privacy
- Page images go to `mapFormFields` once per template. They're not retained server-side: the function is stateless and Anthropic API data isn't used for training. Signed agreements stay on-device until emailed.
- Filled sample copies contain real client PII. **Never commit test captures or mapping outputs**; `tool/form_map/out*` is gitignored. Delete local copies after testing.
- Copyright: Threshold never ships association forms. Agents upload copies they're licensed to use. Built-in forms are only those that are public (state commission forms).

## Remote signing (planned, Phase B)
- `signingRequests/{token}`: template snapshot, values so far, signer email, expiry, status. The token is 128-bit random and single use.
- A web signer at `auaha.app/threshold/sign/<token>` (static page + callable functions `getSigningRequest` / `completeSigning`). The server renders the final PDF with the same layout code, ported to TS (`pdf-lib`), or the app finalizes it when it next opens.
- The audit page adds IP address and user agent for remote signers.

## Costs
- Mapping: about $0.10–0.15 per template (Opus, once).
- Cloud Vision OCR: about $1.50 per 1,000 pages; the first 1,000 a month are free.
- Plain-English summary: one call per template, under $0.05.
- Everything per deal is on-device and free.
