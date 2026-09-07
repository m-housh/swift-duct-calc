# 8B and 8C: rectangular radius elbows

This slice adds the rectangular radius elbow without turning vanes (8B) and with
turning vanes (8C). Catalog revision `fitting-catalog-v8` contains 150 fitting
choices. Both fittings are available on supply and return paths. Production
step-3 UI wiring remains pending.

## Confirmed input choices and defaults

| Input | Typed choices | New-draft default |
| --- | --- | --- |
| R/W | Mitered (0), 0.25, 0.5 or greater | Mitered |
| Bend category | Hard bend, square cross-section (H/W = 1), easy bend | Unselected |
| Angle | 30°, 45°, 60°, 90° | 90° |

The user confirmed an explicit picker for bend category and requested mitered as
the R/W default. The bend category remains a required selection; it is not inferred
from project dimensions. The final R/W choice includes all larger ratios and has a
stable encoded identity of 0.5. Arbitrary numeric ratios and interpolation are not
supported. Defaults populate a new draft only; evaluation reports missing inputs
when a request omits them.

`Sources/ManualDCore/Fittings.swift` declares `RectangularElbowRadiusRatio`,
`ElbowBendCategory`, and the rectangular elbow input/requirement cases. The existing
`ElbowAngle` enum is reused with a fitting-specific subset. Each enum supplies
picker labels; each definition advertises its available choices and defaults.

`Sources/FittingClient/Internal/RectangularElbow.swift` selects the exact R/W and
bend-category cell, then multiplies it by the supported angle factor. Source tables
and factors live in the bundled catalog. Full table validation remains test-only.

## Verified source values

These are the 90° base equivalent lengths in feet:

| Fitting | R/W | Hard bend | H/W = 1 | Easy bend |
| --- | --- | --- | --- | --- |
| 8B | Mitered (0) | 90 | 75 | 65 |
| 8B | 0.25 | 35 | 30 | 25 |
| 8B | 0.5 or greater | 20 | 15 | 10 |
| 8C | Mitered (0) | 30 | 25 | 40 |
| 8C | 0.25 | 10 | 10 | 10 |
| 8C | 0.5 or greater | 5 | 5 | 5 |

Both tables list factors of **0.45 at 30°**, **0.60 at 45°**, and **0.78 at 60°**.
The 90° base uses a factor of one. Fractional results are retained; for example,
8B with mitered R/W, square cross-section, and 30° is 75 × 0.45 = **33.75 ft**.
The other angles available for smooth round 8A elbows are rejected for 8B/8C.

Each calculation retains its typed input selections, the resulting component's
R/W/category/angle key, source identity, and catalog/rule revisions. These are
single-fitting results; quantity remains separate.

## Internal source audit

Tables and angle factors were reviewed against `Public/files/ManD.Groups.pdf`,
viewer page 33, printed page 176. PDF SHA-256:
`aae20d968d8238c8958a2c010012aca59ef4b5eed4ce749ed2b722d222997334`.
Reference conditions are 900 FPM and 0.08 IWC per 100 ft. PDF provenance stays in
internal notes rather than runtime contracts or catalog entries.

Artwork references come from `Public/images/fittings/group-8/manifest.json`.
Each SVG plus reference-image byte pair matched its accepted visual-review hash
during import. The original artwork and manifests are unchanged. Each fitting's
existing drawing is available before the input selections are complete.

## Verification and remaining work

`swift test --filter Fitting --jobs 4` passes 59 tests in 11 suites with Swift 6.2.
The new tests cover all
18 base source cells and all 72 supported R/W/category/angle combinations on both
supply and return paths, the mitered/90° defaults, missing selections, unsupported
angles, incompatible inputs, typed decoding, fractional snapshot round trips,
source identity, and artwork routing. Catalog validation checks that every
R/W/category pair occurs once in canonical order and that angle factors match the
source. Existing round elbow tests remain scoped to the 8A family.

The [other 8A constructions](fitting-client-8a-constructions.md) are now implemented.
The [offset slice](fitting-client-offsets.md) now covers 8D–8K, 8N, and 8P.
Group 8 remains partially implemented: 8L/8M and 8O still need implementation. Rules will continue to be reviewed one group at a time.
