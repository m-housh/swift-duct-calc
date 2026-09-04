#!/usr/bin/env python3
"""Build a review batch from completed group-local manifests."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / 'Public'


def natural(value):
    return [int(part) if part.isdigit() else part for part in re.split(r'(\d+)', value)]


def reviewed_revisions():
    accepted = set()
    for path in (ROOT / 'docs/fitting-reviews').glob('*.json'):
        report = json.loads(path.read_text())
        for decision in report.get('drawings', []):
            if decision.get('status') == 'accepted':
                accepted.add((decision.get('id'), decision.get('revision')))
    return accepted


def item_revision(image, reference):
    image_path = PUBLIC / image.lstrip('/')
    reference_path = PUBLIC / reference.lstrip('/')
    return hashlib.sha256(image_path.read_bytes() + reference_path.read_bytes()).hexdigest()


def normalize(group, entry):
    if group == 3:
        key = entry['assetId']; image = entry['svg']; source = entry['source']
        reference = source['referenceImage']; pdf_page = source['referenceCropPdfPage']
        printed = source['printedPages'][-1]
    elif group == 4:
        key = entry['id']; image = entry['svg']; reference = entry['referenceImage']
        source = entry['source']; pdf_page = source['pdfPages'][0]; printed = source['printedPage']
    elif group == 5:
        key = entry['id']; image = entry['svgPath']; reference = entry['referenceImagePath']
        source = entry['source']; pdf_page = source['pdfPage']; printed = source['printedPage']
    else:
        # Newer isolated generators use the Group 4 field names.
        key = entry['id']; image = entry['svg']; reference = entry['referenceImage']
        source = entry['source']; pdf_page = source.get('pdfPage', source.get('pdfPages', [group])[0])
        printed = source.get('printedPage', source.get('printedPages', ['?'])[-1])
    rev = item_revision(image, reference)
    return dict(id=key, number=entry.get('fittingNumber', key), name=entry['name'], group=group,
                image='../' + image.lstrip('/'), reference='../' + reference.lstrip('/'),
                sourcePage=printed, sourcePDF=f'../files/ManD.Groups.pdf#page={pdf_page}',
                revision=rev)


def entries(manifest):
    return manifest.get('fittings') or manifest.get('items') or manifest.get('drawings') or []


def verify_preflight(groups, items):
    by_group = {group: {} for group in groups}
    for item in items:
        by_group[item['group']][item['id']] = item['revision']
    for group in groups:
        path = ROOT / f'docs/fitting-preflight/group-{group}.json'
        if not path.is_file():
            raise ValueError(f'Group {group} has no visual preflight record; batch was not activated.')
        record = json.loads(path.read_text())
        if record.get('status') != 'passed' or record.get('revisions') != by_group[group]:
            raise ValueError(f'Group {group} visual preflight does not match current revisions; batch was not activated.')


def main(groups, activate=False):
    accepted = reviewed_revisions(); items = []
    for group in groups:
        path = PUBLIC / f'images/fittings/group-{group}/manifest.json'
        manifest = json.loads(path.read_text())
        if manifest.get('group') != group:
            raise ValueError(f'{path} is not a Group {group} manifest')
        for entry in entries(manifest):
            item = normalize(group, entry)
            item['priorApproval'] = (item['id'], item['revision']) in accepted
            items.append(item)
    items.sort(key=lambda item: (item['group'], natural(item['id'])))
    suffix = '-'.join(map(str, groups)); batch_id = f'groups-{suffix}'
    title = f"Groups {', '.join(map(str, groups))} · {len(items)} drawings"
    batch = dict(id=batch_id, title=title,
                 description='Large-batch review of completed group-local drawings. Check only drawings that need more work; accepted decisions are tied to the exact SVG and reference revisions.',
                 items=items)
    folder = PUBLIC / 'fitting-review/batches'; folder.mkdir(exist_ok=True)
    (folder / f'{batch_id}.json').write_text(json.dumps(batch, indent=2) + '\n')
    if activate:
        verify_preflight(groups, items)
        (PUBLIC / 'fitting-review/data.js').write_text('window.FITTING_REVIEW = ' + json.dumps(batch, indent=2) + ';\n')
    print(f"Generated {batch_id}: {len(items)} drawings{' and activated it' if activate else '; not activated'}.")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('groups', type=int, nargs='+')
    parser.add_argument('--activate', action='store_true')
    args = parser.parse_args()
    main(args.groups, args.activate)
