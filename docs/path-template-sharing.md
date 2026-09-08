# Sharing path templates

The configurator's **Export JSON** button downloads the current configuration,
including unsaved changes, after checking its fittings and defaults. It does not
save those changes to the account.

Choose **Import JSON template** on the template list or in its plus-button modal.
Select a file, review its sections and defaults, optionally rename it, and choose
**Import as new template**. Previewing does not save anything. Every import creates
an independent template owned by the signed-in user, with fresh template,
revision, and section IDs. Matching names do not replace existing templates.

When template management is opened from a project, the `project` query parameter
preserves its Back link through creation, configuration, import, save, duplicate,
and delete. The server checks project ownership before rendering that context.
The parameter is never included in exported files.

## File format

The version 1 envelope contains only `format`, `version`, `name`, `type`, and
ordered `steps`. Sections contain `title`, `group`, `behavior`, `allowsSkipping`,
and `choices`. Choices use stable catalog fitting IDs and optional typed defaults.
There are no account details, project data, timestamps, or internal IDs.

```json
{
  "format": "duct-calc-path-template",
  "version": 1,
  "name": "Simple supply connection",
  "type": "supply",
  "steps": [
    {
      "title": "Equipment connection",
      "group": 1,
      "behavior": "chooseOne",
      "allowsSkipping": false,
      "choices": [{ "fittingID": "1B", "defaults": null }]
    }
  ]
}
```

Files are limited to 1 MB, with the existing configuration limits of 50 sections
and 100 distinct fitting choices per section. Unknown versions, malformed files,
missing or incompatible fitting IDs, and unsupported defaults block import.
Preview explicitly identifies fittings whose automatic calculation is unavailable;
they remain in the imported configuration. Nothing is silently dropped.

## Verification

Swift transfer tests cover both starter round trips, new section identities,
excluded metadata, unsupported versions, malformed input, and catalog validation.
`npm run test:path-templates` checks independent cross-account import, preview
errors, preserved defaults, project ownership/context, larger valid payloads,
and the upload limit against the isolated local development app.

Browser checks also cover actual JSON downloads, file selection, preview, the
header/plus modal, and project return navigation.
