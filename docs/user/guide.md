# Designing ducts with DuctCalc

Create an account and a project for the system you are designing. Work through
the project sections in order. The fitting reference and ductulator are also
available without an account.

## Project navigation

Press Ctrl+Alt+/ to reveal shortcut labels beside controls on the page. Press it
again or Escape to hide them. Labels follow you between pages in the same tab
and hide while an editor is open.

Press Ctrl+Alt+Shift+/ or open Keyboard shortcuts in the project navigation
for the full list, with the current page first. Close the dialog with Close or Escape.

Open Account → Keybindings to customize a shortcut. Select its current keys,
press a new combination, then save your changes. Escape cancels recording.
Use Reset to restore one action or Reset all to restore the defaults. Actions
that work in the same context must use different combinations. Search is
customizable too. The shortcuts below describe the defaults.

Use Ctrl+Alt+1 through Ctrl+Alt+6 to open Project, Rooms, Equipment, T.E.L.,
Friction Rate, and Duct Sizes in sidebar order. In Rooms, Ctrl+Alt+J selects the
next visible row and Ctrl+Alt+K selects the previous one. Row navigation stops at
the first and last visible rows. Ctrl+K focuses search in Rooms and Duct Sizes.
Clicking a room row selects it; the pencil opens its editor.

Ctrl+Alt+Enter opens the next project step. Ctrl+Alt+Shift+Enter opens the
previous step. Both follow sidebar order and stop at either end.
Ctrl+Alt+A opens the current step's main action:

| Step | Action |
| --- | --- |
| Project | Project details |
| Rooms | Add room |
| Equipment | Edit all |
| Total effective length | Add path |
| Friction rate | Use template |
| Duct sizes | Add trunk |

Shortcuts work while a search box has focus. They pause in other form fields
or when a dialog is open, except for the guided path navigation described below.
Save your changes before switching sections.

Ctrl+Alt+D opens the ductulator in a new tab. Ctrl+Alt+F opens the fitting
reference in a new tab. These shortcuts work wherever the corresponding
navigation links appear, with the same field and dialog restrictions.

While signed in, Ctrl+Alt+P returns to Projects. Ctrl+Alt+U opens your Profile
in the current tab. These shortcuts also work from search boxes and pause in other fields and dialogs.

## Room loads

Open Rooms to enter each room's heating load, cooling load, and register count.
You can supply total cooling, sensible cooling, or both. Set the sensible heat
ratio, SHR, on Room Loads when a cooling value needs to be calculated from the
other value. Use airflow delegation when another room's ducts will serve a room's
load, and review the register counts before sizing.

### Import from CoolCalc

In Rooms, Ctrl+Alt+I opens Import loads.

To create a project from a report, choose Add Project and drop the report on
Import report, or browse for it. The import fills in the project name, US address,
SHR, and rooms. A missing ZIP code is requested before creation. Equipment and duct
design settings still need to be entered separately.

If a project with a matching name or street address and ZIP code exists, you can
cancel or create another project. Continuing creates a separate project; it does
not merge into the existing one. The new project needs its own name, so a numbered
name is suggested, which you can change.

To import into an existing project, open the upload form on Room Loads and drop the
report on it. This does not require a ZIP code in the report.
Use a text-based CoolCalc MJ8 report in Individual Room Analysis or Room Detail
format. Scanned, locked, and multiple-system reports are unsupported. Include all
room pages and keep the file within 10 MB and 200 pages.

The import uses room heating and total cooling loads, including their infiltration
allocation. It does not use system totals as room loads. New rooms start with one
register and no airflow delegation. Room Detail reports leave levels blank;
repeated room names across levels in Individual Room Analysis receive a level
suffix.

Sensible cooling is calculated using the project's SHR. An existing SHR is kept;
otherwise the report supplies it. Changing SHR later updates the calculated
sensible loads. This applies the same sensible/latent split to every imported room.

### Re-importing and CSV

Room Loads also accepts room-load CSV files through the same upload form. Use this
column order, with loads in BTU/h and empty fields for optional values:

```csv
Name,Level,Heating Load,Cooling Total,Cooling Sensible,Register Count,Delegated To
Bedroom,2,3500,2000,,2,
Kitchen,1,4000,2500,,2,
```

Supply at least one cooling value. Delegated To, when used, names the room that
will receive the airflow. Keep names free of commas.

When a project already has rooms, the upload form explains how the chosen file will
update them before you import. Importing updates matching room names and adds new rooms.
Matching ignores case and surrounding spaces. Rooms missing from the file are kept; renaming
a room can cause a later import to add another room with the original name.

PDF imports keep existing register counts and airflow delegation. CSV imports
apply the values in the file. Both preserve existing trunk assignments for
matched rooms. Invalid or incomplete imports leave the project unchanged.

## Equipment and friction rate

Select the heating card, cooling card, or air handler under Equipment to enter its
value. You can save either airflow first; both are required before equipment is
complete and duct sizing or PDF export is available. Use Edit all or Ctrl+Alt+A to enter
all three values together. Ctrl+Alt+H opens heating, Ctrl+Alt+C opens cooling,
and Ctrl+Alt+S opens static pressure.

Add supply and return paths under T.E.L., the Equivalent Lengths page.
Then open Friction Rate to enter component pressure losses and review the resulting
design friction rate. If the rate is invalid, resolve the warning beside the summary
before sizing ducts. When losses meet or exceed blower static, review those inputs;
there is no positive pressure left for the duct calculation. Applying one loss keeps
any unsaved values in other rows so you can apply them separately.

New projects start with no component losses. On Friction Rate, choose a template
or start from scratch. Shared defaults includes the supply outlet, return grille,
and balancing damper. The furnace template also includes an evaporator coil.
Templates do not include a filter loss. After applying the furnace or air handler
template, choose a filter or skip that step. Applying a template replaces all
current component losses. Edit the values afterward to match your equipment.
With the template chooser open, Ctrl+Alt+D applies Shared defaults, Ctrl+Alt+F
applies Furnace + evaporator coil, and Ctrl+Alt+A applies Air handler.

Look up filter uses your account's filter library at the larger heating or cooling
airflow. Enter airflow under Equipment first. Values between chart points are
interpolated and rounded up to 0.01 in. w.c. Values outside the chart extend its end
segments; Over max CFM marks airflow above the filter's recommended maximum.

If the equipment rating already includes a filter loss, enter that allowance in
Filter loss included in equipment rating. Only the chart drop above the allowance
is added. If the allowance covers the whole loss, the filter stays in the component
list at 0.00, marked "Accounted for". The allowance is saved with the
project when you choose a filter. A saved component is a copy, so look up the filter
again after changing equipment airflow or the allowance.

### Your filter library

Open Account > Filter library to add, edit, duplicate, or delete filters. Each
account starts with Aprilaire and Dust Free Sixteen charts. Add a filter from any
manufacturer using at least two airflow and pressure drop points. For evenly spaced chart columns,
Fill from a chart row accepts the pressure drops in order. The highest chart
airflow is treated as the filter's maximum recommended airflow.

Star the filters you use, then open Design preferences to order your favorites
and save an optional maximum pressure drop. Each favorite can also have a Suggest
below cutoff. A cutoff of 1200 CFM skips that favorite at 1200 CFM and above;
leave it blank for no additional cutoff. DuctCalc suggests the first favorite
below its cutoff and within both the pressure limit and its maximum airflow.
The pressure limit uses the full chart drop, before any equipment allowance.
Try your preferences checks an example airflow and explains skipped favorites
without changing a project. You can still choose any filter in the picker.

Library changes affect future lookups. They do not change filter losses already
saved in projects. Restore default filters lets you add built-in charts missing
from your library or reset edited entries; custom filters are kept. If you already
have a saved library, use this to add the Dust Free Sixteen 3-ton and 5-ton filters.

## Equivalent-length paths

On Equivalent Lengths, use Ctrl+Alt+R to add a return path or Ctrl+Alt+S to add
a supply path from the visual network. Ctrl+Alt+A opens Add path beside the table.

Add a path, choose supply or return, and enter its name and
straight duct lengths. Use Add fitting to select the fittings along that path
and supply any required dimensions or other inputs. Quantity counts complete
fittings or illustrated assemblies. For Group 6 junctions, select the branch or
trunk contribution appropriate to the path being entered.

Use quick reference entry when supplying a fitting code and an equivalent length
from your own reference. Enter length per fitting; quantity is applied separately.
The supplied length is retained.

For multiple reference entries, choose **Import CSV** in the path editor. Paste
CSV or load a UTF-8 CSV file, then preview the rows before adding them. Use
`code,length_ft` headers with an optional `quantity` column:

```csv
code,length_ft,quantity
1A,35,
4AG,30.5,2
```

Lengths are feet per fitting, with a decimal point for fractional feet. Omitted
or empty quantities mean 1. The example illustrates syntax, not a recommended
path. Codes are case-insensitive; recognized variant IDs such as `8A-smooth`
become family reference codes such as `8A`. Use the fitting picker for Group 11.

Correct any reported errors in the CSV and preview again. Imports append to the
unsaved path; repeated entries are kept, and the editor groups rows by fitting
group while retaining their order within each group. Review repeated-use warnings
and choose **Save path** to keep the changes. Cancelling an import leaves the path
intact. Files are limited to 64 KiB, with at most 500 rows in the combined path.

Round and rectangular preferences change fitting order without hiding choices.
Favorites belong to your account and are available across projects, but do not
store custom fitting inputs. Save the path to include it in the design.

Reopening a saved path preserves its recorded fitting lengths. Renaming it or
changing quantities does not update those lengths to newer catalog values.
Explicitly editing a calculated fitting evaluates its inputs again. If another
edit has already been saved, resolve the stale-save message before continuing.

To reuse a path in the same project, choose Duplicate in its table row. The fitting
editor opens with its fittings and straight lengths copied and the name empty.
Enter a new name and make any changes before saving. Cancel discards the draft;
saving creates a separate path and leaves the original unchanged.

## Path templates

Choose From template while adding an equivalent-length path to follow a guided
sequence of fittings. Each account starts with editable Default supply and Default
return templates. Customize or rename these for your usual designs, or add more.
Deleted templates are not automatically replaced. The path name and straight duct
lengths carry into the guided flow. Back to path restores the original path form.

Press Enter to continue a section or save from Review path, and Shift+Enter to
go back. A focused button keeps its usual Enter action. Your next-step,
previous-step, and current-step-action shortcuts also work in the guided flow,
including while entering quantities. In fitting details, Enter applies the edit.
Use Ctrl+Alt+H/J/K/L to move left/down/up/right between fitting cards, then Enter
or Space to choose the focused fitting. Plain arrow keys also work. Up and Down
follow the displayed rows. From a section heading, any direction focuses the
first available fitting. Customize these shortcuts in Account > Keybindings >
Path templates. Tab still reaches reference details and the other controls.
Card navigation also works in Browse all fittings.

Manage templates through Account > Path templates or from a project. Configure
sections to choose one fitting, choose several, or enter quantities. Allow skipping
for optional sections. Each required section needs a supported fitting choice;
unavailable calculations cannot be used to save a path. Try lets you exercise the
template before using it in a design.

Saved paths open in the fitting editor with their name, type, straight lengths,
and fittings populated. Add, edit, or remove fittings there, whether the path was
created manually or from a template. Saved paths retain a copy of their original
template; changes to the path and template do not affect each other.

### Sharing templates

Export JSON downloads the current template configuration, including unsaved
changes, after validation. Exporting does not save those changes to your account.
The file contains fitting choices and defaults, without account or project data.

Choose Import JSON template in template management, select the file, and review it
before choosing Import as new template. Every import creates an independent copy;
a matching name does not replace an existing template. Files are limited to 1 MB.
Incompatible fittings or unsupported file versions must be resolved before import.

## Fitting reference

Open Fitting reference from the navigation to browse drawings, tables, and source
conditions. Filter by supply or return, choose a group, or search for a fitting.
Press Ctrl+K to focus the search field.
Check the illustrated arrangement and its conditions when choosing an entry.

Ctrl+Alt+1 through 9 open those group numbers; Ctrl+Alt+0 opens group 10.
Ctrl+Alt+N selects the next group; Ctrl+Alt+B selects the previous group.
These follow the group list, including All groups, within the current air path
filter. Ctrl+Alt+J selects the next fitting in the filtered list; Ctrl+Alt+K
selects the previous fitting. Navigation stops at either end and pauses while
editing a field other than search, or when a dialog is open. Open Keyboard shortcuts in the
navigation to see the bindings.

Sign in to inspect or download JSON and CSV for a fitting or filtered selection.
These export formats are experimental. Reference exports are separate from the
room-load importer and are not a fitting-path import format. A reference record's
presence does not mean every calculation it describes is available in the picker
or guided templates.

## Duct sizes and reports

Once room loads, equipment, paths, and component losses are complete, open Duct
Sizes to review room duct sizes. In Add trunk, choose a main supply or return
template to select all runs, or a level template to select that level's runs.
Level templates appear when rooms have levels assigned. Review the selected
runs, adjust the name if needed, and optionally enter a rectangular height before
saving. Templates add one trunk at a time and can be edited afterward. You can
also start with No template and select runs yourself. Choosing No template after
using a template clears the name and selected runs, keeping the type and height.

New trunks go at the end of their supply or return list. Drag a trunk by its
reorder handle to move it within that list. With the handle focused, use the Up
and Down arrow keys instead. The order saves automatically and carries through
to the PDF report.

Use Rectangular sizes to select registers and set a shared height or clear
their rectangular sizes. Clearing leaves unselected registers unchanged and does
not require a height. Use PDF or Ctrl+Alt+E on this page to open the design report in a new tab.
You can review it there, then download or print it from the browser's PDF viewer.

## Ductulator

Open Ductulator for a quick calculation outside a project. Enter CFM and friction
rate; optionally enter a height for a rectangular size. The result includes round,
flex, and any requested rectangular size, plus velocity. This calculation does
not save or change a project.

## Admin dashboard

Administrators can open Account > Admin or `/admin` to check registered accounts,
saved projects, signups, request volume, server errors, and average response time.
Instance owners grant access through the [self-hosting configuration](../self-hosting.md#admin-dashboard).

Account and project totals reflect records that exist now. Signup history starts
when collection is enabled and keeps its counts after accounts are deleted.
Requests include automated traffic and partial page updates, so they are not a
count of visitors. Visitor estimates remain in Cloudflare.

Activity updates about once a minute. Dates use UTC and today is incomplete.
A dash means no collection was recorded that day. Counts are approximate and may
have gaps during outages or restarts; check the last-saved time before interpreting
a quiet period. Historical activity is retained for 12 months.
