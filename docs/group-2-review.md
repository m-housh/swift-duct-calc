# Complete Group 2 drawing batch

The review page contains **all 17 Group 2 fittings, 2A–2Q**. The accepted 2B,
2K and 2N assets and reference images are unchanged. Fourteen new source-traced
SVGs await review. Group 1 remains complete and approved.

| Printed page | Fittings | Distinctions retained |
| --- | --- | --- |
| 163 | 2A–2H | Round and rectangular branches; tapered/flared entries; projecting entry details |
| 164 | 2I–2M | Round elbows; rectangular bases; curved and square heels |
| 165 | 2N–2Q | Angled and elbow branches; straight and tapered collars on round trunks |

New contours use original scan coordinates and preserve the source perspective.
Neighboring fittings are omitted from each SVG; unretouched reference crops
retain surrounding marks. The 2O–2Q drawings retain trunk seam arcs and short
trunk continuations so the branch connection remains understandable. Dashed
entry details on 2C and 2F–2H follow the source. Fitting names are descriptive
labels; the fitting numbers remain the authoritative identifiers.

## Review

Refresh `/fitting-review/`. The active batch is now `group-2`. Check only the
drawings that need more work, add notes, finish the review and download its JSON
file. Share it in this task to import decisions and begin any correction pass.

Group 1 and pilot review files and browser state remain separate. All batch
manifests remain available under `Public/fitting-review/batches`; importing an
older completed review still validates against that batch and its exact asset
revisions.

## Reference lengths

Each Group 2 fitting has six reference equivalent lengths, corresponding to
0, 1, 2, 3, 4, and 5 or more downstream branches. All 102 entries are represented
in the catalog. Count to the trunk end or the next reducer, and restart the
count after each reducer. Reference conditions are 900 FPM and 0.08 IWC per
100 feet. These transcriptions are not connected to the app's calculations.

The review concerns drawing accuracy. A future selector must also collect the
downstream branch count to select the appropriate value.

## Regeneration

Run `python3 scripts/generate-fittings.py` to regenerate all drawings and the
active Group 2 review, preserving approvals for unchanged asset revisions.
To view the archived Group 1 batch instead, run
`python3 scripts/generate-fitting-review.py --batch group-1`.

The 14 new reference crops are committed. Recreate them with
`python3 scripts/extract-group-two-references.py` (requires Poppler and
ImageMagick). Their source image indices, crop rectangles and printed pages
are recorded in `scripts/fitting_group_two.py` and the catalog.
