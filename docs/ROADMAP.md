# Threshold roadmap

_Last updated 2026-10-30._

## The shift: from "our forms in 4 states" to "your form, any state"

Threshold today ships hand-built wizards for a few state forms:
- Colorado BC60;
- Louisiana, Oklahoma and Wisconsin through the generic flow.

Every new state means sourcing a form and writing a screen. Many state forms
(Utah's UAR forms, for example) are copyrighted and members-only, so we can't
ship them anyway.

**Bring your own form (BYO)** turns that around. The agent scans or uploads the
buyer agreement their brokerage already uses:
1. Threshold maps its fields once (Claude, server-side).
2. The agent checks the map and fills in the parts that never change.
3. From then on, every buyer signs that exact form on the agent's phone in
   about two minutes, at the door.

This makes Threshold usable in **all 50 states on day one**, without us
redistributing anyone's copyrighted form.

---

## Where BYO forms stand (v1.2.0, branch `poc-camera`, merged to `main` at `edaf9c3`)

Built and working (see `docs/ARCHITECTURE-byo-forms.md`):

- [x] Capture: document scanner (photos, flattened) or PDF upload, rasterized.
- [x] Page prep: resize to at most 1568 px; on-device ML Kit OCR gives text-line anchors.
- [x] `mapFormFields` Cloud Function (claude-opus-5, structured output). Deployed to `threshold-24c99`; the ANTHROPIC_API_KEY secret is set. It returns:
  - each field's id;
  - its label;
  - its kind (text, date, checkbox, signature, initials, …);
  - **who fills it** (agent once, agent per deal, buyer, agent signature);
  - its choice group;
  - its pixel box.
- [x] Clean a filled copy: blue-ink removal plus white-out of already-filled boxes.
- [x] Review screen: tap a field to edit it; drag to move its box.
- [x] Deal screen for the agent's per-deal terms; autofill for buyer names and today's date; day/month/year date splits.
- [x] Guided signing:
  - review and ESIGN/UETA consent;
  - buyer details;
  - initials and signature per buyer, with optional buyer 2;
  - agent signature;
  - PDF with a signature-certificate page and SHA-256 fingerprint;
  - saved with the existing agreements and emailed through the existing delivery path.
- [x] "My forms" card on the dashboard; templates stored on-device.

Known gaps from the PoC:
- [ ] **Swap on-device ML Kit OCR for Google Cloud Vision inside `mapFormFields`.** ML Kit has no arm64 simulator slice, which blocks simulator builds. It also makes the app heavier, and server-side OCR is better on photos. The app would send only page JPEGs; the function OCRs, then maps. Remove `google_mlkit_text_recognition` afterwards.
- [ ] Box accuracy is about 80% on phone photos. The misses:
  - tight signature boxes;
  - the year in split dates;
  - boxes clipping printed text.

  Add **snap to printed lines**: detect the nearest horizontal underline or checkbox square in the cleaned image and fit the box to it.
- [ ] Box **resize** handles in review (only move exists).
- [ ] A blank PDF exported from Lone Wolf / zipForm / Dotloop is the best input. Make "Upload the blank PDF" the primary path, with scanning as the fallback.
- [ ] Device test on a real phone (a pilot agent's UAR Form 6), plus test the email after the Node 22 move.

---

## Phase A: Finish BYO for a real launch (about 2 weeks)

1. **Cloud Vision OCR** swap, described above.
2. **Snap-to-lines and resize handles.**
3. **Templates in the cloud:**
   - Store `templates/{uid}/{id}` in Firestore, with pages in Storage at `templates/{uid}/{id}/page_N.jpg`.
   - Sync across devices and survive reinstalls.
   - Rules: the owner only.
4. **Plain-English key terms** per template, so buyers understand what they're signing:
   - Claude drafts a 5–8 bullet summary (term length, compensation, exclusivity, protection period, termination, dispute resolution).
   - The agent edits and approves it once.
   - It's shown on the buyer's review step, filled with this deal's values.
5. **Remove the state gate for BYO users.** Today `_FormRouter` blocks any state outside `kSupportedStates`. New behavior:
   - any state can sign up;
   - agents in states without a built-in form land on "Add your buyer agreement";
   - the built-in states keep their wizards and also get BYO.
6. **The built-in forms become templates.** The CO / LA / OK / WI flows stay, but they're presented as "Starter templates" in the same list, so there's one mental model.
7. **Paywall:**
   - Free: 1 custom template and 2 signed agreements.
   - Pro: unlimited templates and signings.
   - Mapping costs about $0.13 per template, so it's safe to include in Pro.
8. **Audit and compliance pass:**
   - consent text reviewed;
   - certificate page includes device/app version and IP where available;
   - the signed PDF is immutable once sent;
   - a "void" path.

## Phase B: Signing beyond the doorstep (about 2–3 weeks)

- **Remote signing:** a link texted or emailed to the buyer opens a web signer (Flutter web or a small static page on auaha.app). Buyer signs and the agent is notified. Token-gated, expiring, single use.
- **Dashboard and reminders:** expiring agreements (end date from the template's date fields), unsigned remote requests, push reminders.
- **Brokerage delivery:** auto-send a copy to the brokerage's compliance inbox, set once in the profile.
- **Team templates:** a broker shares a template with every agent in the office, the main path to brokerage sales.
- **Other forms with the same engine:** the BYO pipeline isn't buyer-agreement specific. Next: the **listing agreement**, the **buyer compensation agreement / commission offer**, and **showing/visitor agreements** for open houses (pairs with the existing open-house content).

## Phase C: Platform hygiene

- iOS: remove ML Kit after the Vision swap so simulator builds work again.
- Move `sendAgreementEmail` to Node 22 on the next functions deploy and re-test email.
- Oklahoma SB 1217 (effective **Nov 1, 2026**): no BBSA as a condition of *viewing*. Update the Oklahoma copy and the app's OK flow wording to "before making an offer".
- Watch for UAR / state association rules on e-signature of their forms. Agents uploading their own licensed copy is the safe model; never ship a copyrighted form built in.

---

## Launch plan: "Threshold now works with your form, in any state"

### App Store / Play listing
- [ ] New subtitle (30 chars): **"Buyer agreements, any form"**.
- [ ] Rewrite the description lead around BYO: "Scan your brokerage's buyer agreement once. Every buyer signs it on your phone in two minutes." Keep compliance keywords (buyer agreement, buyer broker agreement, BBA, NAR, e-sign).
- [ ] Keywords: add *esign, scan, any state, realtor forms, buyer rep, docusign alternative*; drop state names that only matter on the web.
- [ ] Screenshots (new set of 6):
  1. scan a form;
  2. fields mapped with colored boxes;
  3. agent terms;
  4. buyer signing at the door;
  5. certificate page;
  6. "Works in all 50 states".
- [ ] App Preview video (15–30s): scan → map → sign.
- [ ] What's New for 1.3: the BYO announcement.

### auaha.app/threshold
- [ ] Hero rewrite: "Your buyer agreement. Signed at the door." Secondary line: "Any form, any state. Scan it once and Threshold does the rest."
- [ ] New section "How it works", 3 steps with screenshots.
- [ ] New page `/threshold/bring-your-own-form`: how mapping works, privacy (forms are processed to map fields and stored in your account; we don't redistribute your brokerage's forms), FAQ.
- [ ] Update `/threshold/buyer-broker-agreement-by-state`: every state now gets a "Use your state's form with Threshold" CTA rather than "coming soon".
- [ ] **State SEO pages: go from 4 states to 50.**
  - Extend `scripts/states.json` with a `byo: true` flavor of the template. Pages don't need a built-in form; they name the state association's form ("Utah: UAR Exclusive Buyer-Broker Agreement"), the commission/regulator, and what changed in 2024.
  - Each page's CTA: "Scan your [Form name] into Threshold".
  - Run `npm run gen:states`; update `sitemap.xml`.
  - Start with the 10 biggest agent markets: CA, TX, FL, NY, GA, NC, AZ, UT, WA, IL. Then the rest.
  - Utah gets its own page now that UAR members can bring Form 6.
- [ ] Comparison page: "Threshold vs DocuSign / Dotloop for buyer agreements": faster at the door, no envelope setup, works offline.
- [ ] Structured data: `SoftwareApplication` + `FAQPage` on the new pages.

### Announcement
- [ ] Email to existing users: "Threshold now works with your own buyer agreement."
- [ ] A short demo video (the same as the App Preview) for Facebook realtor groups, Instagram Reels and TikTok. **threshold-signal** surfaces the Reddit threads (r/RealEstate, r/realtors) where agents complain about buyer-agreement friction; answer them.
- [ ] The pilot agent's brokerage (Kyler's mom): one office, a team template, a testimonial quote for the site.
- [ ] Local association outreach (Utah first): a 10-minute demo at an office meeting; offer a free month of Pro to the office.
- [ ] Press: Inman / RealTrends tip lines with a "small app solves the buyer-agreement-at-the-door problem" angle, plus Product Hunt.

### Order
1. Phase A items 1–5, then TestFlight to the pilot agent (Kyler's mom) plus 3–5 agents (2 weeks).
2. Fix what they hit, then store listing + website + the first 10 state pages (1 week).
3. Release 1.3 and the announcement.
4. Phase B in order of what pilot agents ask for. Remote signing is likely first.
