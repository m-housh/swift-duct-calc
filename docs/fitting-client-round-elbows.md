# 8A round elbows: typed picker inputs

Source-file paths and review hashes below record the completed import. Those
files are now retained in Git history; the app uses the
[finished SVGs and catalogs](fitting-assets.md) without a PDF or regeneration step.

This slice implements the three R/D-based 8A constructions: smooth round,
four/five-piece round, and three-piece round. Catalog revision `fitting-catalog-v7`
contains 148 fitting choices. This is the historical R/D slice; the [remaining 8A constructions](fitting-client-8a-constructions.md)
and [8B/8C](fitting-client-rectangular-elbows.md) have since been implemented.
The production step-3 picker is not wired up yet.

## Confirmed input model

`Fitting.RoundElbowRadiusRatio` declares exactly three choices: **0.75**, **1.0**,
and **1.5 or greater**. The final case represents the inclusive source range.
Its encoded identity is 1.5; users select that category for larger physical ratios.
There is no arbitrary numeric R/D input, intermediate-ratio rounding, or interpolation.

`Fitting.ElbowAngle` declares 20°, 30°, 45°, 60°, 75°, 90°, 110°, 130°, and 150°.
Each fitting's `InputRequirement.roundElbow` advertises the supported R/D and angle
choices. Smooth round elbows support all nine angles; the two segmented
constructions support only 90°. Draft inputs default the angle to 90° and leave
R/D unselected. Evaluation requires both selections and never fills missing values.
Both enums provide labels for the future UI picker.

These definitions and `Inputs.roundElbow` live in `Sources/ManualDCore/Fittings.swift`.
The bundled catalog holds source values and angle factors. Calculation lives in
`Sources/FittingClient/Internal/RoundElbow.swift`; no calculation was added to
ManualDCore. Existing dimension-based rules in other groups retain their policies.

## Source values

| R/D category | Smooth round | Four/five-piece | Three-piece |
| --- | --- | --- | --- |
| 0.75 | 20 ft | 30 ft | 35 ft |
| 1.0 | 15 ft | 20 ft | 25 ft |
| 1.5 or greater | 10 ft | 15 ft | 20 ft |

Smooth round elbows multiply the selected 90° base length by the following factor:

| Angle | 20° | 30° | 45° | 60° | 75° | 90° | 110° | 130° | 150° |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Factor | 0.31 | 0.45 | 0.60 | 0.78 | 0.90 | 1 | 1.13 | 1.20 | 1.28 |

The 90° factor is the identity for the base table. Fractional results are preserved:
for example, smooth round R/D 1.0 at 20° is 15 × 0.31 = 4.65 ft. Calculations retain
the typed selections, a component key identifying the base row and angle, and
catalog/rule revisions. Angle factors do not apply to the other two constructions.

## Internal source audit

Reviewed `Public/files/ManD.Groups.pdf`, viewer page 32, printed page 176.
PDF SHA-256: `aae20d968d8238c8958a2c010012aca59ef4b5eed4ce749ed2b722d222997334`.
Reference conditions are 900 FPM and 0.08 IWC per 100 ft.

The PDF confirms that at R/D 1.0, four/five-piece is **20 ft** and three-piece is
**25 ft**. The new evaluator uses these source columns; the old lookup's apparent
swapped mapping is not copied. This slice does not modify legacy project behavior.

The smooth-round angle heading says “less than 90°” but explicitly lists 110°,
130°, and 150°. The user confirmed using all listed angles plus 90°. This heading
discrepancy stays in internal notes, and does not imply support for unlisted angles.

The three artwork references were imported from
`Public/images/fittings/group-8/manifest.json`. SHA-256 of each SVG plus its reference
image matched its accepted review revision. Original images and manifests are
unchanged. All three constructions retain source code and family ID `8A`, with
distinct fitting IDs, so reference lookup returns the available construction candidates.

## Verification

`swift test --filter Fitting --jobs 4` passes 55 tests in ten suites with Swift 6.2.
Tests cover the nine base
table cells on supply and return paths, all 27 smooth-round R/D-and-angle combinations,
fractional snapshot round trips, picker choices/defaults, rejection of arbitrary
decoded values, missing selections, incompatible inputs, and unsupported angles
on segmented elbows. The full catalog validation and deployed-artwork checks include
these three new cases.
