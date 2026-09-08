#!/usr/bin/env python3
"""Package catalog identities/artwork plus explicitly reviewed calculation cases.

This reads the artwork manifests directly. It does not import prototype rules.
See docs/fitting-rule-audit.md for the source pages checked for enabled rules.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "Public/images/fittings"
SOURCES = {
    1: "catalog.json", 2: "group-2-restored/manifest.json",
    3: "group-3-individual/manifest.json", 4: "group-4-enhanced/manifest.json",
    5: "group-5-shapes/manifest.json", 6: "group-6-enhanced/manifest.json",
    7: "group-7-options/manifest.json", 8: "group-8/manifest.json",
    9: "group-9/manifest.json", 10: "group-10/manifest.json",
    12: "group-12/manifest.json",
}


def fixed(feet):
    return {"kind": "fixed", "feet": feet}


def table(labels, rows):
    return {"kind": "sourceTable", "labels": labels,
            "rows": [{"keys": keys, "feet": feet} for keys, feet in rows]}


def dimensions(labels, rows):
    return {"kind": "dimensions", "labels": labels,
            "rows": [{"ratio": ratio, "feet": feet} for ratio, feet in rows]}


RULES = {key: fixed(feet) for key, feet in {
    "1A": 35, "1B": 10, "1C": 35, "1D": 10, "1E": 10,
    "4G": 80, "4Q": 50, "4R": 20,
    "5A-round": 40, "5A-rectangular": 40,
    "5C-round": 40, "5C-rectangular": 40,
    "6F": 25, "6G": 30, "6H": 15, "6I": 30, "6J": 55,
    "6K": 10, "6L": 20, "6M": 20, "6N": 10, "6O": 10, "6P": 5,
    "8A-mitered": 75, "8A-3-piece-45": 10, "8A-2-piece-45": 15,
    "12S": 30, "12T": 30, "12U": 25,
}.items()}
for key, feet in {
    "2A": [35, 45, 55, 65, 70, 80], "2B": [20, 30, 35, 40, 45, 50],
    "2N": [35, 35, 40, 40, 40, 40], "2O": [55, 65, 75, 85, 90, 100],
    "2P": [50, 55, 60, 65, 70, 75], "2Q": [10, 10, 15, 20, 20, 25],
}.items():
    RULES[key] = {"kind": "downstreamBranches", "rows": [
        {"minimum": n, "maximum": n if n < 5 else None, "feet": value}
        for n, value in enumerate(feet)
    ]}
for key in ["5E-round", "5E-rectangular"]:
    RULES[key] = table(["Returns entering this plenum"], [(["1"], 10), (["2 or more"], 35)])
RULES["5F-rectangular"] = table(
    ["Returns entering this plenum"], [(["1"], 45), (["2 or more"], 70)])
for key in ["5H-rectangular", "5I-rectangular"]:
    RULES[key] = dimensions(["H", "W"], [(1, 45), (2, 30)])
RULES["5J-rectangular"] = dimensions(["R", "W"], [(0.25, 20), (0.5, 15), (1, 10)])
for key, values in {
    "8A-4-or-5-piece": [30, 20, 15], "8A-3-piece": [35, 25, 20],
}.items():
    RULES[key] = table(["R/D"], list(zip([["0.75"], ["1"], ["1.5 or larger"]], values)))
RULES["8A-smooth"] = table(["R/D", "Bend angle (degrees)"], [
    ([radius, str(angle)], base * multiplier)
    for radius, base in [("0.75", 20), ("1", 15), ("1.5 or larger", 10)]
    for angle, multiplier in [(20, .31), (30, .45), (45, .6), (60, .78), (75, .9), (90, 1)]
])
RULES["8A-easy-bend"] = table(["Piece count"], [(["4"], 25), (["3"], 30)])
RULES["8A-hard-bend"] = table(["Piece count"], [(["4"], 30), (["3"], 35)])
RULES["12J"] = table(["Slope X/Y", "Larger / smaller area"], [
    ([slope, area], feet) for slope, feet in [("1:1", 10), ("2:1", 5), ("4:1", 5)]
    for area in ["2", "4"]
])


def build():
    entries = []
    for group, manifest in SOURCES.items():
        document = json.loads((ART / manifest).read_text())
        for item in document.get("items", document.get("fittings", [])):
            if group == 1 and item["group"] != 1:
                continue
            assert item["status"] == "visually-approved", item["id"]
            source = item.get("source", document.get("source", {}))
            artwork = item.get("svg", item.get("image"))
            assert artwork.startswith("/images/fittings/")
            assert (ROOT / "Public" / artwork.lstrip("/")).is_file()
            pages = source.get("pdfPages", [source["pdfPage"]] if "pdfPage" in source else [])
            conditions = item.get("referenceConditions", document.get("referenceConditions", {}))
            condition_notes = []
            if "velocityFpm" in conditions:
                condition_notes.append(f"Source reference velocity: {conditions['velocityFpm']} FPM.")
            if "frictionRateIwcPer100Feet" in conditions:
                condition_notes.append(f"Source reference friction rate: {conditions['frictionRateIwcPer100Feet']} IWC per 100 ft.")
            # Some manifests identify the page containing the preceding heading.
            if group == 5 and item["id"] in ["5H-rectangular", "5I-rectangular", "5J-rectangular"]:
                pages = [22]
            entries.append({
                "id": item["id"], "group": group,
                "sourceCode": item.get("sourceFittingId", item.get("fittingId", item.get("fittingNumber", item["id"]))),
                "name": item["name"], "artworkPath": artwork, "sourcePages": pages,
                "notes": item.get("notes", []) + condition_notes + ([item["countingRule"]] if item.get("countingRule") else []),
                "rule": RULES.get(item["id"]),
            })
    entries.append({
        "id": "11-junction-box", "group": 11, "sourceCode": None,
        "name": "Flex junction box", "artworkPath": None, "sourcePages": [42, 43],
        "notes": ["Production artwork and controlling-velocity rules await verification."], "rule": None,
    })
    entries.sort(key=lambda entry: entry["group"])
    ids = {entry["id"] for entry in entries}
    assert len(ids) == len(entries) == 231
    assert set(RULES) <= ids, set(RULES) - ids
    destination = ROOT / "Sources/FittingClient/Resources/catalog.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps({"revision": "2026-09-08.1", "entries": entries}, indent=2) + "\n")
    print(f"Packaged {len(entries)} definitions, {len(RULES)} reviewed calculation cases.")


if __name__ == "__main__":
    build()
