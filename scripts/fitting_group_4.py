#!/usr/bin/env python3
"""Generate source-traced Group 4 fitting SVGs and local review artifacts.

The PDF places one embedded source image across PDF pages 18 and 19. Extracting
that image directly preserves the fittings which cross the displayed page break.
The PDF labels fittings only by number, so the names below are descriptive aids,
not transcriptions of official fitting names.
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import tempfile
from pathlib import Path
from xml.sax.saxutils import escape

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
PDF = ROOT / "Public/files/ManD.Groups.pdf"
OUT = ROOT / "Public/images/fittings/group-4"
REFS = ROOT / "Public/images/fittings/references/group-4"
DOC = ROOT / "docs/group-4-review.md"

# id, equivalent length, inferred display name, source-art crop (left, top,
# right, bottom). Coordinates are in the 948 x 1231 embedded source image.
ITEMS = [
    ("4A", 30, "Radius boot with rectangular outlet", (115, 230, 195, 310)),
    ("4B", 35, "Radius boot with extended top transition", (245, 232, 335, 310)),
    ("4C", 60, "Low-profile radius boot with top collar", (385, 236, 480, 310)),
    ("4D", 55, "Horizontal boot with round throat transition", (520, 238, 635, 308)),
    ("4E", 70, "Horizontal boot with tapered throat", (675, 236, 780, 308)),
    ("4F", 45, "Radius boot with side extension", (115, 332, 210, 408)),
    ("4G", 80, "Angled boot to round outlet", (275, 330, 350, 410)),
    ("4H", 50, "Tapered boot to round outlet", (405, 338, 490, 408)),
    ("4I", 10, "Compact round-to-rectangular transition", (555, 338, 620, 408)),
    ("4J", 30, "Angled boot to round outlet with smooth throat", (690, 330, 790, 410)),
    ("4K", 30, "Angled boot to round outlet with lined throat", (115, 434, 205, 508)),
    ("4L", 80, "Deep angled boot to round outlet with lined throat", (240, 434, 330, 508)),
    ("4M", 20, "Long rectangular offset transition", (355, 434, 440, 508)),
    ("4N", 45, "Rectangular offset with inset throat", (480, 434, 545, 508)),
    ("4O", 20, "Pitched rectangular boot", (585, 434, 660, 508)),
    ("4P", 10, "Tapered rectangular boot", (710, 434, 785, 508)),
    ("4Q", 50, "Rectangular-to-round side transition", (115, 535, 200, 612)),
    ("4R", 20, "Rectangular-to-round vertical transition", (240, 535, 310, 612)),
    ("4S", 20, "Rectangular-to-round tapered transition", (360, 535, 435, 612)),
    ("4T", 20, "Elongated rectangular-to-round boot", (475, 528, 540, 615)),
    ("4U", 20, "Offset rectangular-to-round boot", (590, 528, 660, 615)),
    ("4V", 60, "Rectangular collar on round duct", (710, 540, 805, 608)),
    ("4W", 35, "Ceiling boot with bell-mouth collar", (120, 642, 205, 712)),
    ("4X", 35, "Ceiling boot with straight collar", (240, 642, 320, 712)),
    ("4Y", 35, "Rectangular ceiling register boot", (355, 642, 440, 715)),
    ("4Z", 60, "Square grille boot to round branch", (470, 638, 540, 715)),
    ("4AA", 35, "Tapered square ceiling boot", (585, 642, 660, 715)),
    ("4AB", 90, "Angled square boot with round branch", (710, 638, 790, 718)),
    ("4AC", 100, "Stack head with curved side outlet", (125, 748, 200, 825)),
    ("4AD", 60, "Segmented elbow on rectangular stack", (250, 742, 315, 825)),
    ("4AE", 55, "Segmented elbow on flange", (365, 742, 435, 825)),
    ("4AF", 50, "Rectangular register boot with side outlet", (475, 748, 550, 820)),
    ("4AG", 60, "Split transition with round branches", (590, 748, 680, 822)),
    ("4AH", 60, "Rectangular stack head with grille face", (710, 748, 805, 822)),
    ("4AI", 20, "Rectangular stack head with framed face", (120, 858, 205, 935)),
    ("4AJ", 25, "Boot with flexible round branch", (240, 855, 330, 938)),
    ("4AK", 55, "Low rectangular stack head with round branch", (355, 858, 445, 930)),
    ("4AL", 70, "Angled stack head with inset opening", (470, 852, 565, 938)),
    ("4AM", 70, "Tapered stack head with front opening", (585, 858, 675, 935)),
    ("4AN", 70, "Tapered stack head with stepped opening", (705, 852, 790, 935)),
    ("4AO", 40, "Straight wall stack offset", (135, 958, 190, 1052)),
    ("4AP", 40, "Stepped wall stack offset", (245, 958, 305, 1052)),
    ("4AQ", 10, "Plain rectangular stack-head turn", (350, 958, 445, 1048)),
    ("4AR", 70, "Rectangular stack-head turn with raised collar", (465, 958, 555, 1048)),
]

# Non-overlapping source cells used for review crops. These retain the original
# blue fitting number and EL label without borrowing artwork from a neighbor.
REFERENCE_ROWS = [
    (["4A", "4B", "4C", "4D", "4E"], (225, 333), [110, 235, 370, 510, 665, 820]),
    (["4F", "4G", "4H", "4I", "4J"], (330, 428), [110, 250, 390, 525, 675, 820]),
    (["4K", "4L", "4M", "4N", "4O", "4P"], (425, 530), [110, 235, 350, 470, 575, 695, 820]),
    (["4Q", "4R", "4S", "4T", "4U", "4V"], (532, 640), [110, 230, 350, 465, 575, 690, 820]),
    (["4W", "4X", "4Y", "4Z", "4AA", "4AB"], (638, 745), [110, 230, 345, 465, 575, 690, 820]),
    (["4AC", "4AD", "4AE", "4AF", "4AG", "4AH"], (742, 855), [110, 235, 350, 465, 575, 700, 820]),
    (["4AI", "4AJ", "4AK", "4AL", "4AM", "4AN"], (852, 960), [110, 235, 350, 465, 575, 700, 820]),
    (["4AO", "4AP", "4AQ", "4AR"], (955, 1070), [110, 230, 345, 460, 575]),
]
REFERENCE_BOXES = {
    key: (bounds[index], y_range[0], bounds[index + 1], y_range[1])
    for keys, y_range, bounds in REFERENCE_ROWS
    for index, key in enumerate(keys)
}


def run(*args: str) -> None:
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def extract_source(work: Path) -> Image.Image:
    prefix = work / "source"
    run("pdfimages", "-f", "18", "-l", "18", "-png", str(PDF), str(prefix))
    candidates = []
    for path in work.glob("source-*.png"):
        with Image.open(path) as image:
            # pdfimages also emits a same-sized grayscale soft mask. Prefer the
            # color source when dimensions tie.
            candidates.append((image.width * image.height, len(image.getbands()), path))
    if not candidates:
        raise RuntimeError("pdfimages did not extract the Group 4 source image")
    source_path = max(candidates)[2]
    image = Image.open(source_path).convert("RGB")
    if image.size != (948, 1231):
        raise RuntimeError(f"unexpected Group 4 source size: {image.size}")
    return image


def trace_crop(source: Image.Image, box: tuple[int, int, int, int], work: Path, key: str) -> tuple[str, str]:
    crop = source.crop(box).convert("RGB")
    # The original scan is small. Trace at 4x so a one-pixel cleanup reduces
    # the enlarged ink weight without erasing the source's thin construction
    # lines or changing their geometry.
    crop = crop.resize((crop.width * 4, crop.height * 4), Image.Resampling.LANCZOS)
    # Source art is neutral black/gray while IDs and EL labels are blue. Keep
    # neutral pixels, then close one-pixel scan holes before thinning the ink.
    bitmap = Image.new("1", crop.size, 1)
    bitmap.putdata([
        0 if max(red, green, blue) - min(red, green, blue) <= 12 and (red + green + blue) / 3 < 230 else 1
        for red, green, blue in crop.get_flattened_data()
    ])
    bitmap = bitmap.convert("L").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(5)).point(
        lambda value: 0 if value < 128 else 255
    ).convert("1")
    pbm = work / f"{key}.pbm"
    traced = work / f"{key}.svg"
    bitmap.save(pbm)
    run("potrace", str(pbm), "--svg", "--flat", "--tight", "--opttolerance", "0.25", "-o", str(traced))
    text = traced.read_text()
    view_box = re.search(r'viewBox="([^"]+)"', text)
    group = re.search(r'(<g transform=.*?</g>)', text, flags=re.DOTALL)
    if not view_box or not group:
        raise RuntimeError(f"could not parse potrace output for {key}")
    return view_box.group(1), group.group(1).replace('fill="#000000"', 'fill="#243b53"')


def write_reference(source: Image.Image, key: str, feet: int, art_box: tuple[int, int, int, int], path: Path) -> None:
    """Isolate the original art and re-typeset its source ID/EL below it."""
    crop = source.crop(art_box).convert("RGB")
    cleaned = Image.new("RGB", crop.size, "white")
    cleaned.putdata([
        pixel if max(pixel) - min(pixel) <= 12 else (255, 255, 255)
        for pixel in crop.get_flattened_data()
    ])
    ink = ImageOps.invert(cleaned.convert("L")).point(lambda value: 255 if value > 20 else 0)
    content_box = ink.getbbox()
    if not content_box:
        raise RuntimeError(f"empty source crop for {key}")
    art = cleaned.crop(content_box)
    art.thumbnail((284, 164), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (320, 240), "white")
    canvas.paste(art, ((320 - art.width) // 2, 8 + (164 - art.height) // 2))
    draw = ImageDraw.Draw(canvas)
    try:
        strong = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 25)
        small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 11)
    except OSError:
        strong = ImageFont.load_default(size=25)
        small = ImageFont.load_default(size=11)
    blue = (94, 115, 171)
    draw.text((18, 184), key, font=strong, fill=blue)
    draw.text((118, 184), f"EL = {feet} ft", font=strong, fill=blue)
    draw.text((18, 222), "SOURCE ART · PRINTED PAGE 168", font=small, fill=(75, 98, 116))
    canvas.save(path, format="PNG", compress_level=9, optimize=False)


def fitting_svg(key: str, name: str, feet: int, view_box: str, group: str) -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="640" height="520" viewBox="0 0 640 520" role="img" aria-labelledby="title desc">
<title id="title">{key} — {escape(name)}</title>
<desc id="desc">Source-traced Group 4 fitting. Reference equivalent length {feet} feet at 900 FPM and 0.08 IWC per 100 feet. Drawing not to scale.</desc>
<style>text{{font-family:Arial,sans-serif;fill:#243b53}}</style>
<rect width="640" height="520" rx="16" fill="white"/>
<text x="32" y="44" font-size="28" font-weight="700">{key}</text>
<text x="112" y="43" font-size="17">{escape(name)}</text>
<text x="32" y="76" font-size="13">GROUP 4 · SUPPLY AIR BOOT AND STACK HEAD FITTINGS</text>
<svg x="55" y="104" width="530" height="295" viewBox="{view_box}" preserveAspectRatio="xMidYMid meet">{group}</svg>
<text x="32" y="446" font-size="15">Reference equivalent length: {feet} ft</text>
<text x="32" y="474" font-size="12">900 FPM · 0.08 IWC per 100 ft</text>
<text x="32" y="500" font-size="12">SOURCE TRACE · NOT TO SCALE · PDF pp. 18–19 / printed p. 168</text>
</svg>\n'''


def comparison_svg(key: str, name: str, svg_text: str) -> str:
    # Inline the generated asset so comparisons remain portable and render in
    # SVG implementations that block external SVG image references.
    svg_body = svg_text.split("\n", 1)[1].rsplit("</svg>", 1)[0]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="700" viewBox="0 0 1280 700" role="img" aria-label="{key} source and SVG comparison">
<rect width="1280" height="700" fill="#f8fafc"/>
<text x="40" y="54" font-family="Arial,sans-serif" font-size="30" font-weight="700" fill="#243b53">{key} · {escape(name)}</text>
<text x="40" y="100" font-family="Arial,sans-serif" font-size="20" fill="#243b53">Original source crop</text>
<text x="660" y="100" font-family="Arial,sans-serif" font-size="20" fill="#243b53">Source-traced SVG</text>
<rect x="40" y="120" width="580" height="520" rx="12" fill="white" stroke="#cbd5e1"/>
<rect x="660" y="120" width="580" height="520" rx="12" fill="white" stroke="#cbd5e1"/>
<image href="{key}.png" x="60" y="140" width="540" height="480" preserveAspectRatio="xMidYMid meet"/>
<svg x="660" y="120" width="580" height="520" viewBox="0 0 640 520" preserveAspectRatio="xMidYMid meet">{svg_body}</svg>
</svg>\n'''


def generate() -> list[dict]:
    OUT.mkdir(parents=True, exist_ok=True)
    REFS.mkdir(parents=True, exist_ok=True)
    for pattern in ("4*.svg", "manifest.json"):
        for path in OUT.glob(pattern):
            path.unlink()
    for pattern in ("4*.png", "4*-comparison.svg"):
        for path in REFS.glob(pattern):
            path.unlink()

    entries = []
    with tempfile.TemporaryDirectory(prefix="fitting-group-4-") as temp:
        work = Path(temp)
        source = extract_source(work)
        for key, feet, name, art_box in ITEMS:
            source_cell_box = REFERENCE_BOXES[key]
            write_reference(source, key, feet, art_box, REFS / f"{key}.png")
            view_box, group = trace_crop(source, art_box, work, key)
            svg_text = fitting_svg(key, name, feet, view_box, group)
            svg_path = OUT / f"{key}.svg"
            svg_path.write_text(svg_text)
            comparison_path = REFS / f"{key}-comparison.svg"
            comparison_path.write_text(comparison_svg(key, name, svg_text))
            entries.append({
                "id": key,
                "fittingNumber": key,
                "group": 4,
                "name": name,
                "nameSource": "descriptive inference from source geometry; the PDF supplies only the fitting number",
                "system": "supply",
                "category": "boot-and-stack-head",
                "svg": f"/images/fittings/group-4/{key}.svg",
                "referenceImage": f"/images/fittings/references/group-4/{key}.png",
                "comparison": f"/images/fittings/references/group-4/{key}-comparison.svg",
                "status": "source-trace-needs-review",
                "referenceEquivalentLengthFeet": feet,
                "referenceConditions": {"velocityFpm": 900, "frictionRateIwcPer100Feet": 0.08},
                "source": {
                    "pdf": "/files/ManD.Groups.pdf",
                    "pdfPages": [18, 19],
                    "printedPage": 168,
                    "embeddedImageIndex": 48,
                    "embeddedImageSize": [948, 1231],
                    "artCropPixels": list(art_box),
                    "sourceCellCropPixels": list(source_cell_box),
                },
                "drawingMethod": "Pure vector path traced from a 4x supersampled fitting-specific source crop with light ink-weight cleanup; no raster image is embedded in the fitting SVG.",
                "referenceImageTreatment": "Original black source art isolated from its crop; fitting ID and equivalent length re-typeset below from the source values.",
                "revision": hashlib.sha256(svg_text.encode()).hexdigest()[:16],
            })

    manifest = {
        "schemaVersion": 1,
        "group": 4,
        "title": "Supply Air Boot and Stack Head Fittings",
        "source": {"pdf": "/files/ManD.Groups.pdf", "pdfPages": [18, 19], "printedPage": 168},
        "referenceConditions": {"velocityFpm": 900, "frictionRateIwcPer100Feet": 0.08},
        "drawingCount": len(entries),
        "status": "source-trace-needs-review",
        "items": entries,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return entries


def write_doc(entries: list[dict]) -> None:
    ids = ", ".join(entry["id"] for entry in entries)
    rows = "\n".join(
        f'| {entry["id"]} | {entry["name"]} | {entry["referenceEquivalentLengthFeet"]} | '
        f'[`SVG`](../Public{entry["svg"]}) · [`source`](../Public{entry["referenceImage"]}) · '
        f'[`compare`](../Public{entry["comparison"]}) |'
        for entry in entries
    )
    DOC.write_text(f'''# Group 4 fitting reconstruction

Group 4 contains **{len(entries)} source fitting numbers**: {ids}.

The PDF identifies these as “Supply Air Boot and Stack Head Fittings” at 900 FPM and 0.08 IWC per 100 feet. The underlying 948 × 1231 source image is placed across PDF pages 18–19 and is printed page 168. The generator extracts that image directly, so fittings near the visual PDF page boundary are complete.

Each fitting SVG is a pure-vector trace of its own source crop. Reference PNGs isolate the original black source art and re-typeset the fitting number and equivalent-length value underneath, avoiding fragments from the tightly packed neighboring cells. Comparison SVGs place that prepared reference and generated SVG side by side for a later large-batch review.

The descriptive names are inferred from visible geometry because the PDF supplies fitting numbers and equivalent lengths but no individual names. Reviewers should treat the drawing, fitting number, and equivalent length as authoritative; names can be revised without changing the traced geometry.

| ID | Descriptive name | EL (ft) | Review files |
|---|---|---:|---|
{rows}

## Regeneration and validation

Run `python3 scripts/fitting_group_4.py`. The command rewrites only the Group 4 output, reference, comparison, manifest, and this document. Expected checks:

- 44 fitting IDs, from 4A through 4Z and 4AA through 4AR, with no gaps.
- XML-valid, raster-free fitting SVGs.
- One reference PNG and one side-by-side comparison SVG per fitting.
- Equivalent lengths transcribed from the source image.
- Byte-identical output on consecutive regenerations.
''')


if __name__ == "__main__":
    generated = generate()
    write_doc(generated)
    print(f"Generated {len(generated)} Group 4 fittings")
