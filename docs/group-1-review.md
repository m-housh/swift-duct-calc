# Complete Group 1 drawing batch

The review page now presents **22 drawings covering all 19 Group 1 fitting
numbers shown in the PDF**. The source skips 1J. Completion here means drawing
coverage, not visual approval.

The five accepted 1A–1E SVGs are unchanged. Seventeen new drawings cover the
remaining 14 numbers, including separate vane-count variants for 1M and 1S.
The first Group 1 review accepted 20 drawings and requested vane-orientation
corrections on 1P and 1Q. The follow-up review accepted both corrected drawings.
All 22 Group 1 drawing revisions are now visually approved. Both reviews are
archived under `docs/fitting-reviews/`.

| Printed page | Fittings | New variants / conditions |
| --- | --- | --- |
| 159 | 1A–1E | Previously accepted |
| 160 | 1F, 1G, 1H, 1I | H/W tables for F, G and H; vanes on I |
| 161 | 1K, 1L, 1M, 1N | R/W tables for L and M; M has one- and two-vane assets |
| 162 | 1O, 1P, 1Q, 1R, 1S, 1T | H/W table for O; S has zero-, one- and two-vane assets |

The new drawings follow the source side elevations in scan coordinates.
Paired diagrams retain their shared source crop while each SVG isolates its
selected connection. Equipment is shown as a cutaway outline. Reference crops
include source tables; the review UI pairs each with the corresponding SVG.

Ratio-dependent reference lengths are stored as `referenceEquivalentLengthTable`
with an explicit `H/W` or `R/W` parameter. Vane variants preserve their original
fitting number and add a distinct asset ID, such as `1M-1-vane`. Fixed values
remain `referenceEquivalentLengthFeet`. The 1N note retains the instruction to
add its transition EL to the upstream elbow or tee EL. These are reference
transcriptions and have not been connected to calculations.

## Review and checkpoints

Refresh `/fitting-review/`. Check only drawings needing more work, add notes,
finish the batch and download its review. The new batch ID is `group-1`; prior
`pilot-01` browser decisions and the imported pilot review remain preserved.
Previously accepted 1A–1E are included for context and marked accordingly.

The left-hand vanes of 1P and the vanes of 1Q now curve toward their leftward
flow. The follow-up export retained the earlier issue text as review history;
its accepted status and corrected revision hashes record that the concerns are
resolved.

Finish Group 1 review and revisions before proceeding to Group 2. Keep commits
at coherent checkpoints: generated batch ready for review, imported decisions,
and completed correction passes. A commit does not itself mark drawings accepted.

## Reproduce

`python3 scripts/generate-fittings.py` regenerates the complete catalog,
reapplies approvals only to exact reviewed revisions, and rebuilds the active
Group 1 review batch. It maintains the archived pilot batch manifest so earlier
exports remain importable. No package installation is required.

Reference crops are committed. To recreate the 14 new crops from the PDF, run
`python3 scripts/extract-group-one-references.py` with Poppler and ImageMagick
installed. Crop coordinates, source image indices and printed pages live in
`scripts/fitting_group_one.py` and each catalog entry's source metadata.

The legacy pilot scripts remain implementation helpers. Use the combined
`generate-fittings.py` command for the complete deliverable.
