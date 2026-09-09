# Finished fitting assets

Fitting artwork extraction and approval are complete. The checked-in SVGs are
final assets. Building, running, testing, and maintaining the app require no
reference PDF, artwork generation, packaging, or batch approval step.

The two catalog files are maintained directly:

- `Sources/FittingClient/Resources/catalog.json` holds the picker's 227 fitting
  definitions, calculation rules, artwork paths, and duct-shape classifications.
- `Public/fittings/catalog-data.js` holds the public reference's 231 records,
  including its separate Group 11 concept. `catalog-rules.js` adapts their tables
  for display and export. This reference data is separate from calculation rules.

Together they use 234 distinct SVG files under `Public/images/fittings` and
`Public/fittings/concepts`. Each SVG is self-contained. Some embed raster artwork;
those embedded bytes are part of the approved drawing and need no external PNG.
All served SVGs and the calculation catalog were preserved byte-for-byte when
the extraction workflow was retired.

The reference PDF, local artwork-review page, extraction and packaging scripts,
source manifests, unused crops, comparison sheets, and superseded drawings have
been removed. The public reference and guided templates link to the fitting
reference itself. Reference exports retain the Manual D citation and printed
page, without links to retired files.

## Historical evidence

Calculation audits, `docs/fitting-preflight`, and `docs/fitting-reviews` retain the
source checks and approval decisions made during import. They are historical
records, not build inputs or instructions to repeat the work. Paths and hashes in
those records describe files at the time of review. Git history retains the
removed source material and tooling.

The development page at `/fittings/review` edits duct-shape classifications in
the calculation catalog. It does not review or regenerate artwork and does not
need the PDF. See [catalog classification review](fitting-catalog-review.md).

## Verification

Run `node scripts/check_fitting_reference.cjs` to check catalog coverage, tables,
exports, and standalone SVG dependencies for both catalogs. The Swift fitting
and template tests verify calculation behavior and artwork lookup. No artwork
regeneration precedes either check.
