# Designing ducts with DuctCalc

Create an account and a project for the system you are designing. Work through
the project sections in order. The fitting reference and ductulator are also
available without an account.

## Room loads

Open Rooms to enter each room's heating load, cooling load, and register count.
You can supply total cooling, sensible cooling, or both. Set the sensible heat
ratio, SHR, on Room Loads when a cooling value needs to be calculated from the
other value. Use airflow delegation when another room's ducts will serve a room's
load, and review the register counts before sizing.

### Import from CoolCalc

To create a project from a report, choose Import from Cool Calc PDF when adding a
project. Upload the report and review any requested information before creating
it. The import fills in the project name, US address, SHR, and rooms. A missing
ZIP code is requested before creation. Equipment and duct design settings still
need to be entered separately.

If a project with a matching name or street address and ZIP code exists, you can
cancel or create another project. Continuing creates a separate project; it does
not merge into the existing one.

To import into an existing project, open the upload form on Room Loads and choose
Cool Calc PDF as the file type. This does not require a ZIP code in the report.
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

Room Loads also accepts room-load CSV files through the upload form. Use this
column order, with loads in BTU/h and empty fields for optional values:

```csv
Name,Level,Heating Load,Cooling Total,Cooling Sensible,Register Count,Delegated To
Bedroom,2,3500,2000,,2,
Kitchen,1,4000,2500,,2,
```

Supply at least one cooling value. Delegated To, when used, names the room that
will receive the airflow. Keep names free of commas.

Re-importing into a project with rooms asks for confirmation. Continuing updates
matching room names and adds new rooms. Matching ignores case and surrounding
spaces. Rooms missing from the file are kept; renaming a room can cause a later import to add
another room with the original name.

PDF imports keep existing register counts and airflow delegation. CSV imports
apply the values in the file. Both preserve existing trunk assignments for
matched rooms. Invalid or incomplete imports leave the project unchanged.

## Equipment and friction rate

Enter the equipment's static pressure and heating and cooling airflow under
Equipment. Add supply and return paths under T.E.L., the Equivalent Lengths page.
Then open Friction Rate to enter component pressure losses and review available
static pressure and the resulting design friction rate. Complete missing inputs
before moving on to duct sizing.

## Equivalent-length paths

Add a path on Equivalent Lengths, choose supply or return, and enter its name and
straight duct lengths. Use Add fitting to select the fittings along that path
and supply any required dimensions or other inputs. Quantity counts complete
fittings or illustrated assemblies. For Group 6 junctions, select the branch or
trunk contribution appropriate to the path being entered.

Use quick reference entry when supplying a fitting code and an equivalent length
from your own reference. Enter length per fitting; quantity is applied separately.
The supplied length is retained. Bulk fitting CSV import is not available.

Round and rectangular preferences change fitting order without hiding choices.
Favorites belong to your account and are available across projects, but do not
store custom fitting inputs. Save the path to include it in the design.

Reopening a saved path preserves its recorded fitting lengths. Renaming it or
changing quantities does not update those lengths to newer catalog values.
Explicitly editing a calculated fitting evaluates its inputs again. If another
edit has already been saved, resolve the stale-save message before continuing.

## Path templates

Choose From template while adding an equivalent-length path to follow a guided
sequence of fittings. Start with a supply or return starter template, or one of
your own templates. The path name and straight duct lengths carry into the guided
flow. Back to path restores the original path form.

Manage templates through Account > Path templates or from a project. Configure
sections to choose one fitting, choose several, or enter quantities. Allow skipping
for optional sections. Each required section needs a supported fitting choice;
unavailable calculations cannot be used to save a path. Try lets you exercise the
template before using it in a design.

Saved paths retain a copy of their template. Editing or deleting the template
does not change those paths.

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
Check the illustrated arrangement and its conditions when choosing an entry.

Sign in to inspect or download JSON and CSV for a fitting or filtered selection.
These export formats are experimental. Reference exports are separate from the
room-load importer and are not a fitting-path import format. A reference record's
presence does not mean every calculation it describes is available in the picker
or guided templates.

## Duct sizes and reports

Once room loads, equipment, paths, and component losses are complete, open Duct
Sizes to review room duct sizes. Add trunks or runouts and select the rooms they
serve. Use PDF on this page to download a report of the design.

## Ductulator

Open Ductulator for a quick calculation outside a project. Enter CFM and friction
rate; optionally enter a height for a rectangular size. The result includes round,
flex, and any requested rectangular size, plus velocity. This calculation does
not save or change a project.
