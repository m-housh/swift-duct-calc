# Fitting catalog: return boots and trunk junctions

This slice adds 36 choices, bringing `fitting-catalog-v4` to 135. Group 9 and group
10 are fully covered; group 6 includes its fixed return boots (6F–6P). The five
flow-ratio junctions 6A–6E await the interpolation decision below.

## Behavior and code to review

`Fitting.Inputs.junction(path:)` distinguishes the branch and main route through
9A–9J. The path must be supplied explicitly. The evaluator returns only the
selected path's equivalent length, with a component key such as `9A/branch` or
`9A/main`; it never sums the two table columns. Inputs and component identity
survive calculation snapshot encoding.

`JunctionPath` is independent of `PathType`: supply/return controls eligibility,
while branch/main identifies the route through the fitting. The input requirement
is `.junction`, and the initial input is `.junction(path: nil)`.

The remaining added entries use the existing fixed rule. A fixed-value junction
such as 9K does not gain an unnecessary branch/main selector. Group 9 conditions
preserve the distinction between a secondary trunk carrying a substantial share
of primary airflow and the group 2 branch-runout application. Group 10 conditions
identify two merging return trunks and refer branch returns to group 6.

Files to review:

- `Sources/ManualDCore/Fittings.swift`: typed junction path, input, requirement,
  and validation fields/results.
- `Sources/FittingClient/Internal/Catalog.swift`: optional path on source rows and
  junction presentation requirements.
- `Sources/FittingClient/Internal/Evaluation.swift`: explicit path lookup.
- `Sources/FittingClient/Resources/catalog.json`: 36 verified definitions.
- `Tests/FittingClientTests/JunctionTests.swift`: independent source values, both
  path choices, missing inputs, eligibility, snapshot encoding, and coverage.
- `Tests/FittingClientTests/CatalogValidator.swift`: test-only validation requires
  exactly one row per junction path in canonical order.

## Internal source audit

Values were read directly from `Public/files/ManD.Groups.pdf`, then compared with
approved artwork metadata. PDF SHA-256 remains
`aae20d968d8238c8958a2c010012aca59ef4b5eed4ce749ed2b722d222997334`.
Viewer-page numbers are one-based; these references remain internal documentation.

| Cases | Viewer pages | Printed page | Verified EL values (ft) |
| --- | --- | --- | --- |
| 6F–6H | 28 | 174 | 25, 30, 15 |
| 6I–6P | 29 | 174 | 30, 55, 10, 20, 20, 10, 10, 5 |
| 9A–9J | 36–37 | 178 | Branch: 80, 80, 80, 75, 50, 45, 35, 100, 85, 25. Main: 5 for all ten. |
| 9K–9M | 37 | 178 | 65, 20, 20 |
| 9N–9R | 38 | 179 | 15, 15, 70, 55, 35 |
| 10A–10G | 40–41 | 180 | 75, 10, 10, 25, 25, 35, 75 |

Group 6 and 10 reference velocity is 700 FPM; group 9 is 900 FPM. All use
0.08 IWC/100 ft. These remain conditions, not a velocity-scaling formula.

All 36 SVG/reference-image pairs match their approved review revisions. Artwork
paths and descriptive names come from the approved group manifests. 6N's guidance
retains the source's allowance for a round or square narrow-end connection. No
artwork or prototype files were modified.

## Pending decision: 6A–6E interpolation

The group 6 tables and examples were inspected on viewer pages 25–28 (printed
172–173). Their ratio is branch airflow CFM1 divided by the combined downstream
trunk airflow CFM2. Each table distinguishes branch EL from the trunk contribution
for a path arriving from upstream.

The examples demonstrate between-row values:

- On viewer page 26, 6A at a displayed ratio of 0.75 uses 68 ft. Its neighboring
  table rows are 0.70 → 60 ft and 0.80 → 75 ft. Linear interpolation at 0.75 is
  67.5 ft. The example also displays the ratio rounded from 530/707.
- On viewer page 27, the 6E example uses 35 ft at a displayed ratio of 0.25,
  between 0.20 → 30 ft and 0.30 → 40 ft.

The examples support interpolation, but do not specify a general rounding
procedure for ratios or final lengths. The user prefers the higher equivalent
length, a visible adjustment indicator, and a 0.5 rounding factor. Clarification
is pending on whether this means interpolating and rounding up to the next 0.5 ft,
or selecting the higher neighboring table value. These five cases are not added
until that distinction is settled.

Further semantics to preserve whichever option is selected:

- The 0.40-or-less row applies only to 6A–6C; 6D/6E start at 0.10.
- CFM1/CFM2 = 1 has no applicable trunk value. An NA cell must not become zero or
  borrow the branch value.
- The branch and trunk values belong to different path contributions. Evaluation
  must not automatically add both to a selected fitting.
- No extrapolation beyond supported source ranges.

## Verification

```sh
swift test --filter Fitting --jobs 4
```

35 tests pass in seven suites, including 26 added fixed-value fixtures and both
paths for all ten branch/main junctions. The asset integration check now covers
all 135 entries. Existing startup, source-table, input-validation, reference lookup,
and snapshot tests also pass. Step-3 UI and persistence integration remain pending.
