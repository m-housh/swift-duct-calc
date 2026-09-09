# Group 3 connection context revision

User feedback, 2026-09-04: separated fittings retain too little of their original upstream/downstream sections. The annotated 3C example requests the full main-duct width and surrounding central section, alongside the complete takeoff and transition.

This supersedes the earlier instruction to keep only a small connecting fragment. Preserve the original main-duct cross-section, direction, taper and a substantial section on both sides of each separated connection. Do not rotate the main duct inline with a side branch. Preserve original standalone artwork and accepted full references.

The user confirmed the revised 3C extent: “Yes, use this amount.” All 16 separated main-duct assemblies (22 fitting IDs including shared corner variants) have now been revised and visually inspected against their accepted full references. The active review includes the revisions. Final artwork acceptance remains pending; the confirmation concerned context extent.

Current per-fitting QA, selected assets and prompts: `docs/fitting-preflight/group-3-expanded-context.json`. Earlier individual QA and inspection sheets describe the superseded small-context drawings and remain as history. The packager overlays the current QA onto those historical entries.

All 32 packaged SVGs were parsed and their embedded PNGs, revision hashes, references and review data verified. Exactly the 22 revised fitting IDs changed; the 10 retained entries, accepted full references, fitting values and source metadata are unchanged. The active review and revised SVGs respond successfully on port 8765.

## 3C candidate

- Artwork: `Public/images/fittings/group-3-individual/3C-context-v2.png`
- Source: `Public/images/fittings/group-3-enhanced/3B-restored-art.png`
- Method: built-in image generation tool, precise object edit.
- Inspection: full-width main duct now passes beneath the far-side branch, with upstream and downstream extent. Curved takeoff, transition panels, seams and rectangular outlet remain recognizable against the source. Cut-end completion is illustrative. User confirmed this context extent; final batch review remains pending.
- Original annotated attachment was visible in the conversation; the supplied `/home/michael/Downloads/3c_expected.png` path was absent on this host.

### Generation prompt

Use case: precise-object-edit. Image 1 is the user's annotated original showing a red dotted boundary around the expected fitting 3C. Image 2 is the accepted high-resolution full source and is the edit target. Extract precisely the portion of Image 2 corresponding to inside the red boundary in Image 1: preserve the full 3C far-side curved takeoff and straight transition to the upper-right shallow rectangular outlet, PLUS the full-width main rectangular duct body underneath, with substantial original upstream and downstream main duct on both sides of its attachment. Main duct must span the original central bay between neighboring 3A and 3B connections, not shrink to wall strips or a tiny stub. Preserve original isometric perspective, source lines, takeoff curves, transition proportions, seams and outlet rim. Remove other branches 3A, 3B, 3D and all labels. Complete the two cut ends of the retained main duct as straight rectangular boundaries, maintain its original cross-section. Do not turn the branch into a top-mounted takeoff. Thin crisp black technical outlines on white. Center the complete main-duct segment plus 3C with white margin. No red boundary, no text, no shading. The main duct should be a substantial recognizable volume matching the user's marked extent.
