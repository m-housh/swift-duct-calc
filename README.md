# swift-duct-calc

[![CI](https://github.com/m-housh/swift-duct-calc/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/m-housh/swift-duct-calc/actions/workflows/ci.yaml)

Residential duct design software.

## Fitting reference

Open `/fittings` on the running app for the public fitting reference. Signed-in
users can also inspect and export CSV/JSON records. See the
[reference documentation](docs/fitting-reference.md) for routes, session behavior,
and catalog maintenance.

## Overview

This is the source code for [ductcalc.pro](https://ductcalc.pro) web site. Which is a residential
duct design software based on ACCA Manual-D. This is meant as a replacement for speed-sheet users or
people who are new / learning duct design concepts.

The web site is free to use, but this project is also setup to be self-hostable if that's your
preference.

## Self Hosting

Documentation coming soon!

## Path templates

On Equivalent Lengths, click + and choose From template inside the add modal to build a guided path.
Manage templates from the project or your account, and share independent copies
through [JSON export/import](docs/path-template-sharing.md).

See the [implementation and verification notes](docs/path-template-implementation-plan.md)
for catalog coverage, persistence, and local checks.
## Cool Calc PDF import

To create a project and its rooms together, open the new-project dialog on the Projects
page and choose **Import from Cool Calc PDF**. Upload the report, then choose **Create
project from PDF**. The importer reads the project name, US address, and SHR from the
report and opens Room Loads. It saves the project, rooms, and default component losses
in one transaction. If the parsed name or street address and ZIP code match one of the user's projects, the
upload pauses for **Cancel** or **Create another project**. Matching ignores capitalization
and repeated whitespace; ZIP+4 matches its five-digit ZIP. Confirming creates a separate
project and preserves existing projects. Existing project names receive a numbered suffix. Equipment and
duct design settings still need to be entered in their usual tabs.

On a project's Room Loads page, use the upload icon, choose **Cool Calc PDF** under **File type**, and upload a text-based
Cool Calc MJ8 report. The first version supports the `Individual Room Analysis` layout
with room headings such as `Dining - Level: Level 1` and paired heating/cooling loads.

The importer creates rooms using the analysis heating and total cooling loads, including
their infiltration allocation. It uses the summary's room list, when present, to check
for missing analysis rooms; it does not import the summary's load values or system loads.
Rooms start with one register and no delegation. Repeated names across levels receive a
level suffix. Names, registers, and delegation can be edited after import.

Sensible cooling is calculated from total cooling using the project SHR. An existing SHR
is preserved; if unset, the report's SHR initializes it. The calculated sensible value is
not stored as a reported load, so changing SHR updates it. This assumes the same
sensible/latent split for every room.

Re-importing into a project with rooms asks for confirmation. Continuing updates rooms
with matching names and adds missing rooms. Matching ignores case and surrounding spaces;
renamed rooms whose names no longer match the file are treated as separate rooms. Rooms
absent from the file are kept. PDF imports preserve register counts and delegation on
existing rooms; CSV imports apply those settings from the CSV. Updates preserve room IDs
and trunk assignments.

Imports are saved in a transaction. Ambiguous names, incomplete room records, and invalid
loads leave the project unchanged. Scanned, locked, and multiple-system reports are not
supported in this draft. Uploads are limited to 10 MB and 200 pages, with a 20-second
text-extraction timeout, at most four active extractors, and a 5 MB streamed text limit.
Linux extractors also have 512 MiB address-space and 20-second CPU limits; core dumps
are disabled. Temporary uploaded PDFs are removed after extraction.

The server needs Poppler's `pdftotext`. The Docker images and devcontainer install
`poppler-utils` and `util-linux` for Linux resource limits. For a native installation, install Poppler and set `PDFTOTEXT_PATH` if
the executable is not at `/usr/bin/pdftotext`.

Run `swift test --filter 'PdfImportClientTests|ProjectTests|RoomTests|RoomPDFUploadTests|EnvVarsTests'`
to verify extraction, upload handling, and database behavior. The PDF test fixture is a
synthetic document containing the reference room-analysis values, without the customer's
project name or address. Set `COOL_CALC_REFERENCE_PDF` to the original reference PDF's
path to also compare its extraction with the fixture.

## License

This project is licensed under Creative Commons 4.0.  See the
[LICENSE](https://github.com/m-housh/swift-duct-calc/blob/main/LICENSE).

## Contributions

We are open to contributions.  Feel free to open an issue or pull-request.
