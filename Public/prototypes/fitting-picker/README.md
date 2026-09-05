# Fitting picker design exploration

## Current review entry points

- **Preferred:** [Path list with the three-card looping carousel](path-carousel.html).
  Supports swipes/drags, buttons, favorites first, group usage indicators,
  editable row quantities, and running totals.
- [Path list with a group-grid pop-up](path-list.html).
- [Frozen guided prototype 2](index.html?v=guided&favorites=first).
- [Original five-direction comparison](index.html).

The user approved the latest carousel pass for continued exploration. This remains
a prototype with a partial sample catalog. Full-path evaluation is deferred until
the fitting artwork and associated catalog data are ready.


Served by the existing static server at `/prototypes/fitting-picker/`.

- `?v=gallery`: Large drawing gallery with a configuration dialog.
- `?v=guided`: Group → drawing → dedicated configuration screen.
- `?v=focus`: Single large drawing, previous/next controls, and thumbnail strip.
- `?v=compare`: Select two drawings, configure and add from a side-by-side comparison.
- `?v=inline`: Illustrated catalog rows with inline configuration expansion.
- `original.html`: Original exported prototype, retained for reference.

All five share the same 17 sample fittings and temporary in-memory path state.
Group 4 starts with approved boot drawings. Group 1 includes the 1F H/W example;
Group 2 includes downstream-branch examples. Return preview includes 7A. Other
eligible groups remain visible with explicit sample-availability states.

Lengths are read-only. The dimension example resolves only exact documented
ratios; interpolation or other between-entry behavior is not established here.
Values are existing repository reference data, not a newly validated standard
calculation engine. Straight lengths are sample inputs from step 2.

`assets/` contains prototype-only SVG viewport copies that remove sheet headings
and footnotes from the artwork area while retaining drawing geometry and internal
dimension annotations. Original artwork sources remain untouched. Group 3 uses
existing art-only assets directly.

No project data is saved; switching design directions or reloading clears entries.
Changing supply/return within one direction preserves each temporary path.

Interaction checks exercised fixed values, quantity edits, dimension calculations,
unresolved ratios, branch counts, filtering, path preservation, and removal in
all five flows. HTTP checks cover the page, scripts, stylesheet, and every image.

## Favorites

All five directions support favorite fitting IDs and an All / Favorites filter
within each group. The guided group cards include direct favorites shortcuts and
counts. Favorites persist in browser localStorage under
`swift-duct-calc.fitting-picker.favorites.v1` and are shared across directions on
the same browser origin, including updates from other open tabs. They are local
to this browser, not a user account or a predefined regional catalog. No favorites
are seeded. Only the fitting identity is saved; dimensions and quantity remain
part of the current fitting entry. If storage is blocked, favorites remain usable
for the current page with a visible persistence notice.

Favorites filtering does not remove already-added fittings or selected comparisons.
Removing a favorite while configuring in a dialog preserves that draft. Empty
groups offer a route back to all fittings. Checks cover all five flows, stored
favorites on reload, malformed stored values, modal drafts, and comparisons.

## Comparing favorites layouts

The lab toolbar includes a Favorites layout choice in every direction:

- **Favorites first in group** (default): stable partition of the canonical group
  order, with a Favorites heading and an End favorites / Other fittings divider.
  Each fitting appears once. No divider is shown when the group has no favorites
  or has no remaining non-favorite fittings.
- **Separate Favorites tab**: original All fittings / Favorites filtered views;
  All fittings keeps canonical order.

The workbench applies the partition to its thumbnail strip and previous/next order.
Configuration selections, input drafts, path entries, and comparisons are preserved
when changing the layout. The selector updates the `favorites=first|tabs` URL
parameter, which carries when switching directions. Favorite IDs are the same for
both layouts. Guided group shortcuts respect the chosen layout.

Ordering checks cover 4E first, the divider, absence of duplicate fittings,
restoring canonical order after unfavoriting, and switching layouts in all flows.

## Preferred direction and group usage

Current user preference: guided selection (2) with favorites first; gallery (1)
with favorites first is the alternative. Guided additions now return to the group
selection screen. Group cards show actual added fitting artwork, IDs, quantities,
and Edit controls. Unused cards say No fitting added; these are usage indicators,
not a requirement to use every eligible group.

User-defined guidance: groups 1, 2, 3, 5, and 6 are generally used once per path.
A non-blocking warning appears when an entry would bring a group's aggregate
quantity above one, including quantity > 1 on a single row. The action reads
Add anyway / Save anyway; there is no extra confirmation dialog or restriction.
The shared configuration behavior also applies to the other four previews.
Editing excludes the edited row from the existing count. Group cards and current
group summaries update after add/edit/remove, scoped to the selected path type.

Checks exercise all five generally-once groups (5 and 6 use test-only fixtures
because those groups have no examples in the shipped sample catalog), repeatable
group 4, edit exclusion, quantity warnings, continuation, overview navigation,
removal, and path isolation. Existing flow and favorites checks still pass.

## Quantity placement experiment (guided only)

Prototype 2 now defaults each new fitting entry to quantity 1 and edits quantity
in the added-fittings list. Selection and explicit Add / Save confirmation remain.
The configuration screen (including Edit dialogs) omits the quantity field;
editing fitting dimensions preserves the row's current quantity. Selecting the
same fitting for a new entry starts again at one. Prototypes 1, 3, 4, and 5 retain
their existing quantity placement.

Valid whole quantities update row subtotals, path totals, group indicators, and
non-blocking generally-once warnings immediately. Invalid inputs show a message
and preserve the last valid quantity in calculations. No group-specific quantity
locks are introduced in this pass.

For comparison, `quantity-in-config.html?v=guided&favorites=first` preserves the
previous guided flow via snapshot copies of its script and stylesheet. Favorites
remain shared; path entries remain temporary.

Checked default quantities, retained confirmation, direct quantity changes,
validation, total/count updates, warnings, dimension edits, new-entry defaults,
and removal/reindexing. Other preview flows and favorites checks pass.

## Corrected guided flow: no Configure & add step

The quantity-only interpretation above was corrected by the user. Prototype 2 now
has only Choose group → Choose fitting. Clicking a fixed-length fitting's drawing
or Add fitting button immediately adds one and returns to the group overview.
Conditional fitting cards expose dimensions or branch count directly in the
selection grid, derive the read-only length, and enable Add when resolved. There
is no separate configuration screen or quantity input for new fitting selection.

Existing entries retain Edit dialogs for changing dimensions/conditions and inline
quantity fields in the path list. Generally-once warnings appear on fixed cards
before immediate additions and alongside conditional inputs. They never block an
otherwise valid addition. All new entries start at one, including after editing a
previous entry of the same fitting. Other prototype flows remain unchanged.

Checks cover immediate fixed additions, inline dimensional and branch examples,
required/unresolved inputs, duplicate warnings, quantity preservation while editing
and favoriting, new-entry defaults, and existing favorites/other-flow behavior.

## Alternate representation: path list + pop-up picker

Open `path-list.html` for a separate exploration. The existing prototype 2 source,
stylesheet, and entry page are frozen at the direct-selection revision; checksum
verification confirmed this pass left all three unchanged. The alternate uses
its own script, base stylesheet snapshot, and layout stylesheet. It shares only
the fitting sample data/assets and browser favorites with the existing previews.

The main screen starts with an empty vertical list and an Add fitting button.
The button opens a native modal dialog containing the guided group/drawing picker,
with favorites first and existing group usage visible. Fixed-value selection adds
one row and closes the dialog; conditional inputs stay on the drawing card and
Add commits once resolved. Closing or cancelling the picker creates no row.

Tall list rows show entry number, drawing, fitting identity, explicit group title,
read-only equivalent length, editable quantity, subtotal, and Edit/Remove actions.
The group strip summarizes only represented groups, without implying every group
must be used. The bottom emphasizes fitting equivalent length and shows straight
length and complete path equivalent length separately. Generally-once warnings
and quantity validation are preserved. The list order is entry order, not an
inferred physical duct topology.

Checks cover picker cancellation and addition, favorites, conditional inputs,
quantities and invalid values, warnings, existing-entry edits, group coverage,
totals, path-type isolation, removal and numbering. All new served files respond
successfully through the existing port 8765 server. The sample catalog is still
partial; this pass does not add uncompleted artwork or fitting calculations.

## Alternate group picker: carousel

Open `path-carousel.html` for the separate path-list variant with a carousel in
the Add fitting pop-up. It has its own script and carousel stylesheet and reuses
the frozen path-list styles and shared sample fitting data. The preceding path
list and prototype 2 entry/source/style files were verified unchanged.

Group cards sit on a native horizontally scrollable, snapping rail with a large
central card and neighboring cards visible. Previous/next buttons, numbered group
shortcuts with descriptive accessible labels, and left/right arrow keys move the
carousel. There is no automatic rotation or wrapping past the endpoints. The
current group position is retained when returning from drawings or reopening the
picker; supply/return changes reset it to the first eligible group. Numbered
shortcuts mark groups already represented in the path. Existing added-fitting
summaries, generally-once guidance, and favorites shortcuts remain on each card.

Choosing a group retains the established guided selection flow; additions close
the picker and update the tall-row path list and fitting total. Checks cover
navigation controls, endpoints, keyboard actions, position retention, eligibility,
and the full path-list flow (including favorites, conditions, quantities, edits,
warnings, cancellation, and totals). Carousel entry/script/style return HTTP 200.

### Carousel refinement: overlapping cards

`path-carousel.html` now uses a stacked, overlapping presentation: the active
card sits in front, neighboring cards are scaled, slightly rotated, and partially
visible behind it. Arrows, group shortcuts, and keyboard navigation are retained.
Tapping an exposed side card promotes it; choosing the active group opens its
fittings. Only the active card's nested controls are interactive; side cards have
labeled promotion buttons and distant cards are inert and hidden from accessibility.
Motion respects prefers-reduced-motion. The earlier horizontal rail is preserved
at `path-carousel-rail.html`, with independent script/style snapshots.

Navigation and path-flow checks pass for the overlapping variant, including
promoting a group before selection. The previous path-list files remain unchanged.

### Carousel styling and gestures

The overlapping carousel now supports touch swipes, mouse drags, and horizontal
trackpad gestures. Pointer motion follows the drag, with resistance at the first
and last group; sufficient distance or a quick flick advances one group. Short
slow drags snap back. Pointer cancellation resets the stack. Drag-completion
clicks are suppressed so swiping cannot select a group accidentally. Vertical
pointer gestures and vertical wheel scrolling remain available for the dialog.
Horizontal wheel momentum is throttled; zoom wheel gestures are left alone.
Arrows, numbered shortcuts, ordinary taps/clicks, and keyboard navigation remain.

The deck styling has gentler rotation, unified rounded cards, softer layered
shadows, a subtle background, a thinner active border, and compact navigation.
Animations respect reduced-motion settings. CSS/JS URLs are revisioned to load
this change on refresh. Pointer/wheel event checks cover both directions, edges,
quick versus short/slow gestures, cancellation, click suppression, ordinary
selection, and vertical/horizontal wheel behavior. Navigation and full path-flow
checks still pass; the frozen prototypes remain byte-for-byte unchanged.

### Three-card looping carousel

The carousel now shows exactly three group cards: previous, current, and next.
Neighbor positions use the eligible supply/return group order cyclically, so the
last group appears before the first and the first appears after the last. Arrows,
keyboard actions, side-card taps, swipes, and horizontal trackpad navigation all
use the same wrapped index. Both arrow buttons remain enabled and the previous
endpoint drag resistance is removed. Remaining cards are hidden and inert.

Checks cover three-card visibility, accessible/inert states, correct neighbors,
multiple loops in both directions for supply and return, side-card wrapping,
swipe wrapping, and the full path-list flow. Prior finite-endpoint descriptions
above document superseded versions; the current carousel has no endpoints.
