"""Prototype v2: field mapping anchored by OCR, mirroring functions/src/mapFields.ts.

Same as map_form.py, but each page is sent with the printed text found by
on-device OCR (macOS Vision here, the same engine as iOS; ML Kit on Android)
and its pixel boxes, so the model can place fields relative to real words.

    ANTHROPIC_API_KEY=$(cat ~/.anthropic_key) .venv/bin/python map_form_v2.py p1.jpg p2.jpg p3.jpg

Outputs go to ./out/ (same files as map_form.py).
"""

import io
import json
import re
import sys
from pathlib import Path

import anthropic
import Quartz
import Vision
from Foundation import NSData

from map_form import MAX_EDGE, SCHEMA, draw, load_page, to_b64

MODEL = "claude-opus-5"

# Keep in sync with PROMPT in functions/src/mapFields.ts.
TS_SOURCE = Path(__file__).parents[2] / "functions/src/mapFields.ts"
PROMPT = (re.search(r"const PROMPT = `(.*?)`;", TS_SOURCE.read_text(), re.S)
          .group(1).replace("\\\n", "").replace('\\"', '"'))


def ocr_lines(jpeg: bytes, width: int, height: int) -> list[dict]:
    data = NSData.dataWithBytes_length_(jpeg, len(jpeg))
    handler = Vision.VNImageRequestHandler.alloc().initWithData_options_(data, None)
    request = Vision.VNRecognizeTextRequest.alloc().init()
    request.setRecognitionLevel_(Vision.VNRequestTextRecognitionLevelAccurate)
    request.setUsesLanguageCorrection_(True)
    ok, err = handler.performRequests_error_([request], None)
    if not ok:
        raise RuntimeError(err)
    lines = []
    for obs in request.results() or []:
        text = obs.topCandidates_(1)[0].string()
        bb = obs.boundingBox()  # normalised, origin bottom-left
        x0 = bb.origin.x * width
        x1 = (bb.origin.x + bb.size.width) * width
        y1 = (1 - bb.origin.y) * height
        y0 = (1 - bb.origin.y - bb.size.height) * height
        lines.append({"text": text,
                      "box": [round(x0), round(y0), round(x1), round(y1)]})
    return lines


def main() -> None:
    paths = [Path(p) for p in sys.argv[1:]]
    if not paths:
        sys.exit(__doc__)
    out = Path(__file__).parent / "out"
    out.mkdir(exist_ok=True)
    pages = [load_page(p) for p in paths]

    content = []
    for n, img in enumerate(pages, start=1):
        small = img.copy()
        small.thumbnail((MAX_EDGE, MAX_EDGE))
        buf = io.BytesIO()
        small.save(buf, format="JPEG", quality=90)
        lines = ocr_lines(buf.getvalue(), small.width, small.height)
        print(f"page {n}: {len(lines)} OCR lines")
        ocr = "\n".join(f"{json.dumps(l['text'])} {json.dumps(l['box'])}"
                        for l in lines)
        content.append({"type": "text",
                        "text": f"Page {n}: {small.width}x{small.height} pixels. "
                                f"OCR lines:\n{ocr}"})
        content.append({"type": "image",
                        "source": {"type": "base64", "media_type": "image/jpeg",
                                   "data": to_b64(img)}})
    content.append({"type": "text", "text": PROMPT})

    client = anthropic.Anthropic()
    with client.beta.messages.stream(
        model=MODEL, max_tokens=64000, thinking={"type": "adaptive"},
        output_config={"effort": "high",
                       "format": {"type": "json_schema", "schema": SCHEMA}},
        betas=["server-side-fallback-2026-07-01"], fallbacks="default",
        messages=[{"role": "user", "content": content}],
    ) as stream:
        response = stream.get_final_message()
    if response.stop_reason in ("refusal", "max_tokens"):
        sys.exit(f"Stopped: {response.stop_reason}")
    fmap = json.loads(next(b.text for b in response.content if b.type == "text"))
    print(f"in={response.usage.input_tokens} out={response.usage.output_tokens}; "
          f"{len(fmap['fields'])} fields")
    (out / "field_map.json").write_text(json.dumps(fmap, indent=2))
    draw(pages, fmap, out)


if __name__ == "__main__":
    main()
