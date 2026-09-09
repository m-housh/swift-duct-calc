# Remaining 8A constructions

Source-file paths and review hashes below record the completed import. Those
files are now retained in Git history; the app uses the
[finished SVGs and catalogs](fitting-assets.md) without a PDF or regeneration step.

Catalog revision `fitting-catalog-v9` contains 155 fitting choices and completes
all eight 8A construction identities. The existing radius-based round elbow rules
and the 8B/8C rules are unchanged. The production picker is still pending.

## Source values and inputs

| Construction | Input | Equivalent length (ft) |
| --- | --- | ---: |
| Smooth mitered round, 90° | Fixed, inside radius zero | 75 |
| Easy-bend oval, 90° | Three pieces | 30 |
| Easy-bend oval, 90° | Four pieces | 25 |
| Hard-bend oval, 90° | Three pieces | 35 |
| Hard-bend oval, 90° | Four pieces | 30 |
| Three-piece round, 45° | Fixed | 10 |
| Two-piece round, 45° | Fixed | 15 |

The oval rules expose `OvalElbowPieceCount` with only three/four choices and no
default selection. A missing submitted piece count returns a field issue. These
constructions have no adjustable radius or angle and do not apply smooth-round
angle multipliers. Fixed constructions use the existing fixed-input rule.
`Fitting.Shape.oval` keeps oval drawings distinct from round and rectangular ones.

Both oval piece counts share their construction's approved illustration; piece
count is a calculation input, not a claim of separate count-specific artwork.
Reference lookup for 8A returns all eight construction IDs without selecting one.
Calculation snapshots preserve the selected piece count and source-row key.

## Internal source audit

The values were visually read from the full source scan at
`Public/images/fittings/group-8/source-art/page-176.png`, corresponding to
`Public/files/ManD.Groups.pdf` viewer page 32, printed page 176. The PDF hash remains
`aae20d968d8238c8958a2c010012aca59ef4b5eed4ce749ed2b722d222997334`.
Reference conditions are 900 FPM and 0.08 IWC per 100 ft. PDF provenance stays out
of runtime metadata. Each imported SVG/reference-image pair matched its accepted
visual-review hash; no artwork or prototype files changed.

## Verification

At this slice, the fitting suite passed 62 tests across 12 suites with Swift 6.2.

`swift test --filter Fitting --jobs 4` covers all seven new source values on both
path types, missing and incompatible inputs, unsupported piece-count decoding,
snapshot round trips, all eight source identities, and artwork before selection.
The catalog validator requires the two oval piece-count rows in canonical order.
