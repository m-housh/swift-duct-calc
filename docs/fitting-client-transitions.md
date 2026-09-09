# Group 12 transitions, plenum passages, and squeezes

Source-file paths and review hashes below record the completed import. Those
files are now retained in Git history; the app uses the
[finished SVGs and catalogs](fitting-assets.md) without a PDF or regeneration step.

Catalog revision `fitting-catalog-v13` contains 226 choices. All 24 Group 12
identities are now implemented on supply and return paths. Group 11 is the only
remaining group without production rules. Step-3 picker and persistence integration
remain pending.

## Typed choices and calculations

Tapered transitions select slope 1:1, 2:1, or 4:1 and larger/smaller area ratio
2:1 or 4:1. Abrupt transitions advertise only the abrupt slope, which is their
new-draft default. All area ratios and tapered slopes begin unanswered. These
are exact published choices, with no interpolation, rounding, or inclusive ranges.
A ratio is cross-sectional area, not diameter or width. Slope is the illustrated
X/Y. Expansion and reduction retain distinct source identities and flow guidance.

12E, 12N, and 12S–12V use the existing fixed rule. The other 12A–12R cases require
the source's slope and area selections even when several cells have equal values.

12W selects inlet and outlet velocities independently from 600/700/800/900 FPM.
The source table's outlet rows and inlet columns are kept distinct: inlet 600 /
outlet 900 is 90 ft, whereas inlet 900 / outlet 600 is 35 ft. This is the entire
illustrated passage through the large plenum.

12X selects upstream velocity at the larger section A1 from those same four
velocity choices, and area ratio 2 or 4. The drawing marks V at the larger duct;
its footnote states that velocity doubles or quadruples in the restricted A2
section. This identifies the table velocity without inferring an arbitrary
controlling duct. Both contraction and re-expansion are included in the listed EL.

Each 12X result retains `minimumUpstreamStaticPressureIWC`, the source's minimum
upstream pressure for positive static pressure at A2. It is a separate applicability
condition, not an EL component or another pressure loss to subtract. For example,
900 FPM and area ratio 4 return 545 ft and a separate 1.17 IWC requirement.
The client does not claim the project meets that requirement; the future UI must
show it alongside the length.

`Conditions.referenceVelocityFPM` is now optional. Catalog definitions for 12W/X
use no single fixed reference velocity. 12X calculations record the selected A1
velocity; 12W retains both selected velocities in its inputs. Other rules retain
their previous reference values. The pressure field is optional for backward
decoding of existing calculation snapshots.

## Internal source audit

All 110 EL cells and eight separate pressure cells were visually read from
the full source scans at `Public/images/fittings/group-12/source-art/page-182.png`,
`page-183.png`, and `page-184.png`. They correspond to `Public/files/ManD.Groups.pdf`
viewer pages 44–48, printed pages 182–184. PDF SHA-256 remains
`aae20d968d8238c8958a2c010012aca59ef4b5eed4ce749ed2b722d222997334`.
The common friction rate is 0.08 IWC per 100 ft; reference velocity is 900 FPM
except where the table explicitly varies it. All 24 SVG/reference-image byte
pairs matched accepted visual-review revisions. Original assets are unchanged.

## Verification

Swift 6.2: `swift test --filter 'Fitting|DatabaseClientTests' --jobs 4` passed
112 tests across 23 suites.

The tests independently encode every EL and pressure cell and exercise supply
and return paths, inlet/outlet direction, missing selections, invalid typed values,
incompatible input families, slope applicability, new-draft defaults, and complete
snapshot round trips. Catalog validation checks table completeness and axes,
pressure presence/units field, and the absence of a fictitious fixed reference
velocity on 12W/X. The integration run also covers startup injection and existing
database behavior.
