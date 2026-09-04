#!/usr/bin/env python3
"""Generate four clean, hand-drawn Group 4 SVGs and activate their review batch."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from xml.sax.saxutils import escape


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Public/images/fittings/group-4-manual"
REFS = ROOT / "Public/images/fittings/references/group-4"
BATCH = ROOT / "Public/fitting-review/batches/group-4-manual-pilot.json"
ACTIVE = ROOT / "Public/fitting-review/data.js"


FITTINGS = [
    ("4AD", "Segmented elbow on rectangular stack", 60),
    ("4AE", "Segmented elbow on flange", 55),
    ("4Y", "Rectangular ceiling register boot", 35),
    ("4Z", "Square grille boot to round branch", 60),
]


ART = {
    "4AD": '''
<g class="part">
  <path d="M195 365V282L258 249L326 282V365L260 393Z" fill="#f8fafc"/>
  <path d="M195 282L260 318L326 282M260 318V393"/>
  <path d="M236 278C218 238 222 196 246 158C276 113 326 88 401 78"/>
  <path d="M299 288C279 252 282 218 303 190C328 157 362 143 419 137"/>
  <path d="M236 278C253 291 280 296 299 288"/>
  <path d="M225 244C248 258 278 262 297 251"/>
  <path d="M225 209C250 223 277 227 303 217"/>
  <path d="M236 174C260 188 286 193 314 183"/>
  <path d="M258 139C281 154 308 158 335 149"/>
  <path d="M291 108C315 122 340 127 369 118"/>
  <path d="M401 78L431 73M419 137L449 132"/>
</g>''',
    "4AE": '''
<g class="part">
  <path d="M118 365L285 310L451 354L280 414Z" fill="#f8fafc"/>
  <path d="M139 365L284 321L426 356L280 401Z"/>
  <path d="M229 318V286C229 270 254 258 284 258S339 270 339 286V318" fill="#fff"/>
  <path d="M229 286C229 302 254 314 284 314S339 302 339 286"/>
  <path d="M234 282C220 241 226 196 252 157C282 113 331 89 400 78"/>
  <path d="M301 287C283 250 287 217 308 188C332 156 365 143 419 137"/>
  <path d="M234 282C254 296 282 299 301 287"/>
  <path d="M224 244C248 259 278 263 298 251"/>
  <path d="M225 207C250 223 279 228 304 216"/>
  <path d="M238 171C262 188 289 192 316 181"/>
  <path d="M261 137C285 153 311 157 338 148"/>
  <path d="M295 106C318 121 343 126 371 117"/>
  <path d="M400 78L431 73M419 137L450 131"/>
</g>''',
    "4Y": '''
<defs>
  <clipPath id="grid-4Y"><polygon points="139,350 397,350 471,393 211,393"/></clipPath>
</defs>
<g class="part">
  <path d="M274 98V73C274 62 287 54 304 54H336C353 54 366 62 366 73V98"/>
  <path d="M224 151L274 98H366L417 151" fill="#f8fafc"/>
  <path d="M184 151H417L473 185H239Z" fill="#fff"/>
  <path d="M204 170H410L443 189H237Z"/>
  <path d="M168 211H432L492 247H229Z" fill="#f8fafc"/>
  <path d="M183 226H424L461 248H221Z"/>
  <path d="M168 211L184 151M432 211L473 185"/>
  <polygon points="139,350 397,350 471,393 211,393" fill="#fff"/>
  <polygon points="153,360 391,360 450,384 214,384" fill="#f8fafc"/>
  <g clip-path="url(#grid-4Y)" stroke-width="1.25">
    <path d="M80 337L190 410M100 337L210 410M120 337L230 410M140 337L250 410M160 337L270 410M180 337L290 410M200 337L310 410M220 337L330 410M240 337L350 410M260 337L370 410M280 337L390 410M300 337L410 410M320 337L430 410M340 337L450 410M360 337L470 410M380 337L490 410"/>
    <path d="M170 337L70 410M190 337L90 410M210 337L110 410M230 337L130 410M250 337L150 410M270 337L170 410M290 337L190 410M310 337L210 410M330 337L230 410M350 337L250 410M370 337L270 410M390 337L290 410M410 337L310 410M430 337L330 410M450 337L350 410M470 337L370 410M490 337L390 410"/>
  </g>
</g>''',
    "4Z": '''
<defs>
  <clipPath id="grid-4Z"><polygon points="202,103 318,158 232,216 116,158"/></clipPath>
</defs>
<g class="part">
  <polygon points="202,91 333,154 232,225 100,158" fill="#fff"/>
  <polygon points="202,103 318,158 232,216 116,158" fill="#f8fafc"/>
  <g clip-path="url(#grid-4Z)" stroke-width="1.2">
    <path d="M75 104L223 230M94 95L242 221M113 86L261 212M132 77L280 203M151 68L299 194M170 59L318 185M189 50L337 176M208 41L356 167"/>
    <path d="M250 70L74 188M270 80L94 198M290 90L114 208M310 100L134 218M330 110L154 228M350 120L174 238"/>
  </g>
  <path d="M100 158V236L231 304L232 225M333 154V232L292 260" fill="#f8fafc"/>
  <path d="M100 236L231 304L292 260L333 232"/>
  <path d="M263 251L445 353M229 302L414 407" fill="none"/>
  <path d="M445 353C461 344 487 355 499 376C511 398 505 421 489 430C473 439 449 428 436 407C424 386 429 362 445 353Z" fill="#fff"/>
  <path d="M414 407L436 407M445 353L263 251"/>
</g>''',
}


def svg(key: str, name: str, feet: int) -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="640" height="520" viewBox="0 0 640 520" role="img" aria-labelledby="title desc">
<title id="title">{key} — {escape(name)}</title>
<desc id="desc">Clean manually reconstructed Group 4 fitting. Reference equivalent length {feet} feet. Drawing not to scale.</desc>
<style>
  text{{font-family:Arial,sans-serif;fill:#243b53}}
  .part{{fill:none;stroke:#243b53;stroke-width:2.4;stroke-linecap:round;stroke-linejoin:round}}
</style>
<rect width="640" height="520" rx="16" fill="white"/>
<text x="32" y="44" font-size="28" font-weight="700">{key}</text>
<text x="122" y="43" font-size="17">{escape(name)}</text>
<text x="32" y="76" font-size="13">GROUP 4 · MANUAL VECTOR PILOT</text>
<svg x="48" y="92" width="544" height="330" viewBox="70 35 450 410" preserveAspectRatio="xMidYMid meet">
{ART[key]}
</svg>
<text x="32" y="458" font-size="15">Reference equivalent length: {feet} ft</text>
<text x="32" y="486" font-size="12">CLEAN MANUAL SVG · NOT TO SCALE · WORKBOOK/PDF PRINTED PAGE 168</text>
</svg>\n'''


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    items = []
    manifest_items = []
    for key, name, feet in FITTINGS:
        text = svg(key, name, feet)
        path = OUT / f"{key}.svg"
        path.write_text(text)
        reference = REFS / f"{key}.png"
        revision = hashlib.sha256(path.read_bytes() + reference.read_bytes()).hexdigest()
        image = f"../images/fittings/group-4-manual/{key}.svg?revision={revision[:12]}"
        items.append({
            "id": key,
            "number": key,
            "name": name,
            "group": 4,
            "image": image,
            "reference": f"../images/fittings/references/group-4/{key}.png",
            "sourcePage": 168,
            "sourcePDF": "../files/ManD.Groups.pdf#page=18",
            "revision": revision,
            "priorApproval": False,
        })
        manifest_items.append({
            "id": key,
            "name": name,
            "referenceEquivalentLengthFeet": feet,
            "svg": f"/images/fittings/group-4-manual/{key}.svg",
            "referenceImage": f"/images/fittings/references/group-4/{key}.png",
            "revision": revision,
            "drawingMethod": "Manual SVG reconstruction using explicit lines, polygons, and Bézier curves.",
        })

    manifest = {
        "schemaVersion": 1,
        "group": 4,
        "title": "Group 4 manual SVG pilot",
        "drawingCount": len(manifest_items),
        "status": "manual-pilot-needs-review",
        "items": manifest_items,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    batch = {
        "id": "group-4-manual-pilot",
        "title": "Group 4 manual SVG pilot · 4 drawings",
        "description": "Four clean SVGs drawn manually from the workbook source. Check only drawings that need more work.",
        "items": items,
    }
    BATCH.write_text(json.dumps(batch, indent=2) + "\n")
    ACTIVE.write_text("window.FITTING_REVIEW = " + json.dumps(batch, indent=2) + ";\n")
    print("Generated and activated four manual Group 4 SVG pilots")


if __name__ == "__main__":
    main()
