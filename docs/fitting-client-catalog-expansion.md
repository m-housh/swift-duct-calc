# Fitting catalog expansion: groups 1, 2, 4, and 5

This slice expands the production catalog from 5 to 99 fitting choices. It completes
coverage of the approved artwork entries in these four groups. The catalog revision
is `fitting-catalog-v3`; existing fitting rule revisions and values are unchanged.
The step-3 picker and project persistence are still pending.

| Group | Choices | Rules |
| --- | ---: | --- |
| 1 — Supply connections at equipment | 22 | Fixed EL, H/W, R/W; separately identified vane variants |
| 2 — Supply trunk branch takeoffs | 17 | Downstream branches: 0, 1, 2, 3, 4, 5+ |
| 4 — Supply boots and stack heads | 44 | Fixed EL for 4A–4AR |
| 5 — Return connections at equipment | 16 | Fixed EL, H/W, R/W, one versus multiple returns entering a plenum |

## Code to review

- `Sources/ManualDCore/Fittings.swift` adds typed `radiusWidth` and `plenumReturns`
  inputs and presentation requirements, with field-specific validation issues.
- `Sources/FittingClient/Internal/Evaluation.swift` shares the dimension checks
  and exact ratio lookup between H/W and R/W. Plenum-return counts use a distinct
  rule starting at one; downstream branch counts continue to start at zero.
- `Sources/FittingClient/Resources/catalog.json` adds the verified definitions and
  tables. No new calculation lives in `ManualDCore`; file loading is unchanged.
- `Tests/FittingClientTests/SourceCoverageTests.swift` contains PDF-derived numeric
  expectations for every source row in these groups, independent of runtime JSON.

Dimensions must be finite and positive. Only exact printed ratios resolve; there
is no interpolation, extrapolation, or arbitrary equivalent-length override.
R/W uses the inside radius and indicated width in the drawing. Missing dimensions
and counts remain unresolved. Actual submitted counts are retained in calculation
snapshots even when the final inclusive bucket is selected.

The number of returns entering a plenum is not fitting quantity. For 5E, one return
uses 10 ft and two or more use 35 ft. For 5F/5G, the corresponding values are 45 and
70 ft. These apply where plenum size is comparable to duct size. The separately
listed 5A–5D cases assume a plenum large compared with the duct.

1N remains the 15 ft transition component. Its guidance explicitly says to add it
to the upstream elbow or tee; selecting 1N alone does not calculate that upstream
component. Path-level assembly handling is outside this slice.

## Source audit (internal MVP reference)

Values were read directly from `Public/files/ManD.Groups.pdf`, then compared with
the artwork manifests. The prototype JavaScript is not a runtime dependency or the
calculation authority. PDF SHA-256:
`aae20d968d8238c8958a2c010012aca59ef4b5eed4ce749ed2b722d222997334`.

Viewer-page numbers below are one-based. Several artwork manifests point to the
start of a scanned printed page, although the relevant table continues on the next
viewer page. This table records where the actual values were inspected.

| Cases | PDF viewer pages | Printed page | Verified values / conditions |
| --- | --- | --- | --- |
| 1A–1E | 1 | 159 | 35, 10, 35, 10, 10 ft; oversized plenum and illustrated clearance/entry geometry |
| 1F–1I | 2 | 160 | F/H: H/W 0.5 → 120, 1 → 85; G: 0.5 → 35, 1 → 25; I: 20 ft |
| 1K–1N | 2–3 | 161 | K: 85; L: R/W 0.25/0.5/1 → 40/20/10; M one vane: 0.05/0.25/0.5 → 30/20/10; M two vanes: 20/10/10; N: additive 15 ft |
| 1O–1T | 3–4 | 162 | O: H/W 0.5/1 → 120/85; P/Q/R: 20/50/120; S zero/one/two vanes: 60/40/30; T: 60 ft |
| 2A–2H | 5–6 | 163 | All six downstream branch buckets; count to next reducer or trunk end |
| 2I–2M | 7 | 164 | All six downstream branch buckets |
| 2N–2Q | 9 | 165 | All six downstream branch buckets |
| 4A–4AR | 18–19 | 168 | All 44 fixed values, transcribed individually in source coverage tests |
| 5A–5D | 20 | 169 | 40 ft for all four source cases; preserve rectangular/round code mapping |
| 5E–5G | 21 | 169 | E: 1 return → 10, 2+ → 35; F/G: 1 → 45, 2+ → 70 ft |
| 5H–5J | 22 | 170 | H/I: H/W 1/2 → 45/30; J: R/W 0.25/0.5/1 → 20/15/10 ft |
| 5K | 23 | 170 | 10 ft with turning vanes |
| 5L–5O | 23–24 | 171 | 75, 10, 55, 35 ft |

Reference conditions remain 900 FPM for groups 1, 2, and 4, and 700 FPM for group 5;
all use 0.08 IWC/100 ft. These are applicability metadata, not velocity-scaling
instructions. PDF paths and page numbers remain internal to documentation.

## Artwork and reference identity

All 99 entries use the approved SVG paths from the current group manifests.
Review revisions were checked against the corresponding SVG/reference-image pairs;
the existing review token hashes both files, rather than the SVG alone. The runtime
artwork revision retains that token, consistent with the original five entries.
No artwork files or prototype files were edited.

Group 1 vane variants share a family/reference code but retain distinct IDs.
Group 5 preserves these mappings:

- `5A-rectangular` / `5A-round` → source codes 5A / 5B.
- `5C-rectangular` / `5C-round` → 5C / 5D.
- `5E-rectangular` / `5E-round` → 5E for both; reference lookup returns both candidates.
- `5F-rectangular` / `5F-round` → 5F / 5G.

## Verification and remaining work

```sh
swift test --filter Fitting --jobs 4
```

30 tests pass across six suites. Parameterized source tests cover 68 fixed cases,
17 branch tables (including all 102 printed cells and large-count boundaries),
24 ratio cells, and four plenum-return variants. Additional checks cover input
errors, snapshot round trips, group counts, reference identity, all 99 asset paths,
catalog validation, and startup/dependency behavior.

Groups 3 and 8 still need the discrepancy review recorded in the implementation
matrix. Groups 6, 7, 9, 10, and 12 need their own source-verified catalog slices.
Group 11 still needs its velocity/applicability decision and production drawing
handling. None of these pending groups receives placeholder calculation values.
