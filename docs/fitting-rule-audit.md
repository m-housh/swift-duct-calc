# Original template input audit

This document records the template branch's original source audit. The integrated
application uses the current `FittingClient` for all numeric evaluation. The
historical restrictions below describe the original template form options. Current
guided options come from the same catalog as the ordinary picker. See [the integration notes](path-template-implementation-plan.md).

The initial template catalog packages 231 definitions for all eligible groups. It
enables 47 calculation cases checked against the supplied
`Public/files/ManD.Groups.pdf` on 2026-09-08. Other definitions retain their
identity and approved artwork but return an unresolved calculation.

| Cases | PDF pages checked | Rule |
| --- | --- | --- |
| 1A through 1E | 1 | Fixed 35/10/35/10/10 ft |
| 2A, 2B, 2N through 2Q | 5, 9 | Explicit downstream counts 0 through 4; inclusive 5-or-more range |
| 4G, 4Q, 4R | 18 | Fixed 80/50/20 ft |
| 5A/5C families, round and rectangular | 20 | Fixed 40 ft; round source codes are 5B/5D |
| 5E round/rectangular, 5F rectangular | 21 | Return-count categories 1 and 2 or more |
| 5H/5I/5J rectangular | 22 | Exact H/W or R/W rows; no interpolation |
| 6F through 6P | 28, 29 | Fixed return-boot values |
| All eight 8A constructions | 32 | Fixed or exact construction/R/D table entries |
| 12J | 45, 46 | Exact slope and area-ratio table |
| 12S/12T/12U | 47, 48 | Fixed 30/30/25 ft |

The 8A discrepancy is resolved for the new catalog: the source assigns 20 ft to
the four- or five-piece 90° elbow at R/D 1.0, and 25 ft to the three-piece 90°
elbow at that ratio. The three-piece 45° case is separately listed at 10 ft.
Existing legacy saved values are not rewritten.

For smooth round 8A elbows, only the explicit 90° base and the listed angles
below 90° are enabled. The source heading conflicts with its 110°/130°/150°
columns, so those angles remain unavailable. Fractional multiplier results stay
fractional through evaluation and persistence.

These are reference-condition values, not an inferred velocity correction.
Group 5/6 source reference velocity is 700 FPM; Group 1/2/4/8 and these Group 12
cases use 900 FPM. Their source reference friction rate is 0.08 IWC per 100 ft.
The drawings and source conditions still govern fitting applicability.

The original template generator and duplicate catalog have been removed. Current
identities, requirements, and numeric evaluation come from `FittingClient` and
`Resources/catalog.json`. This table remains a record of the initial audit.

Current rule coverage and limitations are recorded in the
[catalog expansion](fitting-client-catalog-expansion.md) and per-rule audits.
The original template restrictions above are historical.
