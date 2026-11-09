"""Turns each PDF into the pages the app would send, plus ground truth.

For every PDF in FORMS_DIR this writes OUT_DIR/<name>/:
  pages.json  - what the app uploads: JPEG (long edge <= 1568, q88), size, OCR lines
  page_N.jpg  - the page images (for overlays)
  truth.json  - the PDF's own fillable fields in page pixels, when it has any

Matches lib/features/templates/data/form_capture_service.dart: raster at
150 dpi, shrink to 1568 px, JPEG quality 88, OCR on the shrunk image.

Usage: python3 -I prep.py FORMS_DIR OUT_DIR OCR_BINARY
"""

import base64
import io
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import pypdf
from PIL import Image

MAX_EDGE = 1568


def raster(pdf: Path, tmp: Path) -> list[Path]:
    subprocess.run(
        ["pdftoppm", "-r", "150", "-png", str(pdf), str(tmp / "p")], check=True
    )
    return sorted(tmp.glob("p*.png"), key=lambda p: int(p.stem.split("-")[-1]))


def shrink(png: Path) -> Image.Image:
    im = Image.open(png).convert("RGB")
    scale = min(1.0, MAX_EDGE / max(im.size))
    if scale < 1:
        im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    return im


def truth(pdf: Path, sizes: list[tuple[int, int]]) -> list[dict]:
    """Fillable widgets as [x0,y0,x1,y1] page pixels, with their kind."""
    out = []
    reader = pypdf.PdfReader(str(pdf))
    for i, page in enumerate(reader.pages):
        if i >= len(sizes):
            break
        box = page.cropbox
        pw, ph = float(box.width), float(box.height)
        ox, oy = float(box.left), float(box.bottom)
        w, h = sizes[i]
        sx, sy = w / pw, h / ph
        for a in page.get("/Annots") or []:
            a = a.get_object()
            if a.get("/Subtype") != "/Widget":
                continue
            parent = a.get("/Parent")
            parent = parent.get_object() if parent else {}
            ft = a.get("/FT") or parent.get("/FT")
            name = a.get("/T") or parent.get("/T") or ""
            flags = int(a.get("/Ff") or parent.get("/Ff") or 0)
            if ft == "/Btn" and flags & (1 << 16):  # push button
                continue
            kind = {"/Tx": "text", "/Btn": "checkbox", "/Sig": "signature"}.get(ft, "other")
            x0, y0, x1, y1 = [float(v) for v in a["/Rect"]]
            if abs(x1 - x0) < 2 or abs(y1 - y0) < 2:  # hidden
                continue
            out.append({
                "page": i + 1,
                "name": str(name),
                "kind": kind,
                "box": [
                    round((min(x0, x1) - ox) * sx), round((ph - (max(y0, y1) - oy)) * sy),
                    round((max(x0, x1) - ox) * sx), round((ph - (min(y0, y1) - oy)) * sy),
                ],
            })
    return out


def main(forms_dir: str, out_dir: str, ocr_bin: str) -> None:
    for pdf in sorted(Path(forms_dir).glob("*.pdf")):
        dest = Path(out_dir) / pdf.stem
        if (dest / "pages.json").exists():
            print(f"skip {pdf.stem} (already prepared)")
            continue
        dest.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory() as t:
            pngs = raster(pdf, Path(t))
            pages, sizes = [], []
            for n, png in enumerate(pngs, 1):
                im = shrink(png)
                buf = io.BytesIO()
                im.save(buf, "JPEG", quality=88)
                jpg = dest / f"page_{n}.jpg"
                jpg.write_bytes(buf.getvalue())
                ocr = json.loads(subprocess.run(
                    [ocr_bin, str(jpg)], check=True, capture_output=True
                ).stdout)
                pages.append({
                    "jpegBase64": base64.b64encode(buf.getvalue()).decode(),
                    "width": im.width,
                    "height": im.height,
                    "ocr": ocr,
                })
                sizes.append(im.size)
        (dest / "pages.json").write_text(json.dumps({"pages": pages}))
        try:
            t = truth(pdf, sizes)
        except Exception as e:  # e.g. AES-encrypted PDFs; truth is optional
            print(f"  no truth for {pdf.stem}: {type(e).__name__}")
            t = []
        if t:
            (dest / "truth.json").write_text(json.dumps(t, indent=1))
        print(f"{pdf.stem}: {len(pages)} pages, "
              f"{sum(len(p['ocr']) for p in pages)} OCR lines, {len(t)} truth fields")


if __name__ == "__main__":
    main(*sys.argv[1:4])
