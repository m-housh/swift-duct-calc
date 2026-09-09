# Initial FittingClient source audit

This records the original five-case source check. Current implementation and
validation are documented in [the picker guide](fitting-picker-preview.md) and
[the catalog expansion audit](fitting-client-catalog-expansion.md).

## Source checks

The original five values below were visually checked against `Public/files/ManD.Groups.pdf` during
implementation, independently of the prototype's evaluator. PDF SHA-256:
`aae20d968d8238c8958a2c010012aca59ef4b5eed4ce749ed2b722d222997334`.

| Source case | PDF viewer page / printed page | Implemented values and scope |
| --- | --- | --- |
| 1F | 2 / 160 | H/W 0.50 → 120 ft; H/W 1.0 → 85 ft. Exact ratios only; retain the illustrated 10-inch minimum clearance as source guidance. |
| 2A | 5 / 163 | Downstream branches 0, 1, 2, 3, 4, 5+ → 35, 45, 55, 65, 70, 80 ft. Count to the next reducer or trunk end; preserve the actual count in the result. |
| 4A | 18 / 168 | Fixed 30 ft. |
| 5A / 5B | 20 / 169 | Both 40 ft; rectangular/round connection to a plenum large compared with duct size. The round family variant retains source code 5B. |

Groups 1, 2 and 4 state 900 FPM and 0.08 IWC/100 ft reference conditions; group 5
states 700 FPM and the same friction rate. These are recorded reference conditions,
not instructions to scale a fixed value with an arbitrary velocity.

The artwork catalog's 1F metadata points at viewer page 1, but its table is on
viewer page 2. This correction is recorded in the internal audit table above;
original artwork manifests were not changed. The runtime catalog has no PDF links.
