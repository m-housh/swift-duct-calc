# Batch drawing review

Use `/fitting-review/` in the running app. The review page is served by the
existing public-file middleware. For a standalone preview, serve `Public` with
`python3 -m http.server 8765 --bind 127.0.0.1 --directory Public` and open
`http://127.0.0.1:8765/fitting-review/`.

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

Changing a checkbox or note reopens a finished review. Adding, removing or
changing a drawing/reference also reopens it on reload. Existing rejection
flags and notes are retained. Exports include the exact revision of each
drawing/reference pair, so approval cannot be mistaken for approval of a
later redraw.

## Batch size

The completed pilot review accepted all 13 drawings, with no revision requests.
The original export is archived under `docs/fitting-reviews/`, and the catalog
records the reviewed revision and completion time for each drawing.

Use complete groups rather than 4–6 drawing batches. Complete Group 1 review
and corrections first, then all 17 Group 2 fittings, followed by Group 3.
After each batch, revise the checked drawings and repeat the comparison.

The page currently contains the [complete Group 1 batch](group-1-review.md):
22 drawings covering 19 fitting numbers. The accepted 13-drawing pilot is
preserved separately. Groups 2 and 3 remain incomplete.

## Regeneration

Import a completed export with
`python3 scripts/import-fitting-review.py '/path/to/review.json'`. The importer
checks the batch, completeness and current asset hashes before changing any
files. Archived decisions are reapplied during combined regeneration only
when the SVG and reference still match the reviewed revision.

Run `python3 scripts/generate-fittings.py`. This creates
`Public/fitting-review/data.js` with asset paths and revision hashes; it does
not overwrite browser decisions. No frontend dependency installation or CSS
build is required for this standalone review surface.

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
