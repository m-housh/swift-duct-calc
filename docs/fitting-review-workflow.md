# Batch drawing review

This is a local artwork-authoring tool, separate from the application's
[duct classification review](fitting-catalog-review.md). It is excluded from Docker
images. Serve the checkout's assets locally:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory Public
```

Open `http://127.0.0.1:8765/fitting-review/`. Use the group-specific packager's
`--activate` option where supported to select a batch. The archived
exports in `docs/fitting-reviews` record acceptance of exact artwork revisions.

## Review by exception

1. Compare the source and SVG in each row.
2. Check **Needs more work** only for drawings requiring revision. Optionally
   add a note describing the problem.
3. Click **Finish review** after inspecting the whole batch. Unchecked drawings
   then count as accepted; until that step they remain pending.
4. Click **Download review** and share the JSON file in this task so its
   decisions can be applied to the catalog and the next drawing pass.

Decisions save automatically in this browser, independently of generated
assets. They do not automatically update the repository catalog or sync to
other browsers. Download before clearing browser storage or moving devices.
If browser storage is unavailable, the page reports this and still allows a
download. Missing images block finishing a review.

Changing a checkbox or note reopens a finished review. Adding or removing a
drawing also reopens the batch. When a drawing/reference revision changes, its
checkbox and current note reset: the reviewer marks only problems that remain
in the correction. Earlier feedback remains in its archived review export.
Exports include exact drawing/reference revisions, so approval cannot be
mistaken for approval of a later redraw.

## Regeneration

Import a completed export with
`python3 scripts/import-fitting-review.py '/path/to/review.json'`. The importer
checks the batch, completeness and current asset hashes before changing any
files. Archived decisions are reapplied during combined regeneration only
when the SVG and reference still match the reviewed revision.

Use the appropriate `scripts/package_group_*.py` tool for the artwork being
changed. These tools read source manifests, preflight records, and archived
approvals; inspect their arguments before regeneration. The older
`generate-fittings.py` command only rebuilds the original traced Group 1/2 and
pilot workflow, despite its name. It does not regenerate the complete current
catalog. No frontend dependency installation or CSS build is required.

Reference crops are committed under `Public/images/fittings/references`.
Additional pilot crop provenance (x, y, width, height in embedded image pixels):

| Reference | pdfimages index | Crop |
| --- | --- | --- |
| 1AB | 0 | 80, 230, 755, 270 |
| 1CD | 0 | 80, 530, 830, 290 |
| 1E | 0 | 80, 855, 725, 300 |
| 2K | 18 | 350, 270, 190, 200 |
| 2N | 24 | 95, 275, 175, 100 |
| 3A | 32 | 140, 250, 245, 155 |
| 3S | 32 | 565, 875, 240, 260 |

The 3S variants intentionally share the original detail and its corner-value
table. Paired Group 1 references retain both fitting labels. The 2B and 3T
crop provenance is recorded in `fitting-trace-review.md`.
