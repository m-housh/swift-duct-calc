# FittingClient design sketch

Status: the dependency-only first implementation is available on
`codex/fitting-client`; see [scope and source checks](fitting-client-first-slice.md).
The wider contracts below remain the design reference for subsequent integration. This narrows the broader
[fitting-picker implementation plan](fitting-picker-implementation-plan.md) to one
reviewable dependency boundary.

## Reference material direction

The user considers the supplied PDF internal MVP reference material. Public types,
calculation snapshots and runtime catalog data must not depend on its path, hash
or page layout. Retain document/page evidence in development audit documentation.
A future reference guide may be recreated without page breaks; designing that
replacement is separate work. Keep fitting codes, rule/catalog versions and
applicability conditions independent of the reference document's format.

## Proposed responsibility

`FittingClient` describes fittings, resolves their artwork, and evaluates their
per-fitting equivalent length from explicit inputs. It does not need a project
or user to do those things.

`ProjectClient` supplies project context and coordinates saving a path. Shared
identities, inputs/results and route declarations remain in `ManualDCore`.
This supersedes the earlier proposal to implement fitting rules directly inside
`ProjectClient`, if this new boundary is accepted.

| Owner | Responsibility |
| --- | --- |
| `FittingClient` | Catalog, supply/return eligibility, source-code resolution, defaults and input requirements, artwork lookup, fitting rules and source conditions |
| `ManualDCore` | Shared fitting types and transport contracts; route declarations/parsers where needed |
| `ProjectClient` | Obtain explicitly associated project inputs; coordinate evaluation of calculated rows during save; preserve supplied and legacy values through the agreed persistence workflow |
| `ViewController` | Render groups/cards/inputs and results; HTTP handling, input parsing, interaction state and error presentation |
| `DatabaseClient` | Persist paths and user favorites; legacy-compatible reads/writes |
| Existing `FileMiddleware` | Serve approved static SVGs/images from `Public` |

The client returns canonical group/fitting order. User favorites reorder the
presentation outside it. Group-use warnings also stay outside: detecting a repeat
requires the path's entries, not just the selected fitting.

## Dependency surface

Conceptual Swift signatures, following the existing `@DependencyClient`,
`DependencyValues`, `TestDependencyKey`, and `DependencyKey` pattern in
[ManualDClient](../Sources/ManualDClient/Interface.swift). These are a contract
sketch, not a compilable implementation; the types below are proposed.

```swift
@DependencyClient
public struct FittingClient: Sendable {
  public var groups:
    @Sendable (EquivalentLength.EffectiveLengthType) async throws
      -> [Fitting.Group]

  public var fittings:
    @Sendable (Fitting.BrowseRequest) async throws -> [Fitting.Definition]

  public var artwork:
    @Sendable (Fitting.ArtworkRequest) async throws -> Fitting.ArtworkResolution

  public var evaluate:
    @Sendable (Fitting.EvaluationRequest) async throws -> Fitting.Evaluation

  public var resolveReference:
    @Sendable (Fitting.ReferenceRequest) async throws -> Fitting.ReferenceMatch
}
```

Expose it as `@Dependency(\.fittingClient)` with `testValue = Self()` and live
closures backed by internal catalog/rule helpers. The initial implementation can
read immutable bundled data; it does not need network access. `async throws`
matches neighboring clients; synchronous operations remain an option for review.

| Operation | Input and behavior |
| --- | --- |
| `groups` | Path type → eligible groups, descriptive titles, representative artwork ID, and canonical order. Excludes Group 13. |
| `fittings` | `BrowseRequest(pathType, groupID)` → definitions for that eligible group, including construction variants, source identities, defaults and input requirements. No SVG bytes or user favorites. An ineligible group returns an empty list. |
| `artwork` | Fitting ID, current configuration and requested view → exact artwork asset or explicit unavailable result. Does not require a valid length calculation. |
| `evaluate` | Path type, fitting ID and typed draft inputs → resolved result or field-level unresolved reasons. Rechecks identity/applicability; does not trust prior browser filtering. |
| `resolveReference` | Entered source code and path type → recognized source identity, ambiguity, unknown code or ineligible result. Used by quick entry without running a fitting calculation. |

Expected user states—missing inputs, unsupported table combinations and unknown
codes—are structured results. Throws are reserved for failures such as unreadable
catalog resources or invalid packaged data. Do not turn a missing table cell into
zero, choose the nearest row, or silently fall back to a different fitting.

`resolveReference` is intentionally distinct from `evaluate`: `4AG,30,2` supplied
through quick entry remains the user's value. Resolving the code does not claim
the value is verified or reveal which construction the user consulted.

## Shared types and identity

Proposed namespace: `Fitting` in `ManualDCore`, following the repository's nested
model style. All shared fitting definitions belong together in
`Sources/ManualDCore/Fittings.swift`, per the user's file-layout direction. Keep it distinct from the existing persisted
`EquivalentLength.FittingGroup`; this review does not replace that structure.

| Type | Proposed contents |
| --- | --- |
| `Group.ID` | Validated group 1–12 identifier |
| `ID` | Stable application case/variant ID; do not derive it from a display name or asset filename |
| `SourceCode` | Reference identity such as `5B`, independent of the application's family and variant grouping |
| `Group` | ID, title, representative artwork ID and order |
| `Definition` | ID, group, actual source code if one exists, name, variant/shape metadata, supported systems, input kind/defaults, document-independent applicability conditions and calculation availability |
| `Inputs` | Typed draft cases for rule families, with optional values where the user has not answered yet; explicit units |
| `ArtworkRequest` | Fitting ID, relevant construction configuration and optional view selection |
| `Artwork` | Catalog-owned public path, media type, alt text, revision and view identity |
| `EvaluationRequest` | Path type, fitting ID and draft inputs; no project ID, quantity or user-entered EL |
| `Calculation` | EL per fitting in fractional feet, normalized inputs, component breakdown, rule/catalog revision and applicable guidance |
| `Issue` | Stable reason code, affected field if any, and parameters for presentation; no HTML |

Identity examples that the contract must represent:

- Family 5A with round artwork uses source code **5B**. Do not save 5A solely
  because it was the family used to browse to that variant.
- Group 7's individual and assembly views can show the same calculation case.
  A merging-flow condition changes the rule; changing only the view does not.
- Group 11 has the application case `11-junction-box` and an optional supplied
  90° bend. Do not invent printed source codes 11A/11B. The CSV alias for this case
  remains a separate decision; an application ID is not automatically a CSV code.

A possible evaluation result shape:

```swift
extension Fitting {
  public enum Evaluation: Equatable, Sendable {
    case resolved(Calculation)
    case unresolved([Issue])
  }
}
```

For draft inputs, prefer a tagged enum of typed payloads such as `.fixed`,
`.dimensionRatio`, `.downstreamBranches` and `.flexJunctionBox`, extending it as
verified rule families are introduced. Numeric values should carry units in their
names/types; do not carry an unrestricted `[String: String]` through the domain
layer. HTTP parsing handles invalid text; evaluation also checks numeric bounds,
nonfinite values, configuration compatibility and source coverage.

Definitions advertise the expected input kind, valid options and initial values;
the view chooses the appropriate controls. The same internal rule description
must drive those requirements and validation. This is not a generic form-builder
or a separate JavaScript rule engine.

Apply defaults when creating a **new draft**, not whenever evaluation runs. A
missing submitted velocity must not silently become 700 FPM. Reopening a saved
entry or reevaluating an edited one preserves its recorded inputs.

## SVG lookup and routing

`Sources/App/configure.swift` already installs `FileMiddleware` for `Public`.
The initial proposal keeps this mechanism and the approved files under
`Public/images/fittings`.

Example: `artwork` resolves `11-junction-box` with a supplied bend to the combined
box/bend reference, and box-only configuration to the standalone box reference.
The view renders the returned asset path. Production-approved Group 11 assets
must replace the prototype concept paths before this case ships.

- Resolve from catalog IDs/configuration, not a user-supplied filesystem path.
- Return revisioned asset references so browsers can cache drawings and refresh
  after artwork changes. Keep source links and artwork references distinct.
- Return explicit unavailability for missing shape/view combinations; never show
  rectangular artwork as a fallback for an unavailable round variant.
- SVG lookup stays independent of `evaluate`, so drawings work before inputs are
  complete and while an unsupported-input message is displayed.

No new custom SVG endpoint is needed initially. If stable typed artwork routes,
protected assets or dynamic SVG rendering become requirements, declare the route
in `ManualDCore` and handle the response at the HTTP layer. `FittingClient` can
still resolve the asset; it need not return a Vapor `Response` or depend directly
on `FileClient`.

Picker fragment and evaluation routes are a different concern: propose nesting
them under the existing `SiteRoute.View.ProjectRoute.EquivalentLengthRoute`.
Exact cases, methods and form encodings belong to the following UI/request review.

## Proposed file layout and dependency direction

```text
Sources/
  ManualDCore/
    Fittings.swift                       # all shared fitting definitions
  FittingClient/
    Interface.swift                      # dependency operations + testValue
    Live.swift                           # live closures
    FittingClientError.swift              # catalog/infrastructure failures
    Internal/
      Catalog.swift                      # normalized inventory and lookup
      Artwork.swift                      # configuration/view resolution
      Evaluation.swift                   # dispatch and common validation
      Rules/                             # only verified rule families
    Resources/
      catalog.json                       # proposed canonical runtime metadata
Tests/
  FittingClientTests/
    CatalogTests.swift
    ArtworkTests.swift
    EvaluationTests.swift
    ReferenceResolutionTests.swift
```

`Sources/ManualDCore/Fittings.swift` is the agreed location for all shared fitting
definitions: identities, catalog/source contracts, inputs/defaults, evaluation
results/issues/provenance, and artwork requests/results. Do not split these into
`Fitting+<Type>.swift` files. The remaining client/helper filenames are proposals;
start small rather than creating every helper file immediately.

Add a library and target for `FittingClient`, with direct dependencies on
`ManualDCore`, `Dependencies`, and `DependenciesMacros`. `ProjectClient` and
`ViewController` may depend on it; neither `ManualDCore` nor `DatabaseClient`
depends back on it. The new client does not call `ProjectClient`. There is no
initial need to add fitting operations to `ManualDClient`.

Proposed data approach: normalize reviewed artwork/source manifests into one
versioned resource, retaining internal audit traceability and separate artwork/rule review
states. Evaluate with Swift helpers against that resource. Do not parse `Public`
files on each request or ship the prototype's handwritten JavaScript adapters as
production rules. Resource JSON versus checked-in Swift tables is an explicit
review choice; there must be one authoritative runtime dataset, not two manually
maintained copies. Load/index once per live catalog, expose load errors, and test
that packaged data resolves to the deployed public assets.

## Calls through the feature

1. **Browse:** `ViewController` obtains groups/definitions from `FittingClient` and
   combines them with favorites and current-path usage. No project fetch is needed
   just to resolve a drawing or describe a fitting.
2. **Preview:** parse submitted fields into typed draft inputs, resolve artwork,
   and evaluate. Render field issues or a per-fitting result. Project-associated
   inputs, when available, are supplied explicitly through `ProjectClient`.
3. **Save:** the agreed project save workflow reevaluates calculated entries from
   their IDs/inputs through `FittingClient`. Store returned inputs and rule/catalog
   revision with the resulting value. Browser-supplied calculated EL is not the
   authority. Quantity multiplication remains path arithmetic.
4. **Quick entry / existing data:** resolve source identity without invoking
   `evaluate`; validate and preserve supplied reference lengths or authorized
   legacy values. Do not infer a catalog case from a matching value.

Group 11 illustrates the boundary: the default draft is box 700 FPM, sidewall
openings, bend disabled, with bend defaults 700 FPM and R/D 1.0. Enabling the bend
changes both artwork and the component breakdown. At those inputs the prototype
shows 60 + 15 = 75 ft per entry. Quantity 2 makes the row 150 ft outside the
client. This is an interface example, not source-rule approval: controlling box
velocity, combined-case applicability and production artwork remain unresolved.

## Small first implementation and review questions

The first implementation can be a dependency-only change: shared contracts,
target wiring, a small catalog, artwork lookup and evaluation tests for 4A (fixed),
1F (H/W) and 2A (downstream branches), after their source cases are verified. These
exercise the boundary without replacing step 3, migrating data or implementing
favorites/CSV. The complete picker remains the larger feature objective.

Tests should check source identity and eligibility, exact/unresolved calculations,
partial drafts, independent artwork lookup, case/view distinctions, and dependency
stubbing. Add at least one fixture with a source/variant remapping and a fractional
result. Values must be independently checked against the PDF, not just compared
to the generated resource. Known source disputes stay unavailable for evaluation.

The architectural review can focus on four decisions:

1. **Ownership:** should `FittingClient` own evaluation as well as catalog/artwork,
   with `ProjectClient` coordinating project inputs and save behavior?
2. **Contracts:** are the five operations and a `Fitting` namespace in
   `ManualDCore` a useful fit, or should we change naming/type placement?
3. **Artwork:** is returning static asset references sufficient initially, or do
   you want typed SVG routes in the first implementation?
4. **Data:** should normalized catalog/tables be bundled JSON or Swift definitions?

Migration details, final CSV aliases, favorites schema and the complete route/UI
contract remain in the broader plan; this document does not settle them.
