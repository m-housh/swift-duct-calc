# Continue the fitting artwork work

The portable branch is `codex/fitting-artwork` in
`https://github.com/m-housh/swift-duct-calc.git`.
The current worktree is `/home/michael/dev/swift-duct-calc`.

## Latest state — Group 8 approved; Group 9 next

Group 7's nine individual/assembly options are approved and committed as
`62599b7`. Group 8, **Elbows and Offsets**, is approved: 25 drawings
covering fitting IDs 8A–8P. Exact current revisions are archived from the user's
approval after the four 8A seam corrections. Group 9, Supply Trunk Junction
Fittings, starts on PDF page 36 (printed page 178) and is next. The historical progress
entries below describe earlier review states.

Group 8 separates eight 8A construction styles and both round/rectangular options
for 8L and 8M. Other fittings retain the shape and construction in the source.
The source PDF continues beyond Group 7 (50 PDF pages total); Group 8 occupies
PDF pages 32–35, printed pages 176–177. Original page images and tables are linked
from each review card. Do not assume Group 7 is the end of the source.

Rebuild/activate with `python3 scripts/package_group_8.py --activate`.
Source metadata and picker mappings are in `Public/images/fittings/group-8/`;
prompts and visual checks are in `docs/fitting-preflight/group-8.json`.
All selected images were compared with their source crops before presentation.
Raster restorations remain embedded in self-contained SVGs. The source's 8A
angle-adjustment heading says less than 90 degrees while also listing larger
angles; preserve that source inconsistency for later calculation review.
Reference tables are recorded as source metadata, not calculator changes.

After approval, record exact image revisions, commit that group, and prepare the
next source group automatically. No additional commit confirmation is needed.
Keep Group 2 paused and unrelated `Public/prototypes/` work out of artwork commits.

Latest Group 8 correction: bottom-up seam numbering starts with the lowest outline
as 1. `8A-4-or-5-piece` seams 2/4, `8A-3-piece` seam 2, and `8A-easy-bend`
seams 2/3 are now single lines. `8A-hard-bend` seam 2 is removed entirely;
seams 3/4/5 and its outlet boundary are single lines. Active files end in
`-single-seams-v3.png`. All four were visually checked; a first four/five-piece
candidate accidentally removed seam 3 and was corrected before selection.
The other 21 drawings are unchanged. All 25 drawings, including these corrections,
are now approved by the user.

## Clone on maia

Run these in a terminal on the current computer, then in the SSH session:

```sh
ssh maia
mkdir -p ~/dev
git clone --branch codex/fitting-artwork https://github.com/m-housh/swift-duct-calc.git ~/dev/swift-duct-calc
cd ~/dev/swift-duct-calc
git status --short --branch
```

If a clone already exists elsewhere, fetch the branch there instead of cloning over it.
The source PDF, selected images, SVGs, reference crops, review batches, and QA records are committed.
Earlier untracked experiments remain in the original local checkout and are not required by the current review.
Local secrets, dependencies, browser storage, and generated-image cache directories are not transferred by Git.

## Continue in a fresh task on maia

The attempted cross-host handoff of “Recreate duct fitting drawings” failed with:
“Paginated chats cannot be continued on another host yet.” The existing conversation
remains local. Do not keep retrying handoff or modify chat databases to work around it.

Maia already has the project at `/home/michael/dev/swift-duct-calc`, checked out on
`codex/fitting-artwork` at `a1124a04388dd7cda40b777c08a9bcaf0df948ea`.
The branch is pushed to GitHub. Git and Python 3 are available on maia.

Start a fresh task in the saved `swift-duct-calc` project on `maia`, using the existing
checkout or starting a new worktree from `codex/fitting-artwork`. Read this guide
from `/home/michael/dev/swift-duct-calc/docs/fitting-artwork-handoff.md` for context.
This guide is tracked alongside the accepted Group 3 artwork and review records.

The fresh task should verify its host, directory, and Git branch, then serve the
active review without regenerating images. If the task starts
from another Git state, inspect it and preserve existing work before arranging a
checkout/worktree based on `codex/fitting-artwork`.

The previous conversation is preserved locally for reference. This guide and the
committed review/QA records carry forward the working decisions; they are not a full
conversation transcript. Project credentials, tools, plugins, and skills come from
the remote host. Original spreadsheet input `/home/michael/Downloads/manuald 080217.xls`
and old untracked experiments remain on the original local computer; request/copy
them only if actually needed. The active review assets are fully in Git.

## Open the review from maia

In the actual remote checkout/worktree that Codex is using:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory Public
```

In a separate terminal on the current computer:

```sh
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:8766:127.0.0.1:8765 maia
```

Open `http://127.0.0.1:8766/fitting-review/` locally. Port 8766 avoids the existing local review on 8765. Leave both commands running while reviewing. The review itself only needs Python 3; it does not require building the Swift app. Packaging artwork additionally needs Pillow.

## Current artwork state and preferences

- Group 1 is accepted. Group 2 is paused at the user's request.
- Group 4 is accepted, including the corrected 4AG arrow.
- **Group 3 is accepted**, including all 32 individual fitting IDs and previously accepted full references. Final acceptance recorded at 2026-09-05T01:27:19.824Z in `docs/fitting-reviews/review-e8adf2d2fbd5cd6c.json` from explicit chat approval: “Okay, I think everything is good with group 3.” The review now preserves approval of every current image revision. Earlier decisions/corrections below are history.
- Earlier Group 3 review: `docs/fitting-reviews/review-406a877467ebf0e6.json` (2026-09-05T00:13:36.619Z). All 32 revisions matched on import. Accepted: 3A, 3E, 3I, 3L, 3N, 3R, all 3S variants, 3T, both 3U variants, 3V and 3W (14 IDs). The other 18 IDs need corrections and re-review.
- Completed correction request: remove inset rectangular opening outlines that imply material thickness; retain single boundary lines. Latest 3D clarification supersedes the earlier movement interpretation: move ONLY the two-segment transverse main-duct joint (top diagonal plus front vertical) upstream to the red-dotted position in `3d_2.png`. Keep the elbow and its connection in place. Apply to all three 3D variants.
- Additional 3D clarification in `3d_3.png`: upstream duct must be wider/larger. Extend the far/back edge of the upstream duct outward, then taper down on that side toward the takeoff. Preserve the moved joint's near/front position, downstream duct size and elbow position. The red outline indicates the desired upstream width and reducing shoulder.
- These corrections are now active: `docs/fitting-preflight/group-3-edge-corrections.json` covers 19 revised fitting IDs (13 unique images), including `3D-full-straight-connection-v7.png` shared by all three 3D variants. It includes the relocated joint, wider upstream duct, and straight connecting edge from the upstream far-side joint to the elbow requested in `3d_4.png` and clarified afterward, above the retained straight reducing edge. All revisions have been visually inspected; all 32 current IDs are now accepted.
- Latest 3D clarification: the added line is straight, not curved; downstream width = upstream width minus fitting width. Bowed v6 is superseded by straight v7.
- 3Q correction is active as `3Q-clean-upstream-v6.png`: upstream widened on the near/front side; round takeoff emerges within the sloping reducing wall leading into the smaller downstream duct, repositioned toward the center per `3q_2.png`; the extra diagonal seam in the upstream top face was then removed per follow-up feedback. Visually inspected and now accepted.
- 3L reopened by user markup `3l.png`: downstream far/back boundary moved inward to narrow the downstream duct. Active `3L-narrow-downstream-v3.png` is visually inspected and now accepted; archived acceptance remains attached only to the previous revision.
- 3O v4 was rejected: removing the original triangular tapers into the round collar was wrong, and the reducer was too long. Active candidate `3O-short-faceted-reducer-v5.png` restores faceted taper panels and confines reduction to one short fitting bay before two straight downstream bays. Compared with source and pre-edit artwork; now accepted. Preserve these original transition details in future edits.
- Earlier Group 5 individual batch: 15 distinct entries 5A–5O. User rejected repeated full-assembly restorations as individual fitting drawings. 5A–5G are now separated, retaining both source views for the selected connection only, plus plenum/equipment context. 5H–5O already depict single fittings and retain their original views. Full Group 5 restorations remain untouched and linked from every card. This earlier batch is superseded by the accepted shape review. QA: `docs/fitting-preflight/group-5-individual.json`; manifest: `Public/images/fittings/group-5-individual/manifest.json`.
- **Group 5 by duct shape is accepted**, 16 artwork variants in 12 families. User requested round/rectangular artwork selection for the future picker. Current grouping: 5A/5B → family 5A, 5C/5D → family 5C, 5F/5G → family 5F; 5E has both shapes with a new rectangular adaptation. 5H–5O remain rectangular-only pending direction about round adaptations. Naming and coverage were presented as assumptions while clarification questions were pending; revise them if the user directs otherwise. Source IDs and values remain intact. See `docs/fitting-shape-artwork.md` and `docs/fitting-preflight/group-5-shape-variants.json`.
- Rebuild/activate the shape review with `python3 scripts/package_group_5_shapes.py --activate`. Use the same review URL. Other group packagers change the active batch, so run them only when intended.
- After Group 5: Group 6 (16 entries) and Group 7 (5) have prepared restorations, not accepted individual drawings. Inspect and separate shared assemblies before presenting each group. Keep Group 2 paused. Preserve connecting duct context, reducing sections and original fitting details.
- Retain the original standalone drawings. Updated user clarification (2026-09-04): separated assembly fittings must show the full original main-duct cross-section and substantial upstream/downstream sections, preserving original direction and taper. The user confirmed the expanded `3C-context-v2.png` example as the amount to use throughout. Do not append new upstream geometry to standalone originals.
- Preserve the accepted full illustrations for reference. Each individual review card links to its full reference.
- Review one group at a time. The user can give feedback in chat; do not require downloading review files.
- Visually inspect every changed drawing against its source before presenting it. Expanded-context revisions and prompts are recorded in `docs/fitting-preflight/group-3-expanded-context.json`. The earlier `group-3-individual-final.json` and linked JPGs document the superseded small-context drawings.
- The accepted workflow uses high-resolution raster restorations embedded in self-contained SVGs. These are not path-based vector drawings. Some corner/vane variants share generic artwork while retaining distinct IDs and values.
- Expanded-context revisions replace 3B's cutaway wall strips and the small schematic fragments on 3D and 3H with full-width main-duct sections. Revised drawings remain review candidates; confirmation of the 3C context amount does not imply acceptance of the whole batch.

The active review data is checked in with the artwork; no regeneration is needed to view it.
To rebuild Group 3 after intentionally editing artwork/QA records:

```sh
python3 scripts/package_group_3_individual.py --activate
```

The packager now imports archived Group 3 decisions only when the fitting ID and SVG/reference revision match exactly. Accepted drawings retain their approval and badge. Changed revisions return to pending review; do not infer acceptance from unchecked boxes during an unfinished review.

For a new remote conversation if handoff is unavailable, use:

> Read docs/fitting-artwork-handoff.md and the Group 3 individual manifest and final QA record. Continue the existing fitting artwork workflow on codex/fitting-artwork. Group 3 individual drawings are accepted; Group 5 shape variants are accepted; continue with Group 6. Keep Group 2 paused and preserve accepted standalone and full reference artwork.

Latest Group 5 correction: 5C rectangular side view has a straight top edge and short bottom-only taper, matching the source. Active override `5C-rectangular-prominent-taper-v3.png` deepens the side-view bottom taper per `5c.png` while preserving the perspective flare. Round 5C is unchanged.

Latest Group 5 correction: 5F round (source 5G) now uses `5F-round-equipment-top-v2.png`. User top view clarifies smaller plenum centered on a larger equipment footprint. Removed the projecting band, widened the cabinet/top and retained round inlet/arrow in both views. Other variants are unchanged.

Group 5 final acceptance: user approved all 16 shape variants in conversation on 2026-09-05. Exact current SVG/reference revisions are archived in the Group 5 shapes review record; rebuilding retains approval. Group 6 is next: all 16 source/restoration pairs were inspected and already depict individual fittings. No assembly separation is needed.

Active review is now Group 6 (6A–6P), all pending user review. Group 5 acceptance and artwork committed as `4f202b7`. Activate Group 6 with `python3 scripts/package_restored_fittings.py --group 6 --activate`. Its existing drawings already show separate fittings; source/restoration comparison sheets `docs/fitting-preflight/group-6-final-qa-{1,2,3}.png` were inspected before activation. Group 6 includes rectangular and round connections as depicted in its source; 6N currently shows the round outlet of the source’s round-or-square option.

Group 6 correction: 6F uses `6F-restored-edges-v2.png`, restoring the short vertical step seam and outgoing near top edge from source/user markup `6f.png`. The earlier cleanup incorrectly removed those lines. Compared with the original; pending user review. Prompts and selection are recorded in `docs/fitting-preflight/group-6-enhanced-agent.json`.

Group 6 final acceptance: all 16 current fittings, including corrected 6F, approved in conversation. Exact SVG/reference revisions are archived in the Group 6 review record. Group 7 is next; 7A–7C currently repeat one assembly and must be separated before review. 7D and 7E already depict individual fittings.

Active review is now **Group 7 individual fittings (7A–7E)**, all pending user review. Group 6 acceptance committed as `2e2d93b`. New 7A–7C illustrations isolate the stud-space run, stud-to-joist turn, and straight single-joist run from the shared assembly. 7B second candidate removes an extra foreground passage and opens the outlet. 7D–7E use their existing standalone artwork. Full restorations and source images remain unchanged and linked from the review. QA/prompts: `docs/fitting-preflight/group-7-individual.json`. Rebuild with `python3 scripts/package_group_7_individual.py --activate`. Group 2 remains paused.

Latest Group 7 correction: 7B uses `7B-aligned-wall-v3.png`. Per user markup `7b.png`, the bottom single-joist passage moved into alignment with the vertical cavity between both wall studs; the lateral offset is removed. Compared visually with the markup and previous drawing; pending user review.

Latest 7B: user confirmed v3 alignment and requested emphasis on the transition. Active `7B-transition-arrow-v4.png` replaces both straight wall arrows with one prominent curved arrow at the wall-to-floor turn, retaining the floor arrow and aligned geometry. Visually checked; pending review.

Group 7 individual drawings are accepted: explicit user approval recorded against all five current revisions. User also requested full 7A–7C assembly alternatives with colored bold arrows emphasizing each fitting. Active review is now `group-7-options`: five accepted individual images plus three new pending assembly variants. Blue arrows emphasize 7A downward wall flow, 7B curved wall-to-floor turn, and 7C joist-bay flow. Original individual and full reference files are unchanged. Rebuild with `python3 scripts/package_group_7_options.py --activate`. Picker lookup: `Public/images/fittings/group-7-options/manifest.json`, `families[].artworkByView.individual` or `.assembly`; each option retains the fitting ID and source calculation metadata. Prompts and visual QA: `docs/fitting-preflight/group-7-assemblies.json`. No commit requested yet for these Group 7 additions.

Latest Group 7: user accepted the three assembly options and requested an additional `7C-assembly-merging` case. Active review has nine images: eight approved unchanged options and one pending merging variant. It highlights the upstream return approach, curved merge at the source 40 ft callout, and combined downstream flow. Metadata preserves the original airflow table and carries `equivalentLengthAdjustment: {operation: add, feet: 40}` from the source merging-flow value, applicable when upstream return flow merges. This is artwork/selection metadata; no calculator implementation changed. Picker key: `families[7C].artworkByView["assembly-merging"]`. Existing 7C assembly stays available.

Latest 7C assembly-merging correction: user markup `7c.png` requests quieter floor-joist arrows. Active `7C-assembly-merging-muted-joists-v2.png` makes those five arrows small black while retaining bold blue upstream, merge and downstream arrows. The +40 ft condition is unchanged; other eight options remain approved and unchanged.

Group 7 final acceptance: user explicitly approved all nine current individual/assembly options after the muted merging-arrow correction. All exact revisions are archived in the final `group-7-options` review record; its manifest and review badges are approved. Group 7 is committed as `62599b7`; Group 8 is now active. The established workflow is to commit approved groups and advance automatically. Group 2 remains paused.

Workflow clarification: user expects group approval to include committing that group and opening the next review without a separate commit request. Preserve unrelated work when staging.
