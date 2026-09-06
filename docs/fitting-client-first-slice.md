# FittingClient first implementation

Branch: `codex/fitting-client`, based on prototype/review commit `d89aefb`.
Worktree: `/home/michael/dev/swift-duct-calc-fitting-client`.

This implements the dependency boundary from [the design sketch](fitting-client-design.md).
It does not replace step 3 or write to existing projects. The prototype worktree
and its running preview server are unchanged.

## Included behavior

- All shared fitting definitions are in `Sources/ManualDCore/Fittings.swift`.
- `@Dependency(\.fittingClient)` exposes groups, fitting definitions, artwork,
  equivalent-length evaluation and source-reference resolution.
- One bundled JSON resource provides canonical group order/eligibility and 135
  fitting choices: groups 1, 2, 4, 5, 9, and 10, plus return boots 6F–6P. See the
  [first catalog expansion](fitting-client-catalog-expansion.md) and the
  [junction slice and pending interpolation decision](fitting-client-junctions.md).
  Empty groups report zero available cases and no representative artwork.
- `FittingClient.live()` is an async throwing factory. `Live.swift` resolves its
  own bundle resource and reads it through `FileClient.readFile`. Application
  configuration provides a reader on the application's worker pool, loads one
  fitting client, and passes it to `DependenciesMiddleware` for reuse across
  requests. Loading failures prevent startup; operations capture only the loaded
  catalog. Tests can replace the reader or the application factory. `Catalog`
  receives `Data` and decodes it without bundle or filesystem knowledge. Runtime
  loading checks schema support, group completeness, unique IDs, and nonempty
  rule tables so lookups/indexing cannot trap. A test-only `CatalogValidator`
  checks the authored metadata, artwork paths, and rule tables against the
  checked-in JSON before release. Loading/structural failures throw;
  incomplete inputs, unknown catalog IDs and unsupported conditions return typed
  results. The evaluator does not interpolate or apply velocity corrections.
- New-draft defaults and requirements derive from the same rules used to
  evaluate. Missing submitted inputs are never filled by defaults.
- Approved SVG paths and revisions are resolved without needing valid calculation
  inputs. Unsupported views/shapes have no implicit fallback. Existing static-file
  middleware remains responsible for serving the assets.
- Calculated snapshots preserve per-fitting fractional feet, original inputs,
  fitting/source-code identity, rule component, catalog/rule revisions and applicability
  conditions. Public contracts and runtime catalog data carry no PDF paths, hashes
  or page numbers.
- Source-code resolution normalizes surrounding whitespace/casing and returns
  candidate application IDs, without calculating or accepting an EL value.
  Recognition covers implemented catalog cases, not the complete reference.

The first slice chooses bundled JSON for the runtime catalog and keeps rule
execution in Swift. Client helpers are in `Internal/Catalog.swift` and
`Internal/Evaluation.swift`; their separation follows behavior, not one file per
public type. `ProjectClient`/`ViewController` do not yet call this dependency.

## Internal MVP reference material

The supplied PDF is an internal source for MVP rule verification, not a permanent
product dependency. Its hash and page pointers stay in this audit documentation.
The client does not require the PDF to be deployed or available during lookup or
evaluation. A future continuous reference guide can replace it without changing
fitting/calculation contracts. `Fitting.Conditions` carries the rule's reference
velocity, friction rate and applicability notes, independent of document format.

## Source checks

The original five values below were visually checked against `Public/files/ManD.Groups.pdf` during
implementation, independently of the prototype's evaluator. PDF SHA-256:
`aae20d968d8238c8958a2c010012aca59ef4b5eed4ce749ed2b722d222997334`.

| Source case | PDF viewer page / printed page | Implemented values and scope |
| --- | --- | --- |
| 1F | 2 / 160 | H/W 0.50 → 120 ft; H/W 1.0 → 85 ft. Exact ratios only; retain the illustrated 10-inch minimum clearance as source guidance. |
| 2A | 5 / 163 | Downstream branches 0, 1, 2, 3, 4, 5+ → 35, 45, 55, 65, 70, 80 ft. Count to the next reducer or trunk end; preserve the actual count in the result. |
| 4A | 18 / 168 | Fixed 30 ft. |
| 5A / 5B | 20 / 169 | Both 40 ft; rectangular/round connection to a plenum large compared with duct size. The round family variant retains source code 5B. |

Groups 1, 2 and 4 state 900 FPM and 0.08 IWC/100 ft reference conditions; group 5
states 700 FPM and the same friction rate. These are recorded reference conditions,
not instructions to scale a fixed value with an arbitrary velocity.

The artwork catalog's 1F metadata points at viewer page 1, but its table is on
viewer page 2. This correction is recorded in the internal audit table above;
original artwork manifests were not changed. The runtime catalog has no PDF links.

Group 11 and the known group 3/8 discrepancies remain outside implemented rules.
Optional source codes allow future application-only cases without inventing
lettered IDs. The first slice does not settle those cases' applicability.

## Verification and next integration

The tests cover independent PDF value fixtures, exact ratios, all six branch
buckets, large counts, missing/invalid/nonfinite inputs, direct-request eligibility,
shape/source remapping, artwork lookup, revisioned references, dependency override,
resource rejection and fractional snapshot encoding. Factory tests cover injected
file data, one read per constructed client, and immediate read/decode failures.
Application tests cover startup failure and middleware injection across requests.
Test-only fractional values are labeled as contract fixtures, not as source values.
The expansion audits record numeric coverage for all 135 current fitting choices.

Reproduce with Swift 6.2:

```sh
swift build --target FittingClient --jobs 4
swift test --filter 'Fitting|DatabaseClientTests' --jobs 4
```

The implementation was checked in the same Swift 6.2 container family used by the
repository's test Dockerfile. Database integration tests use in-memory SQLite;
no external database or browser server is needed for these checks.

Review the contracts and client implementation next. Subsequent work can expand
verified cases, then connect the dependency to path drafts, favorites, quick entry,
legacy-aware persistence and the existing step-3 routes. This first change leaves
the current form, saved-path representation and production calculation callers
intact.
