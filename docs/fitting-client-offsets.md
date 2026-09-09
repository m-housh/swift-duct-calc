# Square elbows, offsets, and risers

Catalog revision `fitting-catalog-v10` contains 165 fitting choices. This slice
adds 8D–8K, 8N, and 8P; together with the earlier slices it implements 20 of the
25 approved Group 8 artwork identities at this slice.
[8L/8M and 8O have since been implemented](fitting-client-double-elbows.md).

## Inputs and source values

| Fitting | Selections | Equivalent lengths (ft), in selection order |
| --- | --- | --- |
| 8D | Hard bend / H/W = 1 / easy bend | 80 / 80 / 65 |
| 8E | Hard bend / H/W = 1 / easy bend | 10 / 10 / 10 |
| 8F | L/H = 1 / 2 / 4 | 160 / 260 / 190 |
| 8G | Fixed | 200 |
| 8H, without vanes | H/L = 0.5 / 1 / 1.5 / 2 | 55 / 330 / 430 / 470 |
| 8H, with vanes | H/L = 0.5 / 1 / 1.5 / 2 | Unavailable / 55 / 55 / 55 |
| 8I | Fixed | 20 |
| 8J | Fixed, four 45° elbows | 20 for the complete arrangement |
| 8K | R/H = 0 / 0.25 / 0.5 / 1 | 250 / 100 / 20 / 20 for the complete arrangement |
| 8N | Fixed | 10 |
| 8P, 3¼ × 10 inches | Miter / radius inside corners | 75 / 60 |
| 8P, 3¼ × 12 inches | Miter / radius inside corners | 90 / 75 |
| 8P, 3¼ × 14 inches | Miter / radius inside corners | 90 / 75 |

All table selections use typed choices. Requirements derive from the catalog's
rows. Ratios and bend/riser selections begin unanswered; 8H starts without vanes.
Evaluation never fills a missing selection. No interpolation, inclusive upper
category, or nearest-row policy is inferred for these exact ratios. The 8K zero
radius row is explicitly supported, resolving the old lookup omission.

The 8H unavailable cell remains a field-level unsupported combination. The
requirements advertise which ratios support vanes. The evaluator neither returns
zero nor substitutes the unvaned cell. Vane state is retained in the inputs and
component key. A vane selection does not change the approved illustration.

8D/8E do not inherit the angle factors of 8B/8C. Lengths for the multiple-turn
offsets cover the entire illustrated arrangement; they are not multiplied by its
elbow count. User quantity will remain separate path arithmetic.

## Internal source audit

All 30 numeric cells and the unavailable vane cell were visually read from
`Public/images/fittings/group-8/source-art/page-177.png`, corresponding to
`Public/files/ManD.Groups.pdf` viewer pages 34–35, printed page 177. PDF SHA-256:
`aae20d968d8238c8958a2c010012aca59ef4b5eed4ce749ed2b722d222997334`.
Reference conditions are 900 FPM and 0.08 IWC per 100 ft. Each imported
SVG/reference-image pair matched the accepted visual-review revision. Artwork
and prototype files are unchanged.

## Verification

The Swift 6.2 run of `swift test --filter 'Fitting|DatabaseClientTests' --jobs 4`
passes 98 tests across 20 suites, including application startup/dependency injection
and in-memory SQLite integration.

`swift test --filter Fitting --jobs 4` checks every new numeric cell on supply
and return paths, the unavailable cell, missing inputs, typed decoding, rejection
of incompatible rule families, and snapshot round trips. Requirements and artwork
are checked before selection. Catalog mutation tests reject filling the unavailable
8H cell, removing the 8K mitered row, and duplicating an 8P corner construction.

## Subsequent review

The user confirmed matching 90° elbow pairs for 8L/8M and printed inside-corner
radius categories for 8O, with mitered as the new-draft default. These decisions
are implemented in the [completed Group 8 slice](fitting-client-double-elbows.md).
