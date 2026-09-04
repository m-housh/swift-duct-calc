#!/usr/bin/env python3
"""Generate a source-registered 4Y SVG and activate its one-item review."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Public/images/fittings/group-4-registered"
REFERENCE = ROOT / "Public/images/fittings/references/group-4/4Y.png"
BATCH = ROOT / "Public/fitting-review/batches/fitting-4Y-registered.json"
ACTIVE = ROOT / "Public/fitting-review/data.js"


ART = '''
<defs>
  <clipPath id="grille"><polygon points="15,65 64,65 78,75 28,75"/></clipPath>
</defs>
<g fill="none" stroke="#243b53" stroke-width="0.6" stroke-linecap="round" stroke-linejoin="round">
  <path d="M40 34V27Q40 25 43 25H54Q57 25 57 28V34"/>
  <path d="M27 38L40 34M57 34L65 38"/>
  <path d="M27 38H65L80 45H15Z"/>
  <path d="M18 43H68L77 47H17"/>
  <path d="M15 45L33 59H84L80 45"/>
  <path d="M18 47L29 53H72L81 58"/>
  <polygon points="12,63 65,63 83,77 28,77"/>
  <polygon points="15,65 64,65 78,75 28,75"/>
  <g clip-path="url(#grille)" stroke-width="0.35">
    <path d="M4 62L25 79M8 62L29 79M12 62L33 79M16 62L37 79M20 62L41 79M24 62L45 79M28 62L49 79M32 62L53 79M36 62L57 79M40 62L61 79M44 62L65 79M48 62L69 79M52 62L73 79M56 62L77 79M60 62L81 79M64 62L85 79"/>
    <path d="M26 62L5 79M30 62L9 79M34 62L13 79M38 62L17 79M42 62L21 79M46 62L25 79M50 62L29 79M54 62L33 79M58 62L37 79M62 62L41 79M66 62L45 79M70 62L49 79M74 62L53 79M78 62L57 79M82 62L61 79M86 62L65 79"/>
  </g>
</g>'''


def drawing() -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="640" height="520" viewBox="0 0 640 520" role="img" aria-labelledby="title desc">
<title id="title">4Y — Rectangular ceiling register boot</title>
<desc id="desc">Source-registered manual vector reconstruction of fitting 4Y. Reference equivalent length 35 feet.</desc>
<style>text{{font-family:Arial,sans-serif;fill:#243b53}}</style>
<rect width="640" height="520" rx="16" fill="white"/>
<text x="32" y="44" font-size="28" font-weight="700">4Y</text>
<text x="112" y="43" font-size="17">Rectangular ceiling register boot</text>
<text x="32" y="76" font-size="13">GROUP 4 · SOURCE-REGISTERED MANUAL SVG</text>
<svg x="55" y="94" width="530" height="320" viewBox="8 20 80 62" preserveAspectRatio="xMidYMid meet">
{ART}
</svg>
<text x="32" y="458" font-size="15">Reference equivalent length: 35 ft</text>
<text x="32" y="486" font-size="12">REGISTERED TO WORKBOOK SOURCE CELL · NOT TO SCALE · PRINTED PAGE 168</text>
</svg>\n'''


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    svg_path = OUT / "4Y.svg"
    svg_path.write_text(drawing())
    revision = hashlib.sha256(svg_path.read_bytes() + REFERENCE.read_bytes()).hexdigest()
    manifest = {
        "schemaVersion": 1,
        "group": 4,
        "title": "Source-registered fitting pilot",
        "drawingCount": 1,
        "status": "needs-review",
        "items": [{
            "id": "4Y",
            "name": "Rectangular ceiling register boot",
            "referenceEquivalentLengthFeet": 35,
            "svg": "/images/fittings/group-4-registered/4Y.svg",
            "referenceImage": "/images/fittings/references/group-4/4Y.png",
            "revision": revision,
            "drawingMethod": "Manual SVG drawn in the original 120 by 107 pixel source-cell coordinate system and checked with a registered overlay.",
        }],
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    batch = {
        "id": "fitting-4Y-registered",
        "title": "Source-registered SVG pilot · 4Y",
        "description": "One SVG drawn in the original source-cell coordinate system and checked with a registered overlay. Check it only if it still needs work.",
        "items": [{
            "id": "4Y",
            "number": "4Y",
            "name": "Rectangular ceiling register boot",
            "group": 4,
            "image": f"../images/fittings/group-4-registered/4Y.svg?revision={revision[:12]}",
            "reference": "../images/fittings/references/group-4/4Y.png",
            "sourcePage": 168,
            "sourcePDF": "../files/ManD.Groups.pdf#page=18",
            "revision": revision,
            "priorApproval": False,
        }],
    }
    BATCH.write_text(json.dumps(batch, indent=2) + "\n")
    ACTIVE.write_text("window.FITTING_REVIEW = " + json.dumps(batch, indent=2) + ";\n")
    print("Generated and activated source-registered 4Y pilot")


if __name__ == "__main__":
    main()
