# Development checks and catalog editing

Use the container workflow in the [README](../README.md#development). It chooses a
port once per worktree and keeps it in `.dev-port`. If another service takes that
port, choose an unused port and update the file while this worktree's server is
stopped. Use the same port for subsequent work in that checkout.

The app runs in the foreground. `just stop` targets only the container named for
this checkout. Its SQLite database and Swift compiler cache survive container
removal in separate named volumes. Changing the container engine uses that
engine's separate storage. Container names and image tags are derived from the
checkout's absolute path.

For remote development, forward the port printed by `just url` through SSH.
There is no shared review port or container to stop.

## Verification

`just test-docker` builds the test image and runs the Swift suite. Pass Swift test
arguments to narrow a check, for example:

```sh
just test-docker --filter 'PdfImportClientTests|ProjectTests|RoomTests|RoomPDFUploadTests|EnvVarsTests'
node scripts/check_fitting_reference.cjs
```

The native `just test` and `just code-coverage` recipes require a local Swift 6.2
toolchain. PDF import uses Poppler's `pdftotext`. Native installations can override
`PDFTOTEXT_PATH` when it is outside `/usr/bin`; container images include Poppler,
Pandoc, and WeasyPrint for import and report generation.

### App and browser checks

Use a disposable worktree database. These scripts create accounts and projects.
For the template HTTP and DOM checks, install npm dependencies, start the app, and
run from the repository root:

```sh
npm ci
DUCT_TEMPLATE_QA_ORIGIN="$(just url)" npm run test:path-templates
```

Browser checks also need Playwright and Chromium. They are optional tools, not
installed by `npm ci`. Install them outside the checkout, then expose their modules:

```sh
qa_tools=$(mktemp -d)
npm install --prefix "$qa_tools" playwright
"$qa_tools/node_modules/.bin/playwright" install chromium
export NODE_PATH="$qa_tools/node_modules"
export FITTING_APP_URL="$(just url)"
node scripts/check_fitting_reference_browser.cjs
node scripts/check_fitting_path.cjs
node scripts/check_fitting_path_edges.cjs
node scripts/check_fitting_preference.cjs
node scripts/check_fitting_favorites.cjs
node scripts/check_fitting_modal.cjs
```

The path check creates the session and project fixtures used by the following
picker checks. Those scripts share `/tmp/fitting-review-*` files, so run the
sequence serially and do not run another checkout's picker checks concurrently.
Screenshots are temporary verification output; do not copy them into `docs/` as
an implementation record.

## Editing duct-shape classifications

The catalog review page changes ordering metadata in the source catalog. It does
not review artwork or numerical rules. It is enabled only in development with
`FITTING_CATALOG_REVIEW_PATH` pointing to a writable catalog file. Every signed-in
account on that development server can make these edits.

Start from the same built development image. Stop this checkout's ordinary server
with `just stop`, then use its port and a writable source mount:

```sh
engine=$(just --evaluate container_engine)
image=$(just --evaluate docker_image)
name=$(just --evaluate worktree_name)
"$engine" run --rm --name "$name" \
  -p "127.0.0.1:$(cat .dev-port):8080" \
  -e SQLITE_PATH=/data/db.sqlite \
  -e FITTING_CATALOG_REVIEW_PATH=/catalog/catalog.json \
  -v "$name-data:/data" \
  -v "$name-build:/app/.build" \
  -v "$PWD/Sources/FittingClient/Resources:/catalog" \
  "$image:dev" swift run --jobs 4 App serve --env development --hostname 0.0.0.0 --port 8080
```

With rootless Podman, container root writes as the checkout owner. With rootful
Docker, use a writable disposable catalog directory for review and copy the
reviewed JSON back as the checkout owner. Mount the directory, not just the file,
because saving replaces the file atomically. On SELinux hosts, the bind mount may
need a label such as `:Z`.

Open `/fittings/review`, select a group, review classifications, and save. Saving
writes to the mounted directory and refreshes the development catalog. Review the
Git diff and run fitting tests before committing. Production uses the bundled
catalog and never enables this editor.

For `scripts/check_catalog_review.cjs`, mount a disposable copy of the catalog
directory instead. Set `FITTING_REVIEW_URL` to `just url` and
`FITTING_REVIEW_CATALOG` to that copy's host file path. The test resets review
statuses and exercises writes; do not point it at the real source catalog.
