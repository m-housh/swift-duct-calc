#!/usr/bin/env python3
"""Package the reviewed high-resolution 4Y line-art restoration as an SVG."""

from __future__ import annotations

import base64
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Public/images/fittings/group-4-enhanced"
RESTORED = OUT / "4Y-restored-art.png"
REFERENCE = ROOT / "Public/images/fittings/references/group-4/4Y.png"
BATCH = ROOT / "Public/fitting-review/batches/fitting-4Y-enhanced.json"
ACTIVE = ROOT / "Public/fitting-review/data.js"


def normalized_art() -> tuple[bytes, int, int]:
    with Image.open(RESTORED) as art:
        width, height = art.size
    return RESTORED.read_bytes(), width, height


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    png, width, height = normalized_art()
    encoded = base64.b64encode(png).decode("ascii")
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="640" height="520" viewBox="0 0 640 520" role="img" aria-labelledby="title desc">
<title id="title">4Y — Rectangular ceiling register boot</title>
<desc id="desc">High-resolution line-art restoration of fitting 4Y, packaged as a self-contained SVG. Reference equivalent length 35 feet.</desc>
<style>text{{font-family:Arial,sans-serif;fill:#243b53}}</style>
<rect width="640" height="520" rx="16" fill="white"/>
<text x="32" y="44" font-size="28" font-weight="700">4Y</text>
<text x="112" y="43" font-size="17">Rectangular ceiling register boot</text>
<text x="32" y="76" font-size="13">GROUP 4 · HIGH-RESOLUTION LINE-ART RESTORATION</text>
<image href="data:image/png;base64,{encoded}" x="52" y="94" width="536" height="320" preserveAspectRatio="xMidYMid meet"/>
<text x="32" y="458" font-size="15">Reference equivalent length: 35 ft</text>
<text x="32" y="486" font-size="12">AI-ASSISTED SOURCE RESTORATION · SELF-CONTAINED SVG · PAGE 168</text>
</svg>\n'''
    svg_path = OUT / "4Y.svg"
    svg_path.write_text(svg)
    revision = hashlib.sha256(svg_path.read_bytes() + REFERENCE.read_bytes()).hexdigest()
    manifest = {
        "schemaVersion": 1,
        "group": 4,
        "title": "High-resolution fitting restoration pilot",
        "drawingCount": 1,
        "status": "needs-review",
        "items": [{
            "id": "4Y",
            "name": "Rectangular ceiling register boot",
            "referenceEquivalentLengthFeet": 35,
            "svg": "/images/fittings/group-4-enhanced/4Y.svg",
            "restoredArt": "/images/fittings/group-4-enhanced/4Y-restored-art.png",
            "referenceImage": "/images/fittings/references/group-4/4Y.png",
            "revision": revision,
            "drawingMethod": "AI-assisted high-resolution line-art restoration embedded in a self-contained SVG; source geometry remains the review authority.",
            "embeddedRasterSize": [width, height],
        }],
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    batch = {
        "id": "fitting-4Y-enhanced",
        "title": "High-resolution restoration pilot · 4Y",
        "description": "A sharper restoration beside the exact low-resolution source. Check it if its geometry differs too much or still needs work.",
        "items": [{
            "id": "4Y",
            "number": "4Y",
            "name": "Rectangular ceiling register boot",
            "group": 4,
            "image": f"../images/fittings/group-4-enhanced/4Y.svg?revision={revision[:12]}",
            "reference": "../images/fittings/references/group-4/4Y.png",
            "sourcePage": 168,
            "sourcePDF": "../files/ManD.Groups.pdf#page=18",
            "revision": revision,
            "priorApproval": False,
        }],
    }
    BATCH.write_text(json.dumps(batch, indent=2) + "\n")
    ACTIVE.write_text("window.FITTING_REVIEW = " + json.dumps(batch, indent=2) + ";\n")
    print("Generated and activated high-resolution 4Y restoration pilot")


if __name__ == "__main__":
    main()
