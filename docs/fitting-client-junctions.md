# Fitting catalog: return boots and trunk junctions

The junction work now covers all of groups 6, 9, and 10. The catalog contains
140 choices at revision `fitting-catalog-v5`. The latest addition is 6A–6E, using
the user's confirmed nearest-published-row policy and returning both branch and
trunk contributions.

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

- `Sources/ManualDCore/Fittings.swift`: typed junction path, airflow inputs,
  requirements, and a separate paired result for return junctions.
- `Sources/FittingClient/Internal/Catalog.swift`: optional path on source rows and
  junction presentation requirements.
- `Sources/FittingClient/Internal/Evaluation.swift`: explicit group 9 path lookup.
- `Sources/FittingClient/Internal/ReturnJunction.swift`: group 6 airflow validation,
  nearest-row selection, and both branch/trunk contributions.
- `Sources/FittingClient/Resources/catalog.json`: all 41 verified definitions in
  groups 6, 9, and 10.
- `Tests/FittingClientTests/JunctionTests.swift`: independent source values, both
  path choices, missing inputs, eligibility, snapshot encoding, and coverage.
- `Tests/FittingClientTests/CatalogValidator.swift`: test-only validation requires
  exactly one row per group 9 path, ordered group 6 ratios, and valid trunk cells.
- `Tests/FittingClientTests/ReturnJunctionTests.swift`: both source columns,
  midpoint boundaries, range semantics, rounding metadata, and path-total examples.

## Internal source audit

Values were read directly from `Public/files/ManD.Groups.pdf`, then compared with
approved artwork metadata. PDF SHA-256 remains
`aae20d968d8238c8958a2c010012aca59ef4b5eed4ce749ed2b722d222997334`.
Viewer-page numbers are one-based; these references remain internal documentation.

| Cases | Viewer pages | Printed page | Verified EL values (ft) |
| --- | --- | --- | --- |
| 6A–6C | 25 | 172 | Both columns at ≤0.4, 0.5, 0.6, 0.7, 0.8, 1.0; trunk is NA at 1.0 |
| 6D–6E | 27 | 173 | Both columns at each printed ratio; trunk is NA at 1.0 |
| 6F–6H | 28 | 174 | 25, 30, 15 |
| 6I–6P | 29 | 174 | 30, 55, 10, 20, 20, 10, 10, 5 |
| 9A–9J | 36–37 | 178 | Branch: 80, 80, 80, 75, 50, 45, 35, 100, 85, 25. Main: 5 for all ten. |
| 9K–9M | 37 | 178 | 65, 20, 20 |
| 9N–9R | 38 | 179 | 15, 15, 70, 55, 35 |
| 10A–10G | 40–41 | 180 | 75, 10, 10, 25, 25, 35, 75 |

Group 6 and 10 reference velocity is 700 FPM; group 9 is 900 FPM. All use
0.08 IWC/100 ft. These remain conditions, not a velocity-scaling formula.

All 41 SVG/reference-image pairs match their approved review revisions. Artwork
paths and descriptive names come from the approved group manifests. 6N's guidance
retains the source's allowance for a round or square narrow-end connection. No
artwork or prototype files were modified.

## Confirmed group 6 lookup policy

Use only equivalent lengths in the original table. Compute branch CFM1 / combined
downstream trunk CFM2, then choose the nearest published ratio row. At the midpoint
between rows, choose the higher ratio:

| 6A calculated ratio | Selected row | Branch EL | Trunk EL |
| --- | --- | --- | --- |
| 0.74 | 0.7 | 60 ft | 25 ft |
| 0.75 | 0.8 | 75 ft | 25 ft |

The midpoint rule applies to actual neighboring rows, including uneven gaps:
6D's midpoint between 0.4 and 0.6 is 0.5; 6E's midpoint between 0.5 and 0.8 is
0.65. No unlisted ratio row or interpolated equivalent length is invented.

The ratio is not rounded for display before row selection. For example,
530 / 707 ≈ 0.749646 selects 0.7, even though displaying only two decimal places
would show 0.75. The result preserves the calculated ratio and selected ratio;
the UI should show enough precision to explain a selection near a boundary.
Decimal arithmetic constructs the table midpoints so binary representations do
not send an exact decimal tie such as 0.15 to the lower 0.1 row.

These limits remain explicit:

- 6A–6C have a source-defined 0.40-or-less range. Values within that range return
  its published lengths and are marked `sourceRange`, not `rounded`.
- 6D/6E have no supported range below 0.10; such inputs remain unresolved.
- Both airflows must be finite and positive, and branch flow cannot exceed total.
- An exact row is marked `exact`; any nearest-row adjustment is marked `rounded`.
- The selected 1.0 row has an NA trunk cell. This remains unavailable even when
  a nearby ratio rounded to that row; it is never represented as zero.
- H/W and R/W rules keep their previously reviewed exact-match behavior. This
  nearest-row policy is specific to group 6 airflow tables.

### Both values and path totals

`Inputs.returnJunction(branchCFM:totalCFM:)` does not ask the caller to discard one
column. `Evaluation.resolvedReturnJunction` returns a `ReturnJunctionCalculation`
containing separate `branch` and optional `trunk` components, the original inputs,
ratio-selection metadata, conditions, and catalog/rule revisions. An unavailable
trunk component explicitly represents the selected table's NA cell.

The paired result is distinct from a single-length `Calculation`: there is no
misleading sum or implicit choice of branch versus trunk. Both component keys
identify their source row and column, e.g. `6A/0.8/branch` and `6A/0.8/trunk`.
This supplies the future picker with an adjustment indicator and the future
`ProjectClient` path orchestration with both contributions.

The source's path example on viewer page 26 illustrates where they belong. Each
path uses its entry branch length, then the trunk contribution at each subsequent
junction toward the air handler. With the confirmed row-selection policy:

| Path | Fitting contributions | Total fitting length |
| --- | --- | --- |
| R1 | Entry branch 75 + R2 trunk 25 + R3 trunk 10 | 110 ft |
| R2 | Entry branch 60 + R3 trunk 10 | 70 ft |
| R3 | Entry branch 10 | 10 ft |

R2 uses the unrounded ratio 530/707 and therefore the 0.7 table row. The printed
worked example uses an intermediate EL of 68; this application intentionally uses
only the original table values per the user's instruction. Project topology,
path persistence, and the visible picker indicator will be wired in their own
integration pass; the evaluator now returns the information they require.

## Verification

```sh
swift test --filter Fitting --jobs 4
```

43 tests pass in eight suites, including both original table columns for all
five group 6 junctions, 17 midpoint boundaries (below/at/above each boundary),
the user's rounding examples, source ranges, NA cells, invalid inputs, paired
snapshot encoding, and path-total assembly. The 26 fixed-value fixtures and both
paths for all ten group 9 branch/main junctions also pass. The asset integration
check now covers all 140 entries. Existing startup, source-table, input-validation, reference lookup,
and snapshot tests also pass. Step-3 UI and persistence integration remain pending.
