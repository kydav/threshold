"""Prototype: map the fillable fields of a buyer-broker agreement from photos.

Sends every page image to Claude in one request, gets back a field map as
JSON (each field's page, box, kind and who fills it), then draws the boxes on
each page so accuracy can be judged by eye. Also writes a "blanked" preview
that paints over every field that already holds handwriting or typing, to show
that a filled copy can be turned back into a template.

    export ANTHROPIC_API_KEY=...
    .venv/bin/python map_form.py page1.jpg page2.jpg page3.jpg

Outputs go to ./out/: field_map.json, pageN_fields.png, pageN_blanked.png.
"""

import base64
import io
import json
import sys
from pathlib import Path

import anthropic
from PIL import Image, ImageDraw, ImageFont, ImageOps

MODEL = "claude-opus-5"
# Long edge sent to the model. Field boxes come back in 0-1000 coordinates
# relative to each page, so they map onto the full-resolution photo too.
MAX_EDGE = 1568  # larger images are downscaled server-side anyway

KINDS = ["text", "date", "number", "currency", "percent", "checkbox",
         "signature", "initials"]
FILLERS = ["agent_once", "agent_per_deal", "buyer", "agent_sign"]

SCHEMA = {
    "type": "object",
    "properties": {
        "form_title": {"type": "string"},
        "form_id": {"type": "string"},
        "fields": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "id": {"type": "string"},
                    "page": {"type": "integer"},
                    "section": {"type": "string"},
                    "label": {"type": "string"},
                    "kind": {"type": "string", "enum": KINDS},
                    "filled_by": {"type": "string", "enum": FILLERS},
                    "choice_group": {"type": "string"},
                    "box": {
                        "type": "array",
                        "items": {"type": "integer"},
                    },
                    "currently_filled": {"type": "boolean"},
                },
                "required": ["id", "page", "section", "label", "kind",
                             "filled_by", "choice_group", "box",
                             "currently_filled"],
                "additionalProperties": False,
            },
        },
    },
    "required": ["form_title", "form_id", "fields"],
    "additionalProperties": False,
}

PROMPT = """These are photos of every page of a real estate buyer-broker \
agreement, in order (image 1 = page 1). A real estate agent will use this \
form as a reusable template: our app fills in the blanks and collects \
e-signatures, so we need a precise map of every place someone writes, checks \
a box, initials or signs.

For each field return:
- id: short snake_case name, unique across the form (e.g. buyer_name_1, \
end_date_month, fee_percent, buyer_initials_p2).
- page: 1-based page number.
- section: the form's section number or heading it belongs to ("Header", \
"1.2", "Signatures", "Footer").
- label: what the field is, in plain words.
- kind: one of text, date, number, currency, percent, checkbox, signature, \
initials.
- filled_by: agent_once (the agent's own details that never change, such as \
the brokerage and agent name), agent_per_deal (terms the agent sets for each \
buyer, such as the end date, fee or area), buyer (anything the buyer writes, \
initials, signs or dates), agent_sign (the agent's or broker's signature and \
its date).
- choice_group: for checkboxes where only one of several may be checked, the \
same group name on each option (e.g. "property_scope"); empty string otherwise.
- box: [x0, y0, x1, y1] — the rectangle where the value is written, in \
PIXELS of that page image as you received it (0,0 = top-left; each image's \
exact size is stated just before it). Cover the blank line or box itself, including any \
space a value would occupy, not the printed label next to it. The photos are \
handheld, so pages are slightly rotated and the background is visible: \
measure against the photo, not an idealised page.
- currently_filled: true if this copy already has something written, typed or \
checked in that spot.

Include every blank, including ones this copy left empty (for example a \
second buyer's signature line or an unused property line). Split a date \
written as separate day / month / year blanks into separate fields. Do not \
include printed text that never changes."""


def load_page(path: Path) -> Image.Image:
    img = ImageOps.exif_transpose(Image.open(path)).convert("RGB")
    return img


def to_b64(img: Image.Image) -> str:
    small = img.copy()
    small.thumbnail((MAX_EDGE, MAX_EDGE))
    buf = io.BytesIO()
    small.save(buf, format="JPEG", quality=90)
    return base64.standard_b64encode(buf.getvalue()).decode()


def map_fields(pages: list[Image.Image]) -> dict:
    client = anthropic.Anthropic()
    content = []
    for n, img in enumerate(pages, start=1):
        small = img.copy()
        small.thumbnail((MAX_EDGE, MAX_EDGE))
        content.append({"type": "text",
                        "text": f"Page {n}: {small.width}x{small.height} pixels"})
        content.append({
            "type": "image",
            "source": {"type": "base64", "media_type": "image/jpeg",
                       "data": to_b64(img)},
        })
    content.append({"type": "text", "text": PROMPT})

    with client.beta.messages.stream(
        model=MODEL,
        max_tokens=64000,
        thinking={"type": "adaptive"},
        output_config={"effort": "high",
                       "format": {"type": "json_schema", "schema": SCHEMA}},
        betas=["server-side-fallback-2026-07-01"],
        fallbacks="default",
        messages=[{"role": "user", "content": content}],
    ) as stream:
        response = stream.get_final_message()

    if response.stop_reason == "refusal":
        sys.exit(f"Refused: {response.stop_details}")
    if response.stop_reason == "max_tokens":
        sys.exit("Ran out of output tokens; field map is incomplete.")
    text = next(b.text for b in response.content if b.type == "text")
    usage = response.usage
    print(f"model={response.model} in={usage.input_tokens} "
          f"out={usage.output_tokens}")
    return json.loads(text)


COLORS = {
    "agent_once": (52, 120, 246),      # blue
    "agent_per_deal": (245, 158, 11),  # amber
    "buyer": (22, 163, 74),            # green
    "agent_sign": (147, 51, 234),      # purple
}


def to_px(box: list[int], img: Image.Image) -> tuple[int, int, int, int]:
    # Boxes are in the pixel space of the downscaled image the model saw.
    small = img.copy()
    small.thumbnail((MAX_EDGE, MAX_EDGE))
    sx, sy = img.width / small.width, img.height / small.height
    x0, y0, x1, y1 = box
    return (int(x0 * sx), int(y0 * sy), int(x1 * sx), int(y1 * sy))


def draw(pages: list[Image.Image], fmap: dict, out: Path) -> None:
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 34)
    except OSError:
        font = ImageFont.load_default()
    for i, img in enumerate(pages, start=1):
        fields = [f for f in fmap["fields"] if f["page"] == i]

        annotated = img.copy()
        d = ImageDraw.Draw(annotated)
        for f in fields:
            if len(f["box"]) != 4:
                continue
            color = COLORS.get(f["filled_by"], (220, 38, 38))
            x0, y0, x1, y1 = to_px(f["box"], img)
            d.rectangle((x0, y0, x1, y1), outline=color, width=6)
            d.text((x0, max(0, y0 - 38)), f["id"], fill=color, font=font)
        annotated.save(out / f"page{i}_fields.png")

        blanked = img.copy()
        d = ImageDraw.Draw(blanked)
        for f in fields:
            if f["currently_filled"] and len(f["box"]) == 4:
                d.rectangle(to_px(f["box"], img), fill=(255, 255, 255))
        blanked.save(out / f"page{i}_blanked.png")
        print(f"page {i}: {len(fields)} fields")


def main() -> None:
    paths = [Path(p) for p in sys.argv[1:]]
    if not paths:
        sys.exit(__doc__)
    out = Path(__file__).parent / "out"
    out.mkdir(exist_ok=True)
    pages = [load_page(p) for p in paths]
    fmap = map_fields(pages)
    (out / "field_map.json").write_text(json.dumps(fmap, indent=2))
    print(f"{fmap['form_title']} ({fmap['form_id']}): "
          f"{len(fmap['fields'])} fields")
    draw(pages, fmap, out)


if __name__ == "__main__":
    main()
