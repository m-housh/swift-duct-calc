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
