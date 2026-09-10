# Fitting catalog boundaries

The [calculation catalog](../../Sources/FittingClient/Resources/catalog.json) and
[reference transcription](../../Sources/FittingClient/Resources/reference.json)
have different meanings. The reference retains source tables and experimental
exports. The calculation catalog contains reviewed rules and construction-specific
identities. A reference record is not evidence that its table is an implemented,
verified calculation.

Combining the resources requires explicit mappings for source codes, construction
variants, table axes, and the Group 11 concept. Matching counts, names, or artwork
paths cannot establish those mappings. Both resources are maintained directly;
there is no generator or PDF extraction step in the build.

Fitting IDs must survive changes to artwork, names, and source-document layout.
Several construction IDs can share a printed source code. Group 11 has the
application ID `11-junction-box`, with no invented printed 11A/11B codes. Keep
source citations and printed pages in reference exports without making runtime
identity depend on an old PDF path or hash.

The SVGs under `Public/images/fittings` and `Public/fittings/concepts` are finished
assets. Some embed raster bytes; those bytes are part of the drawing. The imported
artwork retains connection context needed to understand its application. Historical
extraction prompts, rejected candidates, review hashes, source PDFs, and QA images
remain in Git history. They are not prerequisites for changing or testing the app.

## Duct-shape classification

`ductShape` describes the connection used for picker ordering. `shape` describes
the drawing and can be mixed even when the relevant duct connection is round.
Names inferred from drawings are not a reliable classification source. Group 2
uses the trunk connection; Group 4 uses the boot or stack-head duct connection.
A rectangular register face does not make a round-neck boot rectangular.

Author classification in the calculation catalog. `ductShapeReviewed` records
classification review only; it does not approve numerical rules or hide choices.
The [development review page](../development.md#editing-duct-shape-classifications)
writes this source file. Production packages it at build time, so saving a review
does not update an already deployed application.

For numeric ambiguities, see [source interpretation decisions](fitting-rules.md).
For saved calculations, see [saved-path compatibility](saved-paths.md).
