# Group 7: panned stud and joist returns

Source-file paths and review hashes below record the completed import. Those
files are now retained in Git history; the app uses the
[finished SVGs and catalogs](fitting-assets.md) without a PDF or regeneration step.

This slice adds 7A–7E to `FittingClient`, bringing the catalog to 145 fitting
choices at revision `fitting-catalog-v6`. It includes five calculation cases and
nine approved artwork views. Production step-3 UI and project persistence remain
separate work.

## Confirmed rules

Use the nearest published CFM row, with midpoint ties selecting the higher CFM
row. Apply the supported airflow range before rounding. Inputs below the first
row or above the source maximum are unresolved; do not clamp or interpolate.

| Fitting | Supported CFM | Published CFM → equivalent length (ft) |
| --- | --- | --- |
| 7A | 100–200 | 100 → 25; 150 → 25; 200 → 25 |
| 7B | 100–200 | 100 → 10; 150 → 15; 200 → 25 |
| 7C | 100–400 | 100 → 10; 200 → 30; 300 → 60; 400 → 110 |
| 7D | 100–200 | 100 → 20; 150 → 50; 200 → 90 |
| 7E | 200–800 | 200 → 10; 400 → 30; 600 → 60; 800 → 110 |

For example, 7C at 249 CFM selects 200 CFM / 30 ft; 250 CFM selects 300 CFM /
60 ft. A 7A input of 201 CFM is unsupported even though its nearest row is 200.
7A still requires airflow despite having the same length in all three rows.

7C optionally adds the source's 40 ft merging-flow adjustment once. The input
defaults to `mergingFlow: false`; enabling it for another group 7 fitting returns
an unsupported-combination issue. At 250 CFM with merging enabled, the result is
60 + 40 = 100 ft. Quantity is independent of this adjustment.

These are approximate values for existing panned framing returns. Source guidance
does not recommend panning for new systems, does not provide an obstruction sizing
procedure, and identifies leakage effects. Those applicability notes accompany
the results. The reference conditions are 700 FPM and 0.08 IWC per 100 ft.

## Contracts and implementation

- `Sources/ManualDCore/Fittings.swift` declares `Inputs.pannedReturn`, its input
  requirement, supported artwork views, airflow issues, and optional
  `Calculation.AirflowSelection`. The latter retains entered and selected CFM
  and exposes `wasRounded` for an eventual UI indicator. Existing calculation
  snapshots can decode without this optional field.
- `Sources/FittingClient/Internal/PannedReturn.swift` validates airflow, selects
  the row, and adds the merging component. Original inputs and each length
  component are preserved in the result. No new calculation lives in ManualDCore.
- The bundled catalog supplies table rows, the 7C adjustment, and artwork. Its
  first and last CFM rows define the supported bounds. Full authored-data
  validation stays in the test-only `CatalogValidator`.
- `Definition.availableViews` advertises the available drawings. Artwork lookup
  resolves an explicitly requested view and never substitutes an unavailable one.

| Logical fitting | Available views |
| --- | --- |
| 7A, 7B | Individual, assembly |
| 7C | Individual, assembly, assembly with merging flow |
| 7D, 7E | Individual |

Views share the fitting ID and source code; choosing assembly artwork alone does
not add length. The future picker should pair the merging drawing with the 7C
merging input. Artwork lookup remains usable before a calculation is complete.

## Internal source audit

Tables and applicability were checked against `Public/files/ManD.Groups.pdf`,
viewer pages 30–31, printed page 175. PDF SHA-256:
`aae20d968d8238c8958a2c010012aca59ef4b5eed4ce749ed2b722d222997334`.
This document is internal MVP reference material; PDF metadata is not part of the
runtime contracts or catalog.

Artwork comes from `Public/images/fittings/group-7-options/manifest.json`.
All nine SVG/reference byte pairs were hashed and matched to their accepted
visual-review revisions during import. The original SVGs and manifests are
unchanged. Numeric rows were separately compared with the manifest's source data.

## Verification

`swift test --filter Fitting --jobs 4` passes 50 tests in nine suites using Swift
6.2. Group 7 coverage includes all 17 source cells, every midpoint immediately
below/at/above the tie, exact and out-of-range bounds, missing/nonfinite/nonpositive
airflows, return-only eligibility, merge applicability and addition, snapshot
round trips, five logical identities, and nine deployed artwork routes. Catalog
mutation tests cover invalid alternate views/paths, airflow order, and adjustments.
Existing fitting and dependency-injection tests continue to pass.

Remaining rule review continues one group at a time; this slice settles group 7.
