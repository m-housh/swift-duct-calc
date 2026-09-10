# Saved-path compatibility

Saved equivalent lengths are design records. A catalog correction must not
silently change an existing design. Both the
[ordinary path save](../../Sources/ProjectClient/Internal/FittingPaths.swift) and
[guided path save](../../Sources/ProjectClient/Internal/GuidedPaths.swift)
preserve unchanged calculations from the authorized stored path. New or explicitly
edited calculated entries are evaluated on the server. A rename or quantity edit
preserves the recorded per-fitting length.

Legacy rows contain group, letter, value, and quantity without enough information
to reconstruct construction variants or calculation inputs. Decode them without
inventing provenance. Quick reference entries also preserve supplied lengths;
recognizing a source code does not verify its numeric value. Browser-supplied
legacy flags and snapshots cannot authorize preservation of an arbitrary value.

The legacy row projection remains in use by sizing and exports. New metadata adds
identity and provenance without changing its meaning. Preserve fractional fitting
lengths through evaluation, persistence, and totals. Straight duct lengths retain
the existing whole-foot representation.

## Template snapshots and transport

A guided path stores its template configuration and section associations. Editing
or deleting the account template must not change an existing path or prevent it
from reopening. The ordinary editor rejects template-path writes because it
cannot preserve the section metadata.

[TemplateFittingClient](../../Sources/FittingClient/TemplateFittingClient.swift)
adapts the existing template input and JSON format to the current fitting catalog.
The older transport types remain for compatibility; they do not justify a second
set of numeric tables. Catalog coverage also does not imply that every input family
is supported by the guided controls.

Template JSON export shares configuration, not identity. Imports create new
account-owned templates and fresh section IDs, even when names match. Project
return-navigation context is excluded from exports.

Both editors use an atomic conditional update to reject stale saves. Preserve that
check at the database boundary; checking a revision only before a later write
allows concurrent requests to overwrite each other. Pre-migration paths receive
a revision on their first edit. See the
[path persistence tests](../../Tests/DatabaseClientTests/FittingPathTests.swift)
and [guided-path tests](../../Tests/DatabaseClientTests/GuidedPathTests.swift).
