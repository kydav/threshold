# Form import bench

Runs buyer-broker forms through the same mapping request the app uses
(`functions/src/mapFields.ts` → `mapRequest`) and scores the result.

```sh
tools/form_bench/bench.sh ~/Development/threshold-test-forms
```

- **prep.py** renders each PDF like the app (150 dpi, 1568 px, JPEG q88),
  OCRs it with Apple Vision (`ocr.swift`), and pulls the PDF's own fillable
  fields as ground truth when it has them.
- **run.mjs** calls Claude once per form (cached: delete `map.json` to rerun).
- **score.py** writes `REPORT.md` (coverage of real fields, missing
  essentials, boxes over printed words, broken links) and `overlay_N.png`
  per page: blue = agent per deal, pink = buyer, orange = agent signature,
  grey = agent profile, thin green = the PDF's real fields.

Keep the forms and results out of this repo: they're association-copyrighted.
