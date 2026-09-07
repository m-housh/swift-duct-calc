# Duct connections used for picker ordering

The picker preference describes the duct being used along the path. It is separate
from `Definition.shape`, which describes the overall drawing and often says `mixed`
for a fitting with a rectangular register face and a round duct collar. Descriptive
names are not a reliable substitute: the Group 4 names were inferred from geometry,
while the source supplies fitting numbers and equivalent lengths.

The presentation mapping lives in
[`PickerDuctShape.swift`](../Sources/ViewController/Views/FittingPicker/PickerDuctShape.swift).
It changes ordering in both Favorites and All fittings, without changing catalog IDs,
artwork, calculation rules, saved lengths, or which fittings are available.

## Group 2: trunk connection

Round puts 2N–2Q first. Rectangular puts 2A–2M first. In particular, the round branch
outlets on 2A–2C and 2I–2K do not make their rectangular trunk connections round.

## Group 4: duct connection at the boot or stack head

All 44 source reference drawings were reviewed for the connected duct shape. A
rectangular register opening does not make a round-neck boot rectangular; likewise,
a curved heel on a rectangular boot does not make its duct connection round.

| Preferred duct shape | Source fittings | Count |
| --- | --- | --- |
| Round | 4G–4L, 4Q–4Z, 4AA–4AE, 4AG, 4AJ, 4AK | 24 |
| Rectangular | 4A–4F, 4M–4P, 4AF, 4AH, 4AI, 4AL–4AR | 20 |

Round therefore starts **4G, 4H, 4I, 4J, 4K, 4L**. Rectangular starts
**4A, 4B, 4C, 4D, 4E, 4F**. Source order is retained within each set.

Examples from the source references:

- [4A](../Public/images/fittings/references/group-4/4A.png) and
  [4D](../Public/images/fittings/references/group-4/4D.png) have rectangular connections.
  The inferred 4D name mentioning a “round throat” must not control its ranking.
- [4G](../Public/images/fittings/references/group-4/4G.png) and
  [4I](../Public/images/fittings/references/group-4/4I.png) show round duct collars.
- [4Y](../Public/images/fittings/references/group-4/4Y.png) and
  [4AA](../Public/images/fittings/references/group-4/4AA.png) have rectangular register
  faces but round duct necks.
- [4AF](../Public/images/fittings/references/group-4/4AF.png) has a rectangular side
  connection; [4AG](../Public/images/fittings/references/group-4/4AG.png) has round connections.

[The Group 4 source review](group-4-review.md) links every reference drawing. This
mapping is explicit so future additions cannot silently pass the full-catalog audit
by inheriting the artwork's broad `mixed` classification.

Swift checks cover all 44 IDs. The preference browser check verifies the full round
and rectangular order, all 44 originals remaining visible, and matching ordering of
favorite copies without moving originals when starred.
