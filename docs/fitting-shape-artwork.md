# Fitting artwork by duct shape

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
All 18 Group 9 drawings are approved. Exact SVG/reference revisions are archived
from the user's explicit approval.
