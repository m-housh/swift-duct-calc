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
    art = f'<image href="data:image/png;base64,{encoded}" x="52" y="94" width="536" height="320" preserveAspectRatio="xMidYMid meet"/>'
    if fitting_id == "4AG":
        # The source arrow points inward. Complete the existing raster shaft
        # in its native coordinates without changing the restored fitting.
        art = f'''<svg x="52" y="94" width="536" height="320" viewBox="0 0 1402 1122" preserveAspectRatio="xMidYMid meet">
<image href="data:image/png;base64,{encoded}" width="1402" height="1122"/>
<path d="M394 642 L361 643 L372 666 Z" fill="black" aria-label="Airflow into the round connection"/>
</svg>'''
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="640" height="520" viewBox="0 0 640 520" role="img" aria-labelledby="title desc">
<title id="title">{fitting_id} — {name}</title>
<desc id="desc">High-resolution line-art restoration of fitting {fitting_id}. Reference equivalent length {equivalent_length} feet.</desc>
<style>text{{font-family:Arial,sans-serif;fill:#243b53}}</style>
<rect width="640" height="520" rx="16" fill="white"/>
<text x="32" y="44" font-size="28" font-weight="700">{fitting_id}</text>
<text x="112" y="43" font-size="17">{name}</text>
<text x="32" y="76" font-size="13">GROUP 4 · HIGH-RESOLUTION LINE-ART RESTORATION</text>
{art}
<text x="32" y="458" font-size="15">Reference equivalent length: {equivalent_length} ft</text>
<text x="32" y="486" font-size="12">AI-ASSISTED SOURCE RESTORATION · SELF-CONTAINED SVG · PAGE 168</text>
</svg>\n'''


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--activate", action="store_true", help="Make this the active browser review batch")
    parser.add_argument("--pending-only", action="store_true", help="Create a follow-up batch excluding drawings approved at their current revision")
    parser.add_argument("--manifest-only", action="store_true", help="Refresh approval metadata without replacing review batches")
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
        if fitting_id == "4AG" and raster_size != [1402, 1122]:
            raise ValueError("4AG artwork size changed; realign its arrowhead before packaging.")
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

    # Only the exact SVG/reference pair reviewed by the user inherits approval.
    reports = []
    for path in (ROOT / "docs/fitting-reviews").glob("*.json"):
        report = json.loads(path.read_text())
        if report.get("schemaVersion") == 1 and report.get("completedAt") and isinstance(report.get("drawings"), list):
            reports.append((report, path))
    for report, path in sorted(reports, key=lambda pair: pair[0]["completedAt"]):
        decisions = {decision["id"]: decision for decision in report["drawings"]}
        for item in packaged:
            decision = decisions.get(item["id"])
            if decision and decision.get("revision") == item["revision"]:
                item["status"] = "visually-approved" if decision["status"] == "accepted" else "needs-work"
                item["visualReview"] = {
                    "revision": decision["revision"], "completedAt": report["completedAt"],
                    "batchId": report["batchId"], "note": decision["note"],
                    "record": str(path.relative_to(ROOT)),
                }

    manifest = {
        "schemaVersion": 1,
        "group": 4,
        "title": "Supply Air Boot and Stack Head Fittings — high-resolution restorations",
        "source": source["source"],
        "referenceConditions": source["referenceConditions"],
        "drawingCount": len(packaged),
        "expectedDrawingCount": len(source["items"]),
        "status": "visually-approved" if len(packaged) == len(source["items"]) and all(item["status"] == "visually-approved" for item in packaged) else "restoration-needs-review",
        "items": packaged,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    if args.manifest_only:
        print(f"Updated Group 4 manifest: {manifest['status']}")
        return

    batch = {
        "id": "group-4-enhanced-followup" if args.pending_only else "group-4-enhanced",
        "title": "Group 4 · corrections" if args.pending_only else "Group 4 · high-resolution restorations",
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
            "priorApproval": item["status"] == "visually-approved",
        } for item in packaged if not args.pending_only or item["status"] != "visually-approved"],
    }
    batch_path = BATCH.with_name(f"{batch['id']}.json")
    batch_path.write_text(json.dumps(batch, indent=2) + "\n")
    if args.activate:
        ACTIVE.write_text("window.FITTING_REVIEW = " + json.dumps(batch, indent=2) + ";\n")
    print(f"Packaged {len(packaged)} of {len(source['items'])} Group 4 restorations")


if __name__ == "__main__":
    main()
