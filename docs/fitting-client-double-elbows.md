# Double elbows and inside-corner offsets

Catalog revision `fitting-catalog-v11` contains 170 fitting choices and completes
all 25 Group 8 artwork identities. The user confirmed matching 90° elbow pairs
for 8L/8M and the printed inside-corner radius choices for 8O. Mitered is the
user-requested default/common 8O construction for new drafts.

## Double-elbow behavior

8L uses 1.7 times one elbow's equivalent length; 8M uses 2.0. A smooth round
R/D = 1 elbow is 15 ft, so the pair is 25.5 ft for 8L or 30 ft for 8M.
Apply that multiplier once to the base, with no further multiplication by two.
Path quantity counts complete pairs.

The round choices are the smooth, four/five-piece, three-piece, and mitered 8A
90° constructions. Rectangular choices are 8B, 8C, 8D, and 8E. The selected
construction and inputs represent both elbows. The evaluator reuses the existing
single-elbow rules and requires the 90° angle where the base accepts an angle.
Oval, 45°-only, other-angle, unrelated, wrong-shape, and composite bases are
unavailable. Catalog validation checks the allowed base references; runtime checks
also prevent recursive evaluation even if a malformed catalog includes a cycle.

`Inputs.doubleElbow` contains a base ID and its typed inputs; it accepts no
supplied EL. Neither selection defaults to an arbitrary construction.
`Calculation.derivation.scaled` retains the complete base calculation and
multiplier, including source identity, conditions, inputs, and rule revisions.
The outer component contains the final pair length only. Existing calculations
decode without this optional derivation. Artwork works before base selection.

## 8O inside-corner radius

| Typed choice | Printed meaning | EL (ft) |
| --- | --- | ---: |
| Mitered | R = 0 | 235 |
| One quarter | R = 0.25 | 90 |
| Greater than one half | R > 0.50 | 45 |

The user identified R as the inside corner radius and accepted presenting these
printed categories. The selector does not invent units or a ratio denominator.
Stable string identities preserve the strict final category; numeric 0.50 and an
inclusive “0.50 or greater” are not accepted aliases. New drafts default to
mitered, while missing submitted inputs remain missing.

## Audit and verification

Values and diagrams were read from the Group 8 full scan, printed page 177,
corresponding to `Public/files/ManD.Groups.pdf` viewer pages 34–35. PDF SHA-256:
`aae20d968d8238c8958a2c010012aca59ef4b5eed4ce749ed2b722d222997334`.
Reference conditions remain 900 FPM and 0.08 IWC per 100 ft. All five imported
SVG/reference-image pairs matched their accepted review revisions.

`swift test --filter Fitting --jobs 4` covers every allowed base configuration on
both path types, the confirmed fractional example, full snapshot round trips,
incomplete inputs, unsupported angles/shapes, recursive requests and malformed
catalog cycles, all three 8O cells, the mitered default, and strict category decoding.
