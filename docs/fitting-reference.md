# Served fitting reference

`GET /fittings` serves the approved combined group → fitting → reference layout.
It is independent of projects and accepts guests. The All / Supply / Return
control stays in the first sidebar header, moving to the toolbar on mobile.
The production page uses the shared `MainPage` shell, `Navbar`, footer, and
saved user theme. Its scoped stylesheet uses the site’s DaisyUI theme tokens;
SVG drawing paper stays white for legibility. Page-specific assets load through
`MainPage` without changing other pages. The superseded reference design lab has
been removed.

The view controller uses its existing `isLoggedIn` helper (via
`AuthClient.currentUser`) to enable the optional JSON/CSV inspector and exports.
Guest visitors see the complete reference and a sign-in link. Login returns to
the same fitting and filters, with the requested data format open. A direct
`data=json` query does not enable data tools for a guest. This is a convenience
feature for signed-in users. Guests can still browse every reference and SVG.
The bundled reference resource is no longer served as a JavaScript asset.

The typed `FittingsQuery` holds optional `system`, `group`, `fitting`, `q`, `type`,
`data`, `scope`, and `download` fields. Swift normalizes unsupported values and
renders canonical navigation links. `scope=filtered` selects all matching records;
`download=1` returns an authenticated JSON/CSV attachment.
For example, `/fittings?system=supply&group=8&fitting=8A-smooth` opens an elbow;
adding `data=csv` opens its CSV record when signed in. JSON/CSV export schemas
and the path-entry example remain experimental. The reference retains its own
source-value audit limitations and Group 11 concept status. Group 13 is excluded.

## Authentication and navigation

Session authentication runs globally after session storage middleware and before
the route handler. Public pages can recognize an existing user without requiring
login. Protected project/user routes retain their password authenticator and
login redirect. A deleted user's stale session is cleared and treated as anonymous;
database failures are still propagated. Login populates both `request.auth` and
the session so global session middleware preserves it; logout clears both.

`/fittings` responses are private/no-store and vary on Cookie and HX-Request.
HTMX requests to this page receive `HX-Redirect` to load its full
head, styles, and scripts, including the continuation from the existing login
form. All entry links use normal navigation. The navbar and home page link to
the reference, and the equivalent-length form supplies its current path type
to open the matching fitting reference. The reference PDF has been removed from
the application and development workflow.

## Assets and verification

The app view is `Sources/ViewController/Views/Fittings/FittingsView.swift`.
`FittingClient` loads `Resources/reference.json` once at startup through `FileClient`.
`FittingReference` owns the typed reference records, filtering, and export encoding.
`FittingReferencePage` normalizes query state for both HTML and downloads. Group
applicability comes from the calculation catalog. Elementary renders the complete
reference, including source tables and the optional data inspector.

Normal links and GET forms work without JavaScript. `Public/fittings/app.js` adds
debounced search and navigation by fetching server-rendered HTML, restores focus
and scroll position, handles browser history, and provides clipboard access.
It contains no fitting records, table adapters, filtering, or export serialization.
Downloads use the server's authenticated response and work without JavaScript.
Scoped CSS and the Group 11 concept remain under `Public/fittings`; other SVGs
remain under `Public/images/fittings`.

The resource is maintained directly, with no generation step. During migration,
all 231 records were compared against the previous JavaScript JSON exports,
including every table, null value, source condition, and citation. Validate assets with:

```sh
node scripts/check_fitting_reference.cjs
```

`swift test --filter 'FittingReferenceTests|FittingsRouteTests'` exercises public access, actual login
cookies, public-page user recognition, protected-route guards, logout, stale
sessions, query round trips, server-rendered tables, authenticated downloads, filtering,
lossless JSON/CSV exports, and HTMX continuation. Middleware runs in tests as
it does in the application. View snapshots cover navigation link changes.


The reference retains normalized source tables and the one Group 11 concept
illustration it displays. All drawings are final, self-contained SVGs. The
artwork review, extraction, and packaging tooling has been retired. See
[finished fitting assets](fitting-assets.md).

JSON/CSV exports retain a source document citation and printed page. They no
longer contain PDF URLs, source-image paths, crop coordinates, or links to
retired manifests. The exported experimental schema identifiers remain unchanged.

## Integration with the fitting-client branch

The reference is integrated alongside the project fitting picker and development
catalog review. `SiteRoute.View.fittingReference(FittingsQuery)` owns public
`GET /fittings`; `SiteRoute.View.fittings(FittingPickerRoute)` retains the picker
fragment and review endpoints. The former picker landing page now lives at
`GET /fittings/picker`. The reference's full-document HTMX redirect and private
response headers apply only to the reference route, so picker POSTs still return
fragments.

Global session restoration recognizes signed-in reference visitors. Project/user
routes and both catalog-review routes retain their authentication guards, including
when the app runs in tests. FittingClient startup, dependency registration,
development authoring configuration, saved paths, preference sorting, and favorites
remain intact. The current path editor and legacy form both link to the reference;
the current editor updates the link's system filter when its path type changes.
The combined navigation/project snapshots pass without replacing the path editor.

The reference exports the checked-in reference transcription. The reviewed
`Sources/FittingClient/Resources/catalog.json` remains the separate, newer source
of calculation behavior. Its **189 reviewed classifications** were preserved
byte-for-byte during integration. Adapting the reference to that catalog needs
explicit mapping of variant IDs, source tables, review status, and Group 11.
Both resources now live in `FittingClient`, with distinct meanings. `reference.json`
preserves source transcription and experimental exports; `catalog.json` owns
reviewed calculation behavior. This migration does not reinterpret reference tables
as audited rules or change saved project calculations. Consolidating their source
values still requires the mappings above. Both use the finished SVG assets.
The reference retains its concept illustration under
`Public/fittings/concepts`; the picker's three Group 11 drawings under
`Public/images/fittings/group-11` are unchanged.

### Validation of the integrated application

- **222 Swift tests in 45 suites pass**, including actual session/login middleware,
  public reference queries, protected picker/review routes, fragment responses,
  catalog calculations, saved paths, and combined view snapshots.
- `node scripts/check_fitting_reference.cjs` passes for 231 records, 12 groups,
  standalone artwork, citations, and normalized tables. Swift tests check lossless
  CSV/JSON exports for every record.
- `scripts/check_fitting_reference_browser.cjs` passes guest access, real login and
  HTMX return state, persisted Nord theme, record/filtered downloads, path examples, browser history, search focus,
  browsing and downloads without JavaScript, logout, and mobile layout.
- The path, preference, favorites, edge-case, modal, and catalog-review browser
  checks pass against an isolated database and disposable review catalog. These
  include save/reopen, server-authoritative values, stale saves, stable favorites,
  modal cancellation, review bulk edits, and the path-aware reference link.

Run browser checks with Playwright available. The main path check writes temporary
session/project fixtures used by the following picker checks:

```sh
FITTING_APP_URL=http://localhost:YOUR_QA_PORT node scripts/check_fitting_reference_browser.cjs
FITTING_APP_URL=http://localhost:YOUR_QA_PORT node scripts/check_fitting_path.cjs
node scripts/check_fitting_preference.cjs
node scripts/check_fitting_favorites.cjs
node scripts/check_fitting_path_edges.cjs
node scripts/check_fitting_modal.cjs
```

See [catalog review validation](fitting-catalog-review.md#validation) for the
separate disposable-catalog authoring check.

![Signed-in reference and JSON inspector](images/fitting-picker/reference-integrated.png)

![Reference on mobile](images/fitting-picker/reference-integrated-mobile.png)

The navbar's Fitting reference action uses the theme's secondary outline button,
with a filled hover/focus state. The existing Styleguide tooltip helper displays
"Browse fitting references" beneath it on hover and keyboard focus. An
`aria-describedby` link provides the same description to screen readers. Browser
checks cover Dracula and light themes, keyboard activation, and mobile width.

![Themed reference button and tooltip](images/fitting-picker/reference-nav-tooltip.png)

Ductulator uses the same outline styling and text size, retaining the theme's
primary color, pink in Dracula. Its tooltip also appears below the button on
hover and keyboard focus.

![Matching navbar buttons](images/fitting-picker/ductulator-nav-tooltip.png)
