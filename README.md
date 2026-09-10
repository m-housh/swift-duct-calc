# DuctCalc

[![CI](https://github.com/m-housh/swift-duct-calc/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/m-housh/swift-duct-calc/actions/workflows/ci.yaml)

[DuctCalc](https://ductcalc.pro) is residential HVAC duct design software based on
ACCA Manual D and the speed-sheet workflow. The hosted app is free to use, and you
can run your own instance.

- Enter room loads or import them from CoolCalc reports.
- Calculate friction rate and size room ducts, trunks, and runouts.
- Build equivalent-length paths with a fitting picker and reusable path templates.
- Browse the fitting reference or use the standalone ductulator.

See the [user guide](docs/user/guide.md) for the design workflow and
[self-hosting instructions](docs/self-hosting.md) to run a production instance.

## Development

Install Podman, or Docker if Podman is unavailable, plus `just` and Python 3.
Run these commands from the checkout:

```sh
just run
```

This builds the development image from `docker/Dockerfile.test`, compiles the app
with Swift 6.2, and starts it in development mode. The first build takes a while.
Run `just url` in another terminal to print the local address. Create an account
there to work with projects.

Each worktree gets a port saved in the ignored `.dev-port` file, a separate
container, and named volumes for its SQLite database and compiler cache. The
server binds to localhost. Podman is preferred automatically; use
`just container_engine=docker run` to select Docker explicitly.

After changing Swift or public files, stop this worktree's server with `just stop`
and run `just run` again. This rebuilds the source image and reuses its data and
compiler cache. The checkout is not mounted over the app in the container.

For CSS changes, install Node.js and npm, then run:

```sh
just install-deps
just run-css
```

The watcher rebuilds `Public/css/output.css`. Rebuild the app image to serve the
updated CSS. See [development checks and catalog editing](docs/development.md)
for additional workflows.

## Tests

Run the Swift suite in a container, matching CI:

```sh
just test-docker
# Or select a suite:
just test-docker --filter Fitting
```

With Swift 6.2 installed locally, `just test` runs tests with code coverage. PDF
import tests need Poppler's `pdftotext`; the container already includes it.
`node scripts/check_fitting_reference.cjs` checks the fitting catalogs and assets
without starting the app.

## Contributing

Open an issue to discuss a change or submit a pull request. Read [AGENTS.md](AGENTS.md)
for repository guidance. Maintainer notes explain
[fitting catalog boundaries](docs/internals/fitting-catalog.md),
[source interpretation decisions](docs/internals/fitting-rules.md), and
[saved-path compatibility](docs/internals/saved-paths.md).

## License

Source is available under the
[Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International license](LICENSE),
CC BY-NC-SA 4.0.
