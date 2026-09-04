#!/usr/bin/env python3
"""Package reviewed Group 4 restoration images as self-contained SVG cards."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Public/images/fittings/group-4-enhanced"
SOURCE_MANIFEST = ROOT / "Public/images/fittings/group-4/manifest.json"
BATCH = ROOT / "Public/fitting-review/batches/group-4-enhanced.json"
ACTIVE = ROOT / "Public/fitting-review/data.js"


def svg_card(item: dict, png: bytes) -> str:
    encoded = base64.b64encode(png).decode("ascii")
    fitting_id = item["id"]
    name = item["name"]
    equivalent_length = item["referenceEquivalentLengthFeet"]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="640" height="520" viewBox="0 0 640 520" role="img" aria-labelledby="title desc">
<title id="title">{fitting_id} — {name}</title>
<desc id="desc">High-resolution line-art restoration of fitting {fitting_id}. Reference equivalent length {equivalent_length} feet.</desc>
<style>text{{font-family:Arial,sans-serif;fill:#243b53}}</style>
<rect width="640" height="520" rx="16" fill="white"/>
<text x="32" y="44" font-size="28" font-weight="700">{fitting_id}</text>
<text x="112" y="43" font-size="17">{name}</text>
<text x="32" y="76" font-size="13">GROUP 4 · HIGH-RESOLUTION LINE-ART RESTORATION</text>
<image href="data:image/png;base64,{encoded}" x="52" y="94" width="536" height="320" preserveAspectRatio="xMidYMid meet"/>
<text x="32" y="458" font-size="15">Reference equivalent length: {equivalent_length} ft</text>
<text x="32" y="486" font-size="12">AI-ASSISTED SOURCE RESTORATION · SELF-CONTAINED SVG · PAGE 168</text>
</svg>\n'''


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--activate", action="store_true", help="Make this the active browser review batch")
    args = parser.parse_args()

    source = json.loads(SOURCE_MANIFEST.read_text())
    packaged = []
    for item in source["items"]:
        fitting_id = item["id"]
        art_path = OUT / f"{fitting_id}-restored-art.png"
        if not art_path.exists():
            continue
        png = art_path.read_bytes()
        with Image.open(art_path) as image:
            raster_size = list(image.size)
        svg_path = OUT / f"{fitting_id}.svg"
        svg_path.write_text(svg_card(item, png))
        reference_path = ROOT / "Public" / item["referenceImage"].lstrip("/")
        revision = hashlib.sha256(svg_path.read_bytes() + reference_path.read_bytes()).hexdigest()
        packaged.append({
            "id": fitting_id,
            "fittingNumber": fitting_id,
            "group": 4,
            "name": item["name"],
            "referenceEquivalentLengthFeet": item["referenceEquivalentLengthFeet"],
            "svg": f"/images/fittings/group-4-enhanced/{fitting_id}.svg",
            "restoredArt": f"/images/fittings/group-4-enhanced/{fitting_id}-restored-art.png",
            "referenceImage": item["referenceImage"],
            "revision": revision,
            "status": "restoration-needs-review",
            "drawingMethod": "AI-assisted high-resolution line-art restoration embedded in a self-contained SVG; source geometry remains the review authority.",
            "embeddedRasterSize": raster_size,
        })

    manifest = {
        "schemaVersion": 1,
        "group": 4,
        "title": "Supply Air Boot and Stack Head Fittings — high-resolution restorations",
        "source": source["source"],
        "referenceConditions": source["referenceConditions"],
        "drawingCount": len(packaged),
        "expectedDrawingCount": len(source["items"]),
        "status": "restoration-needs-review",
        "items": packaged,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    batch = {
        "id": "group-4-enhanced",
        "title": "Group 4 · high-resolution restorations",
        "description": "Sharp restored drawings beside the exact low-resolution source. Check only drawings whose geometry still needs work.",
        "items": [{
            "id": item["id"],
            "number": item["id"],
            "name": item["name"],
            "group": 4,
            "image": f"../images/fittings/group-4-enhanced/{item['id']}.svg?revision={item['revision'][:12]}",
            "reference": f"../images/fittings/references/group-4/{item['id']}.png",
            "sourcePage": 168,
            "sourcePDF": "../files/ManD.Groups.pdf#page=18",
            "revision": item["revision"],
            "priorApproval": item["id"] == "4Y",
        } for item in packaged],
    }
    BATCH.write_text(json.dumps(batch, indent=2) + "\n")
    if args.activate:
        ACTIVE.write_text("window.FITTING_REVIEW = " + json.dumps(batch, indent=2) + ";\n")
    print(f"Packaged {len(packaged)} of {len(source['items'])} Group 4 restorations")


if __name__ == "__main__":
    main()
