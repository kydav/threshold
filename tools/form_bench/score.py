"""Scores each field map and draws it over the pages.

For every OUT_DIR/<name>/map.json:
  - Coverage (only forms with fillable fields, truth.json): how many of the
    PDF's own fields have a mapped box on them, by kind.
  - Checks every form gets: the fields a buyer agreement can't do without,
    boxes off the page or over printed words, broken links between fields.
  - overlay_N.png: each box drawn on its page, colored by who fills it.
Writes OUT_DIR/REPORT.md.

Usage: python3 -I score.py OUT_DIR
"""

import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

COLORS = {
    "agent_once": (120, 120, 120),
    "agent_per_deal": (31, 111, 235),
    "buyer": (214, 51, 132),
    "agent_sign": (230, 126, 34),
}
NEED = {
    "buyer signature": lambda f: f["kind"] == "signature" and f["filled_by"] == "buyer",
    "buyer name": lambda f: f["role"] in ("buyer_names", "buyer1_name"),
    "sign date": lambda f: f["role"] == "sign_date",
    "agent/broker signature": lambda f: f["kind"] == "signature" and f["filled_by"] == "agent_sign",
    "end date / term": lambda f: f["role"] == "end_date" or "term" in f["group_title"].lower()
    or "how long" in f["group_title"].lower(),
}


def area(b):
    return max(0, b[2] - b[0]) * max(0, b[3] - b[1])


def inter(a, b):
    return area([max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3])])


def hits(model_box, truth_box):
    """A mapped box counts for a real field when they clearly overlap."""
    i = inter(model_box, truth_box)
    if not i:
        return False
    return i / min(area(model_box) or 1, area(truth_box) or 1) >= 0.4


def score(dirp: Path) -> dict:
    m = json.loads((dirp / "map.json").read_text())
    pages = json.loads((dirp / "pages.json").read_text())["pages"]
    fields = m["fields"]
    ids = {f["id"] for f in fields}
    r = {"name": dirp.name, "title": m["form_title"], "pages": len(pages),
         "fields": len(fields), "problems": []}

    run = dirp / "run.json"
    if run.exists():
        r.update(json.loads(run.read_text()))

    r["kinds"] = {}
    for f in fields:
        r["kinds"][f["kind"]] = r["kinds"].get(f["kind"], 0) + 1

    missing = [k for k, test in NEED.items() if not any(test(f) for f in fields)]
    if missing:
        r["problems"].append("missing: " + ", ".join(missing))

    dup = len(fields) - len(ids)
    if dup:
        r["problems"].append(f"{dup} duplicate ids")

    bad_links = [f["id"] for f in fields
                 if (f["depends_on"] and f["depends_on"] not in ids)
                 or (f["continues"] and f["continues"] not in ids)]
    if bad_links:
        r["problems"].append(f"{len(bad_links)} links to unknown fields ({', '.join(bad_links[:3])})")

    off, covers = [], []
    for f in fields:
        b, p = f["box"], f["page"]
        if len(b) != 4 or not 1 <= p <= len(pages):
            off.append(f["id"])
            continue
        pg = pages[p - 1]
        if b[0] < 0 or b[1] < 0 or b[2] > pg["width"] or b[3] > pg["height"] or b[2] <= b[0] or b[3] <= b[1]:
            off.append(f["id"])
        if f["kind"] in ("signature", "initials"):
            continue  # these sit on signature lines with printed captions
        for line in pg["ocr"]:
            lb = line["box"]
            if inter(b, lb) > 0.5 * (area(lb) or 1) and len(line["text"]) > 3 \
                    and not re.fullmatch(r"[_\s.:$%/()-]+", line["text"]):
                covers.append(f["id"])
                break
    if off:
        r["problems"].append(f"{len(off)} boxes off the page ({', '.join(off[:3])})")
    if covers:
        r["problems"].append(f"{len(covers)} boxes over printed words ({', '.join(covers[:4])})")

    placeholders = set()
    for s in m["summary"]:
        placeholders |= set(re.findall(r"\{(\w+)\}", s["text"]))
    date_bases = {re.sub(r"_(day|month|year)$", "", i) + "_date" for i in ids} | \
                 {re.sub(r"_(day|month|year)$", "", i) for i in ids}
    unknown = sorted(p for p in placeholders if p not in ids and p not in date_bases)
    if unknown:
        r["problems"].append(f"summary uses unknown fields: {', '.join(unknown)}")

    tp = dirp / "truth.json"
    if tp.exists():
        truth = json.loads(tp.read_text())
        found = [t for t in truth
                 if any(f["page"] == t["page"] and hits(f["box"], t["box"]) for f in fields)]
        r["truth"] = len(truth)
        r["found"] = len(found)
        by_kind = {}
        for t in truth:
            k = by_kind.setdefault(t["kind"], [0, 0])
            k[1] += 1
            if t in found:
                k[0] += 1
        r["by_kind"] = by_kind
        r["missed"] = [t["name"] for t in truth if t not in found]
        extra = [f["id"] for f in fields
                 if not any(f["page"] == t["page"] and hits(f["box"], t["box"]) for t in truth)]
        r["extra"] = extra

    draw_overlays(dirp, fields, pages, json.loads(tp.read_text()) if tp.exists() else [])
    return r


def draw_overlays(dirp, fields, pages, truth):
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 13)
    except OSError:
        font = ImageFont.load_default()
    for n in range(1, len(pages) + 1):
        im = Image.open(dirp / f"page_{n}.jpg").convert("RGB")
        d = ImageDraw.Draw(im, "RGBA")
        for t in truth:
            if t["page"] == n:
                d.rectangle(t["box"], outline=(0, 170, 0, 200), width=1)
        for f in fields:
            if f["page"] != n or len(f["box"]) != 4:
                continue
            c = COLORS.get(f["filled_by"], (0, 0, 0))
            d.rectangle(f["box"], outline=c + (255,), fill=c + (40,), width=2)
            d.text((f["box"][0] + 2, f["box"][1] - 14), f["id"], fill=c + (255,), font=font)
        im.save(dirp / f"overlay_{n}.png")


def report(rows, out: Path):
    L = ["# Form import bench", "",
         "| Form | Pages | Fields | Coverage of real fields | Problems | Time | Cost |",
         "|---|---|---|---|---|---|---|"]
    for r in rows:
        cov = f"{r['found']}/{r['truth']} ({100 * r['found'] // max(r['truth'], 1)}%)" if "truth" in r else "—"
        L.append(f"| {r['name']} | {r['pages']} | {r['fields']} | {cov} | "
                 f"{len(r['problems']) or 'none'} | {r.get('seconds', 0):.0f}s | ${r.get('cost_usd', 0):.2f} |")
    total = sum(r.get("cost_usd", 0) for r in rows)
    L += ["", f"Total cost: ${total:.2f}", ""]
    for r in rows:
        L += [f"## {r['name']}", f"*{r['title']}* · {r['kinds']}", ""]
        for p in r["problems"]:
            L.append(f"- {p}")
        if "by_kind" in r:
            L.append("- coverage by kind: " + ", ".join(
                f"{k} {v[0]}/{v[1]}" for k, v in r["by_kind"].items()))
            if r["missed"]:
                L.append(f"- missed real fields: {', '.join(r['missed'][:15])}"
                         + (" …" if len(r["missed"]) > 15 else ""))
            if r["extra"]:
                L.append(f"- mapped with no real field under it: {len(r['extra'])} "
                         f"({', '.join(r['extra'][:8])})")
        L.append("")
    out.write_text("\n".join(L))


if __name__ == "__main__":
    root = Path(sys.argv[1])
    rows = [score(d) for d in sorted(root.iterdir()) if (d / "map.json").exists()]
    report(rows, root / "REPORT.md")
    print((root / "REPORT.md").read_text())
