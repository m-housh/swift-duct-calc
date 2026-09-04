# Fitting visual preflight

Generated fitting groups must remain off the browser review page until their
source/SVG pairs have been rendered and inspected as images. XML parsing,
vector-only checks and deterministic generation remain required, but they do
not establish visual fidelity.

Run `python3 scripts/render-fitting-qa.py GROUP` to produce fitting-specific
pair images and four-up contact sheets under `/tmp/fitting-qa-group-GROUP`.
Inspect every sheet at readable resolution. Reject a group before user review
if a drawing represents the overview assembly instead of the individual source
crop, changes its attachment surface, disconnects components, omits a defining
feature, or cannot be understood without neighboring fittings.

The review page uses the `qa-hold` batch while no group has passed this check.
`generate-isolated-group-review.py` creates a batch file without activating it.
Its `--activate` option requires `docs/fitting-preflight/group-N.json` with a
`passed` status and an exact revision map for every source/SVG pair. Record the
inspected sheet paths, rejected IDs, corrections, and a second clean inspection
before creating that passing record.

Group 3 failed this gate retroactively on 2026-09-04. Its source crops show
individual fittings, while its SVGs frequently reconstruct overview trunk
assemblies. All Group 3 drawings are quarantined for a new approach.
