# Form import bench

Runs buyer-broker forms through the same reading the app uses
(`functions/src/mapFields.ts` → `mapPacket`, which splits packets over 12
pages into parts) and the same snapping to the PDF's own fields
(`functions/src/pdfFields.ts`), then scores the result.

```sh
tools/form_bench/bench.sh ~/Development/threshold-test-forms
```

- **prep.py** renders each PDF like the app (150 dpi, 1568 px, JPEG q88),
  OCRs it with Apple Vision (`ocr.swift`), and pulls the PDF's own fillable
  fields as ground truth when it has them.
- **run.mjs** reads each form with Claude (cached: delete `map.json` to rerun).
- **snap.mjs** moves boxes onto the PDF's fillable fields like the server
  and prints how close the boxes were before and after. No API cost: run it
  alone after changing `pdfFields.ts`.
- **score.py** writes `REPORT.md` (coverage of real fields, box fit, missing
  essentials, boxes over printed words, broken links) and `overlay_N.png`
  per page: blue = agent per deal, pink = buyer, orange = agent signature,
  grey = agent profile, thin green = the PDF's real fields.

Keep the forms and results out of this repo: they're association-copyrighted.
