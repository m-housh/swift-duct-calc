# Group 3 reducing-trunk takeoffs

Source-file paths and review hashes below record the completed import. Those
files are now retained in Git history; the app uses the
[finished SVGs and catalogs](fitting-assets.md) without a PDF or regeneration step.

Catalog revision `fitting-catalog-v12` contains 202 fitting choices, including all
32 approved Group 3 construction identities. Group 3 is supply-only. Existing
artwork and legacy project lookup behavior are unchanged.

## Source audit

The values below were visually checked directly against `Public/files/ManD.Groups.pdf`,
viewer pages 10–13, printed pages 166–167. PDF SHA-256 remains
`aae20d968d8238c8958a2c010012aca59ef4b5eed4ce749ed2b722d222997334`.
Reference conditions are 900 FPM and 0.08 IWC per 100 ft. Each imported
SVG/reference-image pair matched its accepted visual-review revision.

| Cases | EL (ft) |
| --- | --- |
| 3A / 3I | 15 |
| 3B / 3L | 30 |
| 3C / 3K | 20 |
| 3D / 3J full, tight, mitered | 35 / 55 / 110 |
| 3E | 30 |
| 3F full, tight, mitered | 50 / 70 / 125 (3D + 15) |
| 3G / 3H | 35 |
| 3M / 3N | 25 / 40 |
| 3O / 3R | 20 |
| 3P / 3Q | 50 / 35 |
| 3S full, tight, mitered | 15 / 35 / 90 |
| 3T | 10 |
| 3U mitered with / without vanes | 10 / 80 |
| 3V / 3W | 30 |

The source discrepancies are recorded explicitly:

- **3W:** its specific drawing on viewer page 13 labels EL = 30. The old lookup's
  full/tight/mitered values correspond to the adjacent 3S table, not 3W.
- **3J:** the overview explicitly groups it with 3D; all three construction
  values are included even though the old lookup omitted 3J.
- **3U:** the overview groups 3S/3U under radius categories, but viewer page 12
  gives a specific mitered 3U table with vanes yes = 10, no = 80. The approved
  3U artwork identities represent that detailed case, so the new catalog uses
  the specific table rather than applying the overview's 90-ft mitered 3S row.

## Assembly and sleeve inputs

Construction variants remain distinct application IDs with explicit display
names. They share their printed source code. Fixed assembly lengths include the
named elbows/transitions; callers must not add those parts again.

For 3O/3P/3Q/3R the source says to add 15 ft if the round sleeve is simply butted
to the transition wall. `Inputs.easedTakeoff(buttedSleeve:)` exposes that condition,
defaulting false for a new draft. The evaluator adds one separately keyed 15-ft
component when selected. It does not apply that note to unrelated fittings.
Inputs and both components survive snapshot encoding; quantity remains separate.

## Verification

The fitting tests independently cover all 32 base values, both sleeve states for
all four applicable fittings, return-path rejection, incompatible rule inputs,
snapshot round trips, construction identities, defaults, and deployed artwork.
