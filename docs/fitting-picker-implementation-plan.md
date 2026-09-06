# Fitting picker implementation matrix

Planning baseline: 2026-09-05; updated after the full-catalog and Group 11 review. This is a
production implementation proposal, not a change to the Swift application or the frozen prototypes.

For the current, narrower architecture review, start with the
[FittingClient design sketch](fitting-client-design.md). It proposes the dependency
interface, shared types, artwork handling and file layout without implementing the
full picker or persistence changes.

## Review status and repository ownership

This is the reviewable working plan, not a finalized implementation specification. Product decisions
explicitly confirmed below are settled; proposed API names, file placement, persistence mechanics
and delivery sequence remain open to the repository owner's direction. Production implementation has
started with the dependency-only slice on `codex/fitting-client`; see
[implementation scope and source checks](fitting-client-first-slice.md). The step-3
UI and persistence integration are still pending. The reviewed dependency foundation
now includes async startup loading through `FileClient`; the
[catalog expansion](fitting-client-catalog-expansion.md) and
[junction slice](fitting-client-junctions.md) cover 140 fitting choices in groups
1, 2, 4, 5, 6, 9, and 10. Group 6 uses the confirmed nearest-published-ratio-row
policy (midpoint ties upward) and returns both branch and trunk contributions.

Architecture guidance from the user:

- `ManualDCore` is primarily for shared types and routes. Do not put the new fitting calculation
  implementation there.
- The user subsequently proposed a `FittingClient` dependency. The current sketch
  places fitting catalog/artwork/evaluation there, with `ProjectClient` handling
  project-input and save orchestration. The dependency foundation is implemented
  and reviewed; picker and persistence integration remain to be implemented.

Existing structure and proposed responsibilities:

| Location                                                 | Existing role / proposed fitting-picker work                                                                           | Review status                                   |
| -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `Sources/ManualDCore`                                    | Shared fitting identities, typed inputs/results, entry payloads and routes; no new evaluator implementation            | User-directed boundary                          |
| `Sources/ProjectClient/Interface.swift` and `Live.swift` | Dependency interface and live behavior; project-input and save orchestration calling the proposed FittingClient       | Exact API and ownership to review               |
| `Sources/ProjectClient/Internal`                         | Existing project helpers; fitting-rule implementation is now proposed under FittingClient           | Proposed, filenames not committed               |
| `Sources/FittingClient` | Catalog, artwork resolution, source-code lookup and fitting evaluation | Implemented dependency; see the current catalog audits above |
| `Sources/ManualDClient`                                  | Existing reusable duct-sizing/friction calculations; determine whether fitting math needs any reusable operations here | Open; do not assume a new abstraction is needed |
| `Sources/ViewController`                                 | Step-3 rendering, request handling, modal/carousel interaction and input-error presentation                            | Follow existing view/controller conventions     |
| `Sources/DatabaseClient`                                 | Saved fitting entries, compatibility with existing JSON rows, user favorites                                           | Persistence design to review                    |
| `Sources/CSVParser`                                      | Existing CSV module to inspect for reuse before adding import infrastructure                                           | Parser reuse and import contract to review      |
| `Sources/PdfClient`                                      | Ensure existing and new fitting rows remain usable in exports                                                          | Compatibility requirement                       |
| `Public/images/fittings`                                 | Approved source artwork and manifests                                                                                  | Preserve source IDs and artwork revisions       |
| `Public/prototypes/fitting-picker`                       | Design reference and prototype-only adapters; not the production rule engine                                           | Prototype remains separate                      |

Useful review topics: module ownership and dependency direction; catalog/table storage; request and
response types; legacy-data strategy; favorite persistence; CSV scope; and the order of
implementation. The next specification should map these decisions to concrete files and APIs after
this architectural review.

Current prototype: `Public/prototypes/fitting-picker/path-catalog.html`, committed in `5dc3574`. It
includes 230 approved artwork variants plus the reviewed Group 11 junction-box flow. Group 11 starts
with a box and an optional supplied 90° bend; the combined entry defaults velocities to 700 FPM,
bend R/D to 1.0 and openings to Sidewall. Straight-run and L ≥ 2D assumptions are guidance rather
than form inputs. Top/bottom openings remain unresolved. See
[group-11-picker-plan.md](group-11-picker-plan.md) for the detailed current flow. These UI decisions
do not resolve the outstanding source-rule questions.

## Decisions and scope

Confirmed with the user:

- Treat `Public/files/ManD.Groups.pdf` as internal MVP reference material, not a
  permanent product dependency. Keep its path/hash/pages out of public fitting
  contracts and calculation snapshots. A future continuous reference guide can
  replace it; record current source evidence in internal audit documentation.
- Use the supplied `Public/files/ManD.Groups.pdf` for rule verification for now. Do not silently mix in another edition.
  Identifying the edition remains useful provenance work, not a reason to prevent planning against
  this document.
- Ask for missing fitting-specific dimensions, conditions, airflow, or velocity. Reuse existing
  values only where their association with this fitting is known.
- Real saved projects exist and must be preserved.
- Quick entry is an explicit reference-transcription workflow for power users: fitting code and
  equivalent length are required; quantity is optional. The user consults the PDF/reference in
  another tab or window. CSV paste and file upload are candidate interfaces for this same workflow.
- Visual entry derives equivalent length and does not expose a length override. Quick entry accepts
  the user's reference value and does not require calculation inputs or offer automatic calculation.
  This clarification supersedes the earlier blanket no-custom-length interpretation for quick entry
  only. Do not label transcribed values as app-calculated or independently source-verified.
- New entries default to quantity 1; quantity is edited in the path list. Group-specific quantity
  locks are deferred. Groups 1, 2, 3, 5, and 6 receive a non-blocking warning when their total
  quantity exceeds one.
- Current preferred visual direction: tall path rows with an Add fitting pop-up, descriptive group
  selection in a three-card looping carousel, favorites first, and a running fitting total.
  Fixed-value fitting selection adds immediately; conditional inputs appear on the fitting card.
  Prototype 2 remains frozen.
- Groups 1–12 are in scope. Group 13 is excluded per the artwork task's recorded user instruction in
  [fitting-shape-artwork.md](fitting-shape-artwork.md).

Source identity: SHA-256 `aae20d968d8238c8958a2c010012aca59ef4b5eed4ce749ed2b722d222997334`.

The tables below consolidate existing source transcriptions, artwork manifests, planning notes, and
current Swift code. They do **not** constitute a fresh visual verification of every PDF table cell
or a certification of production formulas. Artwork acceptance and calculation-rule verification must
be tracked separately. PDF page ranges below are one-based viewer pages from the existing inventory.

## Group input and calculation matrix

This matrix describes the **visual calculation flow**. Quick entry bypasses these calculation-input
requirements and records a supplied reference value.

Input source abbreviations: **F** = ask about the selected fitting; **P** = reuse only an explicitly
associated path/duct input, otherwise ask. A reference velocity printed above a table is not
automatically a required user input or an instruction to scale a fixed reference value. Verify the
source's applicability separately.

| Group / path                                                                                        | Source PDF pages | Inputs to resolve                                                                                                                                                                                  | Input origin                                          | Calculation families                                                                                            | Open verification / implementation work                                                                                                                                                                                                                                                                                                     |
| --------------------------------------------------------------------------------------------------- | ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **1 — Supply connections at equipment** / Supply                                                    | 1–4              | Fitting/shape, H and W for H/W cases, radius and W for R/W cases, vane configuration, relevant clearances                                                                                          | F; P for dimensions only with an explicit connection  | Fixed values; dimension ratios → tables; discrete vane variants                                                 | Define ratio boundaries and intermediate-value treatment. Keep construction and clearance conditions with the selected fitting.                                                                                                                                                                                                             |
| **2 — Supply trunk branch takeoffs** / Supply                                                       | 5–9              | Fitting/connection shape; number of downstream branches to next reducer or trunk end                                                                                                               | F; a flat fitting list cannot infer branch count      | Table indexed by 0, 1, 2, 3, 4, or 5+ downstream branches                                                       | Verify count semantics in source UI help. Do not use row count or quantity as downstream branch count. Use the completed group-2-restored manifest.                                                                                                                                                                                         |
| **3 — Reducing trunk takeoffs** / Supply                                                            | 10–17            | Selected connection in an assembly; corner/radius or vane variant; applicable sleeve/transition-wall condition                                                                                     | F                                                     | Fixed per source case/variant; source-defined additive conditions                                               | Resolve old lookup versus newer manifest differences, particularly 3W. Reconcile the recorded 3U overview/detail conflict. Determine exactly where the butt-sleeve adjustment applies and avoid adding it twice to composite values.                                                                                                        |
| **4 — Supply boots and stack heads** / Supply                                                       | 18–19            | Source fitting ID and construction/orientation needed to identify it                                                                                                                               | F                                                     | Predominantly fixed values by fitting                                                                           | Verify source conditions and letter coverage, including multi-letter IDs. A representative drawing's dimensions are not automatically calculation inputs.                                                                                                                                                                                   |
| **5 — Return connections at equipment** / Return                                                    | 20–24            | Duct shape and family; return count for affected entries; H/W or R/W dimensions for affected entries                                                                                               | F; P for identified dimensions                        | Fixed values; one versus two-or-more return table; ratio tables                                                 | Preserve actual source ID when shape changes (e.g. family 5A round maps to source 5B). Return count is a source condition, not entry quantity. Clarify ratio boundaries.                                                                                                                                                                    |
| **6 — Return trunk branches and boots** / Return                                                    | 25–29            | Fitting; path through branch versus trunk; source-labeled CFM1 and CFM2                                                                                                                            | F for flow path; P for CFM only if associated         | CFM1/CFM2 → separate branch/trunk table columns for 6A–6E; fixed values for 6F–6P                               | Implemented: branch CFM1 / combined downstream CFM2; nearest published ratio row with midpoint ties upward. Return both branch and trunk contributions with selection metadata; preserve ≤0.40 ranges and NA trunk cells. ProjectClient will assemble path totals.                                                                                                                                                          |
| **7 — Panned joists and stud returns** / Return                                                     | 30–31            | Fitting/assembly case; CFM through the represented return; whether upstream return flow merges for 7C                                                                                              | F and P                                               | Airflow tables, maximum-CFM applicability; additive merging-flow condition                                      | Even 7A's constant table value has airflow coverage to validate. 7C's merging case records +40 ft; it is an addition to its table value. Individual/assembly views alone must not change the calculation.                                                                                                                                   |
| **8 — Elbows and offsets** / Both                                                                   | 32–35            | Construction/piece count, shape, R/D or R/W or other labeled ratios, angle, vanes, riser size; selected constituent elbow for linked-elbow cases                                                   | F; P for associated dimensions                        | Fixed values; multidimensional tables; angle multipliers; derived base elbow × multiplier                       | Audit 8A piece-count mappings against old Swift entries; preserve source angle-note inconsistency as unresolved. Support 8L/8M by calculating a selected base elbow, not asking for its EL. Check ratio boundary wording, e.g. 8O.                                                                                                          |
| **9 — Supply trunk junctions** / Supply                                                             | 36–39            | Junction case, relevant connection shapes, branch versus main path where table distinguishes them, applicable flow relationship                                                                    | F; P if flow relationship can be established          | Branch/main fixed values for 9A–9J; single values for 9K–9R                                                     | Do not sum branch and main values for a path traversing only one. Verify source application relative to Group 2; mixed shapes must retain both connection shapes.                                                                                                                                                                           |
| **10 — Return trunk junctions** / Return                                                            | 40–41            | Source junction case and shape; confirmation this is a merging-trunk case                                                                                                                          | F                                                     | Fixed values for 10A–10G at stated source reference conditions                                                  | Preserve distinction from branch returns assigned to Group 6. Source metadata records 700 fpm reference, unlike many supply entries.                                                                                                                                                                                                        |
| **11 — Flex junction boxes and radius bends** / Both in current app, source applicability to verify | 42–43            | Junction box with optional supplied 90° bend; opening placement; flex-duct velocity for the box; bend velocity and R/D                                                                             | F; P where airflow/diameter association is explicit   | Box table plus optional 90° bend table; R/D categories                                                          | UI flow reviewed; concept artwork integrated. Determine box-controlling duct velocity, radius categories, and intermediate-velocity policy. Do not fabricate 11A/B/C fitting IDs from diagram labels. Unresolved visual calculations stay unavailable; separate quick entry can record a supplied length once the source code is supported. |
| **12 — Transitions and special cases** / Both                                                       | 44–48            | Directed inlet/outlet shape and dimensions; source-labeled slope X/Y; larger/smaller area ratio; for 12W inlet and outlet velocity; for 12X controlling velocity and applicable pressure condition | F; P for associated dimensions, airflow, and pressure | Slope × area-ratio tables; fixed special cases; velocity tables; additional minimum-pressure applicability data | Distinguish expanding from reducing source cases. Verify slope/area definitions and intermediate values. 12W/X are absent from old Swift lookup. Keep minimum static pressure separate from equivalent length; do not add pressure to a feet total.                                                                                         |

### Source and artwork inventory snapshot

Counts are artwork entries, not unique calculation rules. Different views may represent the same
rule; shapes sometimes represent different source fitting IDs.

| Group | Primary local catalog for this planning pass                                      | Artwork snapshot                                                 | Calculation readiness                                                                                      |
| ----- | --------------------------------------------------------------------------------- | ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| 1     | [catalog.json](../Public/images/fittings/catalog.json)                            | 22 approved entries                                              | Fixed and ratio data transcribed; source conditions/range audit still required                             |
| 2     | [restored manifest](../Public/images/fittings/group-2-restored/manifest.json)     | 17 approved restored entries                                     | Branch-count tables integrated in prototype; production rule audit remains                                 |
| 3     | [individual manifest](../Public/images/fittings/group-3-individual/manifest.json) | 32 approved entries                                              | Source/legacy discrepancies need resolution                                                                |
| 4     | [enhanced manifest](../Public/images/fittings/group-4-enhanced/manifest.json)     | 44 approved entries                                              | Fixed values transcribed; audit conditions and full ID coverage                                            |
| 5     | [shape manifest](../Public/images/fittings/group-5-shapes/manifest.json)          | 16 approved variants across 12 families, retaining 15 source IDs | Shape/source mapping and nested value data require normalization                                           |
| 6     | [enhanced manifest](../Public/images/fittings/group-6-enhanced/manifest.json)     | 16 approved entries                                              | Flow-ratio and branch/trunk rules require explicit modeling                                                |
| 7     | [options manifest](../Public/images/fittings/group-7-options/manifest.json)       | 9 approved views/options                                         | Airflow bounds and merging adjustment require explicit modeling                                            |
| 8     | [manifest](../Public/images/fittings/group-8/manifest.json)                       | 25 approved entries                                              | Several rule types and discrepancies; split into independently verified cases                              |
| 9     | [manifest](../Public/images/fittings/group-9/manifest.json)                       | 18 approved entries                                              | Branch/main path selection and application checks required                                                 |
| 10    | [manifest](../Public/images/fittings/group-10/manifest.json)                      | 7 approved entries                                               | Fixed values transcribed; source application checks required                                               |
| 11    | [reviewed picker flow](group-11-picker-plan.md)                                   | Box, standalone bend and combined concept drawings integrated    | Production rule verification and box-controlling duct velocity remain open                                 |
| 12    | [manifest](../Public/images/fittings/group-12/manifest.json)                      | 24 approved entries                                              | 12A–V metadata reports 86 values checked against Swift; W/X and numeric coverage still need implementation |

Use the original PDF to adjudicate discrepancies; neither the old Swift lookup nor a newly approved
illustration independently establishes the correct formula. Do not flatten all nested fields into
`referenceEquivalentLengthFeet`: several manifests deliberately place their real values inside
`referenceValues`, while the top-level field is null.

## Specific rule audit queue

These are findings/questions for implementation, not new interpretation of the PDF:

1. **3W:** individual manifest has a single 30 ft value, while the Swift lookup has
   full/tight/mitered keys with 15/35/90 ft. Inspect the actual source case before selecting an
   authoritative mapping. 3J also exists in the newer artwork but has no corresponding entry in the
   old Group 3 lookup.
2. **3U:** the old inventory records different overview/detail descriptions. Newer individual
   entries distinguish mitered with/without vanes. Verify the intended source identity; approval of
   the drawing does not settle the rule.
3. **8A:** at R/D = 1 the manifest assigns 20 ft to four/five-piece and 25 ft to three-piece
   constructions; old keys `8a-1-3` and `8a-1-5` contain 20 and 25 ft respectively. Resolve this
   apparent mapping discrepancy against the PDF.
4. **8K:** metadata includes an R/H = 0 value absent from the old lookup. Confirm its applicability
   and include or explicitly withhold the case.
5. **8L/8M:** replace the old instruction to supply a multiplier-based result with selection and
   calculation of the underlying elbow. Keep a dependency graph restricted to supported base rules
   so an arrangement cannot reference itself.
6. **7A:** the full-catalog prototype now restricts selection to the transcribed airflow rows,
   replacing the earlier fixed-25-ft sample. Production must verify maximum airflow and source
   coverage independently of prototype behavior.
7. **11:** visual cases still need a verified rule and explicit application keys. Quick entry may
   record a supplied reference length without running that rule, once the source-case identifiers
   are defined. This is a separate entry origin, not an override attached to a supposedly verified
   automatic calculation.
8. **12W/X:** add explicit cases for the two velocity-dependent tables. Verify the meaning of the
   pressure constraint and which velocity applies; do not silently convert a pressure quantity into
   EL or double-count it elsewhere.
9. **Across tables:** distinguish exact entries, inclusive ranges, strict bounds, and missing cells.
   No universal nearest-row rule, interpolation, extrapolation, or velocity correction is assumed.
   Where the PDF lacks guidance, record the gap and withhold that calculation range rather than
   invent a value.

## Where production inputs will come from

The current [EquivalentLength model](../Sources/ManualDCore/EquivalentLength.swift) contains a
project ID, name, supply/return type, straight lengths, and fitting rows. It has no
room/duct-segment relationship and no fitting dimensions or CFM fields. Steps 1–2 collect path
details and straight lengths; those lengths cannot be reused as fitting height, width, bend radius,
or transition slope.

Proposed behavior:

- Take supply/return from the current path draft.
- Take identity, variants, shape, flow direction, and construction conditions from the selected
  source fitting or ask where the source offers a choice.
- In the visual picker, ask for missing dimensions/CFM/velocity on the selected fitting card. Quick
  entry requests the user's equivalent length instead. Label which connected duct each input
  describes; retain units.
- If the user supplies airflow and the correct cross-section, derive velocity through the domain
  calculation layer. Identify that value as derived and retain its underlying inputs. Do not
  substitute total project airflow for a particular branch without an explicit association.
- Future duct-segment associations can prefill values. Record where prefills came from and flag
  changes that invalidate a saved calculation. Do not silently iterate between new duct sizes and EL
  to resolve a sizing dependency.
- The visual picker derives length from its inputs. Quick entry intentionally accepts a transcribed
  reference length without requesting those inputs.

## Two entry approaches, one path draft

### Visual entry

Use the frozen prototype interaction as the starting point: Add fitting → eligible group carousel →
fitting/variant selection. A verified fixed case can add directly at quantity 1. A conditional case
requires its labeled inputs and a resolved value before Add becomes available. Added rows show
group, source code, drawing, inputs, quantity, per-fitting EL, subtotal, and a running total.

### Quick entry: reference transcription

Confirmed intent: a power user reads the PDF or another reference independently and provides a
fitting code, per-fitting equivalent length, and optional quantity. No dimension prompts, automatic
lookup of length, or calculated-value substitution belong in this workflow. The app still calculates
quantity × entered EL and path totals; that arithmetic is distinct from calculating the fitting's
EL.

Proposed UI: an **Import / Quick entry** action alongside **Choose fittings**. Offer Paste CSV and
Upload CSV as two inputs to the same parser and review screen. The old compact
group/letter/length/quantity form can remain a compatible single-row entry option during rollout. Do
not force image browsing or catalog conversion.

Proposed initial CSV contract (column names and import behavior are not yet an approved final UX):

```csv
code,length_ft,quantity
1A,35,
2A,55,1
4AG,30,2
```

- `code` and `length_ft` are required. `quantity` may be omitted as a column or left empty in a row;
  both mean 1. A two-column header is therefore valid.
- `length_ft` is equivalent length **per fitting**, in feet, not a row subtotal or physical straight
  length. Accept fractional feet. The example values above illustrate file syntax, not a source
  verification or a recommended path.
- Start with header-based UTF-8 comma-separated CSV, conventional quoting, CRLF/LF, optional BOM,
  surrounding whitespace normalization, and blank-line tolerance. Use a CSV parser, not line/comma
  splitting. A dot is the proposed decimal separator; alternate spreadsheet locales/headerless
  formats are future choices.
- Normalize code casing and look up code identity/applicability independently of length calculation.
  Multi-letter IDs and supported variant/case aliases must work. A family with a supplied length
  need not identify every numerical variant; retain a family-level reference code and avoid
  assigning an invented variant.
- Missing artwork or an unimplemented evaluator alone must not prevent quick entry for a recognized
  source code. Unknown codes need a line-specific error and correction path. Group 11 needs an
  explicit identifier contract first.
- Validate finite positive per-fitting length, positive integer quantity, supported source code and
  supply/return applicability. Do not demand that the supplied value match a lookup value, infer
  missing dimensions, or silently replace it.
- Preview parsed rows with line numbers, normalized codes, entered lengths, defaulted quantities,
  subtotals, and the proposed total before applying them. Errors identify their row and field; do
  not silently skip malformed rows.
- Default to appending rows to the current unsaved path. Proposed first release: all-or-nothing
  application after errors are corrected. A Replace-path option, if added later, must be explicit;
  an upload must not silently replace real data.
- Show generally-once warnings for the combined existing + imported draft, but permit intentional
  duplicates. Preserve import order and repeated codes.
- Applying an import updates the draft; saving the project remains a separate action. Parse/preview
  failure or cancellation leaves the existing path intact. Define a file-size/row limit and guard
  double submissions in implementation.

### Shared path behavior and provenance

Visual, quick-entry, and legacy rows coexist in one path draft and share totals, quantity editing,
group usage indicators, source-code identity, and exports. Switching entry approaches must not
discard draft rows or raw pasted text. Repeated codes must not be automatically merged.

Each row records how its length was obtained: `catalog` (app-calculated), `referenceEntry`
(user-supplied), or `legacy` (preexisting, origin unrecorded). Use a concise **Entered** indicator
where useful. Known drawings/descriptions may be shown for a reference entry, but a matching
code/value does not prove which variant, source table cell, or reference edition the user consulted.
Never invent rule provenance. Record CSV filename/line or paste origin where available; a source
citation can be added later without making it mandatory for quick entry.

Editing a reference-entered code or EL remains available through its compact form; quantity stays
editable in the path list. Converting an entered value to a visual calculation is optional and
requires the missing inputs plus an explicit review of any resulting length change. Do not convert
automatically during save/reopen.

## Existing saved paths: compatibility proposal

Preservation is confirmed; the following mechanics are proposed for review:

- Introduce a versioned entry representation with a stable row ID and an origin (`legacy`,
  `referenceEntry`, or `catalog`). Retain the existing group, letter, per-fitting value, and
  quantity without changing historical results.
- Decode old rows with missing metadata as legacy. Never infer calculation inputs from a matching
  code/value alone, or attach a fabricated source/rule version.
- Permit unchanged legacy rows alongside new calculated and reference-entered rows in one path.
  Renaming a path, changing straight lengths, or adding another fitting should not force the user to
  reconstruct every legacy entry.
- Display a compact legacy indicator and preserve the recorded EL. A conversion action lets the user
  choose/confirm a catalog case and supply missing inputs; show any resulting value change before
  replacing the legacy row.
- Proposed legacy editing boundary: keep the compact reference-entry editor for code/EL changes as
  well as quantity/removal. Preserve untouched legacy values. On an explicit code/EL edit, record
  the new referenceEntry origin; this does not claim the old value was app-calculated. Catalog
  conversion is optional.
- Load legacy values from the authorized server-side saved record when preserving them. Never trust
  a client-supplied `origin=legacy` flag or arbitrary length to create new legacy rows. Authorized
  user-supplied values must use the distinct referenceEntry path. Assign durable row IDs during
  controlled persistence.
- Keep the old read path working during rollout. Test a mixed old/new path through decode, edit,
  save, reopen, total calculation, and PDF export.
- A supply/return change must retain the current draft long enough to resolve incompatible entries
  explicitly; do not silently drop or reinterpret them.

Current persistence stores fitting arrays as JSON in a database data field:
[EquivalentLengths.swift](../Sources/DatabaseClient/Internal/EquivalentLengths.swift). An
additive/versioned JSON migration may be sufficient; determine this from real saved fixtures before
choosing a schema migration. Preserve backups and rollback compatibility when changing the
decoder/writer.

## Proposed production boundaries

| Component                                         | Responsibility                                                                                                                                            |
| ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Internal source audit                            | PDF identity/hash, viewer and printed pages, table/case keys and verification record in development documentation; no runtime PDF dependency                                                       |
| Fitting catalog                                   | Stable app ID, actual source ID, family/variant identity, system applicability, shape/connection metadata, labels and approved artwork references         |
| Shared types/routes in ManualDCore                | Typed fitting identities, inputs, results and route/request contracts; no new calculation implementation                                                  |
| Fitting catalog/evaluation, proposed FittingClient | Exact table/range semantics, derived ratios/formulas, source assumptions and structured errors; final placement and API to review                         |
| Path entry                                        | Stable row ID, catalog/referenceEntry/legacy origin, source code, optional verified rule provenance, relevant inputs or supplied EL, quantity and order   |
| Path draft                                        | Shared rows for visual/quick input, unsaved edits, totals, non-blocking usage warnings, row operations and save lifecycle                                 |
| User favorites                                    | User-owned stable fitting/variant IDs; same favorites across projects/devices, independent of saved dimensions/quantities                                 |
| View/controller                                   | Elementary/HTMX rendering, carousel gestures, reference-entry editor, shared CSV paste/upload preview, draft submission and errors                        |
| Persistence                                       | Authorized path/favorite access, legacy-aware decode/write, server calculation for catalog rows, validation and preservation of supplied reference values |

The existing entry DTO uses `Double` for value, but the current step-3 request uses
`groupLengths: [Int]`. Remove that integer bottleneck. Derive catalog-entry lengths server-side from
typed inputs; validate and retain supplied reference-entry lengths without recalculating them.
Preserve fractional values and apply presentation rounding separately from source-required
calculation rounding.

The current submission assembles several parallel arrays by index. Replace or encapsulate this with
identifiable entry payloads and checked decoding; row removal must not misalign identities, inputs,
quantities, and values. Review existing letter validation for multi-letter IDs and non-letter
application cases such as Group 11, rather than forcing every future case into one letter.

Do not maintain separate hand-written JavaScript and Swift calculation tables. Use one authoritative
Swift evaluation path for visual/catalog entries; an optional browser calculation preview must
consume the same versioned rule data and be checked against server results. CSV parsing/validation
is a separate shared path for paste/upload. Imported length fields are never passed through the rule
evaluator simply because a matching fitting code exists. Saved snapshots prevent a later catalog
update from silently changing an existing path's sizing result. Offer intentional re-evaluation with
an explained difference.

## Delivery sequence and verification

1. **Normalize and audit the source catalog.** Build a case-level inventory beneath this group
   matrix. Capture rule kind, source cell/condition, IDs, supported ranges, discrepancies, artwork
   review state, and calculation verification state. Start with fixed cases, Group 1 dimension
   tables, and Group 2 branch tables.
2. **Establish compatibility and request contracts.** Read representative real saved paths,
   introduce identifiable legacy/referenceEntry/catalog entries, and preserve totals. Define the CSV
   contract and retain compact reference editing before replacing old form routes.
3. **Implement one production slice.** Add fixed, ratio-table, and branch-count cases through the
   agreed calculation module (currently proposed FittingClient); both visual and quick entry; user
   favorites; mixed-path saving and reopening. Keep quantity in the path list and generally-once
   rules as warnings. Unsupported ranges return a specific unresolved-input condition.
4. **Expand verified cases.** Flow-dependent returns, artwork/source shape mapping, composite elbow
   rules, transitions, and the reviewed Group 11 flow follow as their source questions are resolved.
   Group-level enablement must not imply every case/range in that group is supported.
5. **Evaluate complete real paths.** Once drawings and rules cover the cases, walk through
   representative supply and return paths with the user. Compare their fitting selections,
   quantities, and totals to the supplied reference workflow.

Required checks should include:

- Source-backed fixed/table/formula fixtures, fractional EL, exact range endpoints, missing cells,
  positive denominators, units, and invalid/unresolved inputs.
- A source-shape remapping (5A family/round → source 5B), branch/main distinction, and an additive
  condition such as 7C merging flow without double-counting.
- Matching user-supplied/calculated values produce matching arithmetic totals, while different
  reference-entered values are preserved without forced equality. Duplicate codes, quantity edits,
  and mixed-origin save/reopen retain provenance.
- CSV paste/file parity; quoted fields, BOM, CRLF/LF, blank lines, fractional EL, missing optional
  quantities, missing required fields, malformed quotes, unknown codes, incompatible groups,
  invalid/nonfinite numbers, and excessive input size. Error/cancel leaves the path untouched;
  successful preview/apply preserves row order, appends once, and never silently recalculates
  imported values.
- Real legacy decode/write fixtures, no forced conversion, no client-forged legacy values, and
  unchanged historical totals through exports.
- Keyboard-only picker use, labeled dimensions and source direction, dialog focus restoration,
  swipe-versus-click suppression, reduced motion, loading failures, double-click/double-submit
  protection, and preservation of an unsaved draft.

No production code, source calculations, or prototype files were changed for this planning document.
Existing artwork-task documents are referenced rather than edited; their historical proposals may
differ from the current decisions above.
