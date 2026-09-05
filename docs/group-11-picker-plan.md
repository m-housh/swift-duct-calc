# Group 11 picker proposal

Status: deferred at the user's request to review Group 12 next. Guidance reviewed;
proposed representation, not implemented or approved.
Group 10 is approved and committed as `4b848b3`, including corrected 10F arrows.
Group 12 review takes priority; resume this proposal when the user returns to it.

## What the supplied source contains

Primary artwork reference: `Public/files/ManD.Groups.pdf`, printed page 181,
PDF pages 42–43 (one original page split across two PDF pages). Title:
Flexible Duct Junction Boxes and Radius Bends. Reference friction rate is
0.08 IWC per 100 feet; velocity varies by table row.

The source presents two calculation cases: a junction box and a radius bend.
A, B and C label entrance, exit and nearby-turn details in the explanatory
illustrations; they are not a numbered catalog of fittings 11A, 11B and 11C.
L is spacing, D is duct diameter, R is bend radius and theta is bend angle.
The large multi-box assembly is useful context, not one selectable fixed loss.

The supplied page associates its box values with straight approaches/departures,
side-wall connections, and exit spacing at least two duct diameters from the
entrance. It describes an optional entrance diffuser for pressure recovery and
swirl control. Nearby turns or inadequate spacing can make its listed losses
too small. Do not assign an invented correction factor to those arrangements.
The red tentative annotation on top/bottom exits is part of the supplied source;
it does not resolve the contradictory editorial state or authorize an exception
to the table footnote restricting openings to the sides.

Transcription of the supplied table, for provenance rather than production use:

| Velocity, fpm | Box EL, ft | 90° bend R/D 1.0 | R/D 1.5 | R/D 2–3 | R/D 4–5 |
| --- | --- | --- | --- | --- | --- |
| 400 | 20 | 5 | 5 | 5 | 5 |
| 500 | 30 | 5 | 5 | 5 | 5 |
| 600 | 40 | 10 | 5 | 5 | 5 |
| 700 | 60 | 15 | 10 | 5 | 5 |
| 800 | 75 | 15 | 10 | 10 | 8 |
| 900 | 95 | 20 | 15 | 10 | 8 |

The source explicitly scales bend EL by angle/90. Its example is R/D = 1.0,
700 fpm, 45°: 15 × 45/90 = 7.5 ft. It gives no interpolation/extrapolation
policy for intermediate velocities or gaps between radius categories.

## Proposed picker choices

| Choice | Artwork | Inputs and behavior |
| --- | --- | --- |
| Flex junction box | One box with straight round inlet/outlet stubs, plus a plan-view spacing illustration | Velocity and applicable construction conditions. Highlight the selected inlet-to-outlet path; show other outlets as context. |
| Flex radius bend | Standalone round flex bend with readable D, R and angle callouts | Velocity, R/D and angle. Reuse artwork for different velocities; vary bend appearance for radius/angle where useful. |

Use application keys such as `11-junction-box` and `11-radius-bend`, retaining
source group 11 and descriptive case names. Do not imply these keys are printed
source IDs. Both depict round flexible connections; the rectangular box body
does not create a rectangular-duct option.

Artwork deliverables proposed for review:

1. Junction-box perspective, with an inlet and multiple straight outlet stubs.
2. Junction-box plan view that clearly shows the inlet-to-exit spacing L and D;
   optional diffuser may be a separate overlay/view, without inventing a new EL.
3. Standalone radius-bend illustration with R, D and angle annotations.
4. Original assembly retained as a reference/help view, with the active flow
   path emphasized if later needed, following the Group 7 assembly approach.

Keep unsupported construction examples in guidance rather than offering them
as ordinary selectable fittings with an unqualified table value. Conditions
belong beside the box choice, where they affect whether that calculation applies.

Proposed path accounting: add the box once to a path that traverses it and add
the separate downstream/upstream bends on that path. Other outlets shown in the
illustration do not increase quantity for that path. Confirm this mapping against
the chosen edition's full calculation guidance before implementation.

## Calculation decisions to resolve before implementation

- **Edition:** identify which Manual D edition the application will implement.
  ACCA's [2017 release notice](https://www.acca.org/news/release/acca-updates-manual-d)
  explicitly reports revised flex-junction-box equivalent lengths in Manual D
  2016. The supplied Appendix 3 page cannot be assumed to contain current values.
  Do not replace it with numbers from a public-review draft or mix editions.
- **Velocity:** confirm which connected duct's velocity controls the box lookup
  when inlet and outlets differ. The supplied header only says velocity in flex
  duct. For a bend, use its own duct velocity. Where airflow and diameter are
  available later, derive velocity and show it; retain the underlying inputs.
- **Table coverage:** verify interpolation, rounding, supported angle/radius
  ranges and handling of out-of-range inputs in the chosen edition. Until then,
  avoid automatic extrapolation or silently assigning a nearest category.
- **Unsupported layouts:** retain an explicit documented manual value path when
  the chosen table does not cover a layout, rather than returning a fabricated
  automatic result. Verify supply/return applicability separately.
- **Persistence:** save case, inputs, source edition/table, calculated value and
  any manual override provenance. Preserve fractional equivalent lengths.

The existing `Sources/ManualDCore/EffectiveLengthGroup.swift` explicitly leaves
Group 11 for manual entry (line 522). The current form asks for group, letter,
length and quantity; its fixed lookup representation is insufficient for these
parameter-dependent cases. No runtime code or calculation tables were changed
during this guidance review.

## Corroboration and scope

The [DOE-hosted IBACOS research presentation](https://www1.eere.energy.gov/buildings/publications/pdfs/building_america/cq5_duct_splitter_box_beach.pdf),
slide 6, reproduces the older box recommendations and velocity table. Its study
also reports sensitivity to box size, outlet placement and flow conditions.
This supports showing construction context; it is not a replacement for the
selected Manual D edition's calculation rules. ACCA's
[Manual D product guidance](https://www.acca.org/standards/technical-manuals/manual-d)
also identifies revised flex-junction-box values.

Next artwork step: prepare the two selectable families and their supporting
views above after discussing this representation. Edition verification can
proceed separately; artwork preparation need not imply a production formula.
