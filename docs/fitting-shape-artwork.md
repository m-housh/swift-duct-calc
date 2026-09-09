# Fitting artwork by duct shape

## Group 2 renewed review

Group 2 is reopened as `group-2-restored`, with 17 fresh source restorations,
2A–2Q, now approved after the 2F and 2O corrections. Each retains a full main-trunk section on both sides of
the branch. 2A–2H connect to the side of a rectangular trunk; 2I–2M connect to
its top; 2N–2Q connect to a round trunk. The old `group-2` catalog entries, traced
SVGs and approval records remain an unchanged checkpoint.

The new manifest has per-family default and shape lookups. `mixed` denotes a
rectangular main with a round branch; `connectionShapes` records both separately.
The original entry geometry remains part of the fitting identity: plain versus
flared or projecting entry, round versus rectangular hood, curved versus square
heel, and straight versus tapered collar. Do not substitute among those cases
merely to match a shape.

All 102 equivalent-length entries remain attached to their source fitting and
downstream branch-count ranges (0, 1, 2, 3, 4, 5+). Count to the trunk end or next
reducer and restart after each reducer, as the original table states. These
records support later picker work; no calculator code changed in the retry.

## Group 5 shape variants

Group 5 artwork is indexed by fitting family and return-duct cross-section in
`Public/images/fittings/group-5-shapes/manifest.json`. Shape describes the return
duct; the equipment and plenum may remain rectangular.

The current mapping groups source pairs under the first source ID. Every variant
keeps its actual `sourceFittingId`, source reference, conditions and equivalent
length data. Family naming does not renumber or overwrite the source records.

| Family | Rectangular source | Round source |
| --- | --- | --- |
| 5A — oversized plenum entry | 5A | 5B |
| 5C — tapered plenum entry | 5C | 5D |
| 5E — compact plenum top entry | 5E | 5E |
| 5F — compact plenum side entry | 5F | 5G |
| 5H–5O | Same source ID | Not currently provided |

The source explicitly allows square or round for 5E. Its rectangular artwork is
adapted from the isolated round illustration. Existing individual assets are
reused for the other variants. The combined elevation and isometric views are
currently stored together; shared side profiles can be split into separate view
assets later without changing the family/shape keys.

For a future picker:

1. Resolve an existing source ID through `sourceIdToFamilyId` if necessary.
2. Find the family and select `artworkByShape[ductShape]`.
3. Use its `image` for display and `itemId` to find the full variant record.
4. Use that variant's `sourceFittingId` and source values for the relevant source
   case. Do not infer calculation applicability merely from an artwork variant.

For example, `5A` with `round` selects `5A-round.svg`, whose source fitting is
`5B`. Both `5E` shapes refer to source `5E` and retain its return-count conditions.
An absent shape means no artwork is provided for that choice; do not silently
show a rectangular image for a round request.

The shape review contains 16 variants in 12 families, with all 15 source IDs
retained. The current naming and source-only coverage are recorded in
`docs/fitting-preflight/group-5-shape-variants.json`. All 16 current variants were approved by the user on 2026-09-05. Approval is
recorded against the exact SVG/reference revisions; changed artwork requires review.

Rebuild and activate with:

```sh
python3 scripts/package_group_5_shapes.py --activate
```

Full source restorations and the earlier individual batch remain available.

## Group 7 individual and assembly views

`Public/images/fittings/group-7-options/manifest.json` provides `families[].artworkByView` for display choices independently of duct shape. For 7A–7C, choose `individual` or `assembly`; 7D–7E currently provide `individual`. Each lookup returns `itemId` and `image`. The assembly options keep the full illustration and emphasize the selected fitting using bold blue arrows. Existing individual artwork remains unchanged and accepted. All options retain their original fitting IDs and calculation metadata. All current assembly variants are approved.

7C also provides `artworkByView["assembly-merging"]` for an upstream return joining the joist return. Its item records `artworkCondition.upstreamReturn` and `mergingFlow`, plus an additive 40 ft `equivalentLengthAdjustment` sourced from `referenceValues.mergingFlowEquivalentLengthFeet`. The airflow-based table remains unchanged; the 40 ft is an addition, not a replacement total. The existing `assembly` view remains separate. The eight preceding options are now approved; the merging variant is approved. These fields prepare artwork selection and do not implement calculator behavior.

All nine current Group 7 artwork options are approved, including the revised merging view with subdued joist arrows. Approval is bound to each exact SVG/reference revision.

## Group 8 construction and shape options

Group 8 is approved and committed as `4cc7dd0`. Its manifest provides 25 artwork
items across 8A–8P. Eight 8A construction styles have distinct
`artworkByVariant` keys; 8L and 8M each have round/rectangular
`artworkByShape` alternatives. The source tables and conditions remain attached
to each item. These drawings do not implement the equivalent-length calculations.

## Group 9 junction shapes

Group 9 provides one source-specific drawing for each of 9A–9R. Its manifest's
`families[].artworkByShape` maps the depicted shape to its item and image.
9A uses `mixed` because it joins a rectangular main to a round branch;
`connectionShapes` records the main and branch separately. Do not substitute
another source junction merely to satisfy a different shape selection.
9A–9J retain separate branch/main equivalent lengths; 9K–9R retain the single
value printed for their case. Applicability is supply trunk junction flow,
with a substantial secondary-trunk share of primary flow, as stated in the source.
All 18 Group 9 drawings are approved and committed as `f6601f2`. Exact SVG/reference revisions are archived
from the user's explicit approval.

## Group 10 return junction shapes

Group 10 provides seven approved individual drawings, 10A–10G. 10A–10D
are rectangular; 10E–10G are round. Each family has a default variant and a
shape lookup. Rectangular geometry derives from approved 9K–9N, with airflow
reversed for merging returns; `geometryBasedOn` records the source revision.
Original Group 9 artwork is preserved. The three round entries retain their own
source construction and flow arrows.

Source equivalent lengths are 75, 10, 10, 25, 25, 35 and 75 ft, respectively,
at the source reference velocity of 700 fpm and friction rate of 0.08 IWC/100 ft.
These describe two return trunks merging; the source directs branch-return
values to Group 6. They remain artwork metadata, with no calculator changes.

## Group 12 transitions and special cases

Group 12 has 24 approved source-specific items, 12A–12X.
12A–12I expand and 12J–12R reduce. Opposite flow cases retain their own IDs,
arrows and equivalent-length tables. Slope/area-ratio selections are table inputs;
the source gives one representative drawing per fitting, not a separate drawing
for every numeric table cell.

`connectionShapes` records inlet/outlet cross-sections on the directed transitions.
Round-to-rectangular transitions use `mixed`; a shape lookup must not lose the
opposite end's shape. 12S–12U join oval and round ends; 12V joins rectangular
and round ends. Those source drawings do not specify airflow direction.
12W/12X use `schematic`, since the cross-sectional outlines do not establish a
specific duct shape. Their labels remain visible because the source tables refer
to them.

Full source pages 182–184 preserve the slope/area definitions, velocity-dependent
plenum table and squeeze static-pressure table. The 86 source values for 12A–12V
were cross-checked against the existing Swift lookup; 12W/12X are additional
source cases absent from that lookup. No calculator code was changed.
Group 11 is implemented; see [the flex junction audit](fitting-client-flex-junctions.md).

## Group 13 excluded

The user explicitly excluded Group 13 (Manual Balancing Dampers, 13A–13D)
from the fitting picker. Do not generate SVGs or picker entries for this group.
The original reference PDF remains available.
