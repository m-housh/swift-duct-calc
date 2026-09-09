# Reference-entry CSV proposal

CSV paste/upload is follow-up work. The existing [picker](fitting-picker-preview.md)
already supports single reference entries. This is the retained proposal for bulk
entry; its import format and UX still need review.

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
