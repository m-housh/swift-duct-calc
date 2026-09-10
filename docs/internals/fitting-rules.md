# Source interpretation decisions

These decisions explain where the fitting rules require interpretation of the
Manual D source, or deliberately differ from legacy lookups. Source tables and
numeric expectations belong in the catalog and tests, not a second table here.
The original import audits and source scans remain in Git history.

Source reference velocities and friction rates describe applicability. They do
not authorize an inferred velocity correction to a fixed equivalent length.
Rounding policies are specific to a rule family; do not apply them to other tables.
Unavailable cells remain unresolved rather than becoming zero or a nearby value.

## Reducing-trunk takeoffs

The detailed Group 3 drawings take precedence over misleading overview or legacy
mappings. 3W uses its specific 30 ft label; the legacy radius-dependent values
belong to adjacent 3S. 3J shares the 3D constructions even though the legacy lookup
omitted it. 3U uses its specific mitered table with and without vanes, rather than
3S's overview row. Assembly lengths already include their named components.
See [reducing-takeoff tests](../../Tests/FittingClientTests/ReducingTakeoffTests.swift).

## Return junctions and panned returns

For Group 6, maintainers chose the nearest published branch/total airflow ratio,
with midpoint ties going to the higher ratio. The printed worked example uses an
intermediate equivalent length; DuctCalc deliberately uses only table values.
Select using the unrounded ratio. For example, 530/707 selects 0.7 even though a
two-decimal display reads 0.75. Decimal midpoint construction avoids binary
floating-point errors at exact ties.

The source-defined lower range for 6A through 6C is different from rounding.
6D/6E do not gain that range. An unavailable trunk cell at ratio 1.0 remains
unavailable even when a nearby ratio rounds to it. Branch and trunk contributions
belong to different routes through a path; they must not be summed as one fitting.
See [return-junction tests](../../Tests/FittingClientTests/ReturnJunctionTests.swift).

Group 7 also uses nearest published airflow with higher-row midpoint ties, but
checks source bounds before rounding. Out-of-range airflow cannot be clamped into
a supported row. Its merging-flow adjustment is separate from quantity. See
[panned-return tests](../../Tests/FittingClientTests/PannedReturnTests.swift).

## Elbows and offsets

For 8A at R/D 1.0, four/five-piece and three-piece 90-degree elbows use 20 ft and
25 ft respectively. The apparent swapped mapping in the legacy lookup is not
carried forward. The smooth-round heading says less than 90 degrees but lists
110, 130, and 150 degrees. Maintainers confirmed using those listed angles, as
well as the 90-degree base. See
[round-elbow tests](../../Tests/FittingClientTests/RoundElbowTests.swift).

New round-elbow drafts use R/D 1.0 and 90 degrees. These defaults also apply when
selecting a round base for a double elbow. Defaults initialize a draft; omitted
submitted fields still require input, and saved calculations retain their inputs.

8L and 8M represent matching 90-degree elbow pairs. Their source multiplier applies
once to one elbow's length. Quantity counts complete pairs. For 8O, R means the
inside-corner radius. Maintainers accepted the printed categories without inventing
units or a ratio denominator. The final category is strictly greater than 0.50,
not inclusive. Mitered is the new-draft default. See
[double-elbow tests](../../Tests/FittingClientTests/DoubleElbowTests.swift).

Multi-turn offset lengths cover the complete illustrated arrangement. Do not
multiply them again by the illustrated elbow count. The unsupported 8H vane cell
stays unavailable, and 8K's zero-radius row is supported. See
[offset tests](../../Tests/FittingClientTests/OffsetTests.swift).

## Flex junction box

The Group 11 source says "Velocity in flex duct" without clearly resolving inlet
versus outlet. Maintainers chose to retain that wording and one box-velocity input.
Do not infer a controlling duct or add an inlet/outlet selector as though the
source settled it. The optional supplied bend has an independent velocity input;
adding it cannot make an incompatible box arrangement valid. See
[flex-junction tests](../../Tests/FittingClientTests/FlexJunctionBoxTests.swift).

## Transitions and squeezes

Transition ratios refer to cross-sectional areas, not widths or diameters. For
12W, inlet columns and outlet rows must remain distinct. For 12X, the drawing and
footnote identify velocity at the larger upstream A1 section; the smaller A2
velocity is not the table input. Its minimum upstream static pressure is an
applicability condition, not an equivalent-length component or another loss to
subtract. The listed length includes contraction and re-expansion. See
[transition tests](../../Tests/FittingClientTests/TransitionTests.swift).
