#!/usr/bin/env python3
"""Generate a self-contained 4Y facsimile SVG from its exact source crop."""

from __future__ import annotations

import base64
import hashlib
import io
import json
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Public/images/fittings/group-4-facsimile"
REFERENCE = ROOT / "Public/images/fittings/references/group-4/4Y.png"
BATCH = ROOT / "Public/fitting-review/batches/fitting-4Y-facsimile.json"
ACTIVE = ROOT / "Public/fitting-review/data.js"


def source_art() -> tuple[bytes, int, int]:
    # The source drawing occupies the upper 118 pixels. Stop before the faint
    # remnants of the original printed annotation beneath the grille.
    reference = Image.open(REFERENCE).convert("RGB")
    art_area = reference.crop((0, 0, reference.width, 118))
    mask = ImageOps.invert(art_area.convert("L")).point(lambda value: 255 if value > 18 else 0)
    bounds = mask.getbbox()
    if not bounds:
        raise RuntimeError("4Y reference art is empty")
    left, top, right, bottom = bounds
    padding = 5
    art = art_area.crop((max(0, left - padding), max(0, top - padding), min(art_area.width, right + padding), min(art_area.height, bottom + padding)))
    buffer = io.BytesIO()
    art.save(buffer, format="PNG", optimize=True)
    return buffer.getvalue(), art.width, art.height


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    png, width, height = source_art()
    (OUT / "4Y-source-art.png").write_bytes(png)
    encoded = base64.b64encode(png).decode("ascii")
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="640" height="520" viewBox="0 0 640 520" role="img" aria-labelledby="title desc">
<title id="title">4Y — Rectangular ceiling register boot</title>
<desc id="desc">Self-contained facsimile SVG preserving the exact source drawing for fitting 4Y. Reference equivalent length 35 feet.</desc>
<style>text{{font-family:Arial,sans-serif;fill:#243b53}}</style>
<rect width="640" height="520" rx="16" fill="white"/>
<text x="32" y="44" font-size="28" font-weight="700">4Y</text>
<text x="112" y="43" font-size="17">Rectangular ceiling register boot</text>
<text x="32" y="76" font-size="13">GROUP 4 · SOURCE FACSIMILE SVG</text>
<image href="data:image/png;base64,{encoded}" x="70" y="104" width="500" height="300" preserveAspectRatio="xMidYMid meet"/>
<text x="32" y="458" font-size="15">Reference equivalent length: 35 ft</text>
<text x="32" y="486" font-size="12">EXACT SOURCE ART · SELF-CONTAINED SVG · PRINTED PAGE 168</text>
</svg>\n'''
    svg_path = OUT / "4Y.svg"
    svg_path.write_text(svg)
    revision = hashlib.sha256(svg_path.read_bytes() + REFERENCE.read_bytes()).hexdigest()
    manifest = {
        "schemaVersion": 1,
        "group": 4,
        "title": "Source facsimile fitting pilot",
        "drawingCount": 1,
        "status": "needs-review",
        "items": [{
            "id": "4Y",
            "name": "Rectangular ceiling register boot",
            "referenceEquivalentLengthFeet": 35,
            "svg": "/images/fittings/group-4-facsimile/4Y.svg",
            "sourceArt": "/images/fittings/group-4-facsimile/4Y-source-art.png",
            "referenceImage": "/images/fittings/references/group-4/4Y.png",
            "revision": revision,
            "drawingMethod": "Self-contained SVG wrapper with the exact isolated source raster embedded as a PNG data URI.",
            "embeddedRasterSize": [width, height],
        }],
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    batch = {
        "id": "fitting-4Y-facsimile",
        "title": "Source facsimile SVG pilot · 4Y",
        "description": "One self-contained SVG preserving the exact source drawing. Check it only if this representation is still unsuitable.",
        "items": [{
            "id": "4Y",
            "number": "4Y",
            "name": "Rectangular ceiling register boot",
            "group": 4,
            "image": f"../images/fittings/group-4-facsimile/4Y.svg?revision={revision[:12]}",
            "reference": "../images/fittings/references/group-4/4Y.png",
            "sourcePage": 168,
            "sourcePDF": "../files/ManD.Groups.pdf#page=18",
            "revision": revision,
            "priorApproval": False,
        }],
    }
    BATCH.write_text(json.dumps(batch, indent=2) + "\n")
    ACTIVE.write_text("window.FITTING_REVIEW = " + json.dumps(batch, indent=2) + ";\n")
    print("Generated and activated 4Y facsimile SVG")


if __name__ == "__main__":
    main()
