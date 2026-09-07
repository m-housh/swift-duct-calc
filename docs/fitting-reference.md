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
feature for signed-in users: the underlying reference, SVGs, and catalog assets
are public, and no private catalog or live API is introduced.

The typed `FittingsQuery` holds optional `system`, `group`, `fitting`, `q`, `type`,
and `data` fields. The browser normalizes unsupported values and updates the URL.
For example, `/fittings?system=supply&group=8&fitting=8A-smooth` opens an elbow;
adding `data=csv` opens its CSV record when signed in. JSON/CSV export schemas
and the path-entry example remain experimental. Source-value audit limitations
and the Group 11 concept status carry over from the prototype. Group 13 is excluded.

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
instead of linking directly to the PDF. The PDF remains available inside the reference.

## Assets and verification

The app view is `Sources/ViewController/Views/Fittings/FittingsView.swift`.
Served scripts/styles live under `Public/fittings`; approved SVGs are referenced
in place under `Public/images/fittings`. To refresh the catalog after changing
its source manifests:

```sh
python3 scripts/build_fitting_picker_catalog.py --output Public/fittings
node scripts/check_fitting_reference.cjs
```

`swift test --filter FittingsRouteTests` exercises public access, actual login
cookies, public-page user recognition, protected-route guards, logout, stale
sessions, query round trips, and HTMX continuation. Middleware runs in tests as
it does in the application. View snapshots cover navigation link changes.


The generator reads the approved SVG manifests directly. Its default destination
still supports the separate picker prototype; `--output Public/fittings` writes
only the served reference catalog. The reference maintains its own table adapters
and the one Group 11 concept illustration it displays. It does not load or copy
picker UI code. The exported experimental schema identifiers remain unchanged.

## Integration with the fitting-client branch

This feature branches from the same artwork baseline as `codex/fitting-client`.
The picker worktree has since added a production `FittingClient`, catalog review,
and path editing. Keep those implementations when integrating the reference.

- Combine the additions to `Package.swift`, `ViewRoute`, `ViewController.Live`,
  and the equivalent-length form; retain both the picker and `/fittings` entry.
- Reconcile `configure.swift` and route middleware carefully: the reference uses
  global session restoration for optional login and exercises real middleware
  in tests. Preserve the picker's dependency registrations and protected routes.
- Regenerate affected view snapshots after integration; both features change the
  project detail view.
- The reference still exports the artwork-manifest transcription. The other branch's
  `Sources/FittingClient/Resources/catalog.json` and review changes are a separate,
  newer source of calculation behavior. Adapting this page to that catalog needs
  explicit mapping of variant IDs, source tables, review status, and Group 11;
  merging UI code alone does not reconcile the data.
- Keep the shared artwork, original PDF, and picker files. The other branch has
  Group 11 artwork under `Public/images/fittings/group-11`; compare it before
  replacing this reference's remaining concept asset.

After integration, run the full Swift suite, the reference catalog check, and
browser checks for guest access, login return state, theme inheritance, exports,
and the project's fitting picker. No picker files were removed by this cleanup.
