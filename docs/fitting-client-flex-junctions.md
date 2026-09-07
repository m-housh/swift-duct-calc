# Group 11 flex junction box

Catalog revision `fitting-catalog-v14` contains 227 fitting choices and covers all
groups 1–12. Group 11 has one application identity, `11-junction-box`, with an
optional supplied 90° radius bend. No source letters 11A/11B are invented.

The user believes the box table refers to outlet velocity but explicitly chose
one control with the source's ambiguous wording, **Velocity in flex duct**.
There is no inlet/outlet selector and no inferred controlling duct. The optional
bend uses its own separate velocity. This is a user-confirmed input contract,
not a claim that the source resolves the underlying terminology.

New drafts default the box to 700 FPM, sidewall openings, and bend off. Retained
bend defaults are 700 FPM and R/D 1.0. Published velocity choices are 400–900 FPM
in steps of 100; bend radius categories are 1.0, 1.5, 2–3, and 4–5. There is no
interpolation or extrapolation. Missing submitted values remain missing; disabled
bend inputs are preserved but neither required nor included in the result.

At the defaults the box is 60 ft. Enabling the supplied bend gives 60 + 15 = 75 ft.
Each component has a distinct rule key. Quantity multiplies the complete entry.
Top/bottom openings remain unsupported under the source footnote. Straight
approaches/departures, sidewall connections, and at least two duct diameters of
exit spacing remain visible applicability guidance. Adding the bend does not
correct an otherwise incompatible box arrangement.

## Source and artwork audit

The six box values and 24 bend cells were independently reviewed against
`Public/files/ManD.Groups.pdf`, viewer pages 42–43, printed page 181. PDF SHA-256:
`aae20d968d8238c8958a2c010012aca59ef4b5eed4ce749ed2b722d222997334`.
The source wording stays intact; source provenance remains internal.

The previously reviewed prototype flow's SVG schematics are promoted to
`Public/images/fittings/group-11` with schematic captions and SHA-256 revisions.
They are code-native illustrations, not extracted source artwork. The box-only,
supplied-bend, and bend-detail views are available independently of calculation
inputs. Their visual presentation is included in the upcoming picker UI review.

## Verification

Swift 6.2: the fitting suite passes 84 tests in 17 suites. New tests cover every
box/bend source cell on both path types, independent velocities, defaults,
missing fields, unsupported openings, disabled-bend preservation, snapshot encoding,
source-code behavior, and all three artwork views.
