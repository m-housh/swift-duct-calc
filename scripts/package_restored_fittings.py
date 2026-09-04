#!/usr/bin/env python3
"""Package source-reviewed restorations for Groups 3, 5, 6 and 7."""
import argparse
import base64
import hashlib
import json
import textwrap
from pathlib import Path
from xml.sax.saxutils import escape

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / 'Public'


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n')


def source_metadata(group, out):
    path = out / 'source-metadata.json'
    if path.exists():
        return json.loads(path.read_text())
    legacy = json.loads((PUBLIC / f'images/fittings/group-{group}/manifest.json').read_text())
    entries = legacy.get('items', legacy.get('fittings', legacy.get('drawings', [])))
    items = []
    for entry in entries:
        source = entry.get('source', {})
        source_id = entry.get('assetId', entry.get('id'))
        reference = source.get('referenceImage') or entry.get('referenceImagePath') or entry.get('referenceImage')
        items.append({
            'id': source_id, 'fittingNumber': entry.get('fittingNumber', source_id),
            'name': entry['name'], 'variant': entry.get('variant'),
            'referenceEquivalentLengthFeet': entry.get('referenceEquivalentLengthFeet'),
            'referenceValues': entry.get('referenceValues', {}),
            'referenceConditions': entry.get('referenceConditions', legacy.get('referenceConditions', {})),
            'source': source, 'originalReferenceImage': reference,
            'notes': entry.get('notes', []),
        })
    data = {'group': group, 'title': legacy['title'], 'items': items,
            'source': legacy.get('source', {}), 'printedPages': legacy.get('printedPages', []),
            'referenceConditions': legacy.get('referenceConditions', {})}
    write_json(path, data)
    return data


def card(item, png, group, printed_page):
    encoded = base64.b64encode(png).decode('ascii')
    name = escape(item['name'])
    title = escape(item['id'])
    scalar = item.get('referenceEquivalentLengthFeet')
    if scalar is None:
        scalar = item.get('referenceValues', {}).get('equivalentLengthFeet')
    value = f'Reference equivalent length: {scalar} ft' if scalar is not None else 'Equivalent length varies with conditions; see the source table.'
    lines = textwrap.wrap(item['name'], width=59)
    names = ''.join(f'<text x="32" y="{84 + i*23}" font-size="19">{escape(line)}</text>' for i, line in enumerate(lines))
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="800" height="720" viewBox="0 0 800 720" role="img" aria-labelledby="title desc">
<title id="title">{title} — {name}</title>
<desc id="desc">Source-based high-resolution raster restoration in a self-contained SVG.</desc>
<style>text{{font-family:Arial,sans-serif;fill:#243b53}}</style>
<rect width="800" height="720" fill="white"/>
<text x="32" y="46" font-size="30" font-weight="700">{title}</text>
<text x="768" y="42" font-size="14" text-anchor="end">GROUP {group}</text>
{names}
<image href="data:image/png;base64,{encoded}" x="32" y="125" width="736" height="490" preserveAspectRatio="xMidYMid meet"/>
<text x="32" y="655" font-size="16">{escape(value)}</text>
<text x="32" y="686" font-size="12">SOURCE RESTORATION · PRINTED PAGE {printed_page}</text>
</svg>\n'''


def package(group, activate=False):
    out = PUBLIC / f'images/fittings/group-{group}-enhanced'
    out.mkdir(exist_ok=True)
    source = source_metadata(group, out)
    qa_path = ROOT / f'docs/fitting-preflight/group-{group}-enhanced-agent.json'
    qa = json.loads(qa_path.read_text())
    checks = {entry['id']: entry for entry in qa['items']}
    reports = []
    for path in (ROOT / 'docs/fitting-reviews').glob('*.json'):
        report = json.loads(path.read_text())
        if report.get('schemaVersion') == 1 and report.get('completedAt') and isinstance(report.get('drawings'), list):
            reports.append((report, path))
    items, batch_items = [], []
    for original in source['items']:
        fitting_id = original['id']
        check = checks.get(fitting_id)
        if not check or check['status'] != 'ready-for-review':
            continue
        item = dict(original)
        item.update({k: check[k] for k in ['restoredArt', 'referenceImage', 'sharedArtworkIds'] if k in check})
        item['restorationNotes'] = check.get('notes', [])
        png_path = PUBLIC / item['restoredArt'].lstrip('/')
        reference = PUBLIC / item['referenceImage'].lstrip('/')
        png = png_path.read_bytes()
        with Image.open(png_path) as im:
            im.verify()
            item['embeddedRasterSize'] = list(im.size)
        src = item['source']
        printed = src.get('printedPage') or (src.get('printedPages') or source.get('printedPages') or [None])[0]
        page = src.get('referenceCropPdfPage') or src.get('pdfPage') or (src.get('pdfPages') or [1])[0]
        svg = out / f'{fitting_id}.svg'
        svg.write_text(card(item, png, group, printed))
        revision = hashlib.sha256(svg.read_bytes() + reference.read_bytes()).hexdigest()
        item.update({'svg': '/' + str(svg.relative_to(PUBLIC)), 'revision': revision,
                     'status': 'restoration-needs-review', 'drawingMethod': 'AI-assisted raster restoration embedded in self-contained SVG.',
                     'qaRecord': str(qa_path.relative_to(ROOT))})
        for report, path in sorted(reports, key=lambda p: p[0]['completedAt']):
            for decision in report['drawings']:
                if decision.get('id') == fitting_id and decision.get('revision') == revision:
                    item['status'] = 'visually-approved' if decision['status'] == 'accepted' else 'needs-work'
                    item['visualReview'] = {'revision': revision, 'completedAt': report['completedAt'], 'batchId': report['batchId'],
                                            'note': decision['note'], 'record': str(path.relative_to(ROOT))}
        items.append(item)
        batch_items.append({'id': fitting_id, 'number': item['fittingNumber'], 'name': item['name'], 'group': group,
                            'image': '..' + item['svg'] + '?revision=' + revision[:12],
                            'reference': '..' + item['referenceImage'], 'sourcePage': printed,
                            'sourcePDF': f'../files/ManD.Groups.pdf#page={page}', 'revision': revision,
                            'priorApproval': item['status'] == 'visually-approved', 'notes': item['restorationNotes']})
    missing = [item['id'] for item in source['items'] if item['id'] not in {ready['id'] for ready in items}]
    manifest = {'schemaVersion': 1, 'group': group, 'title': source['title'], 'drawingCount': len(items),
                'expectedDrawingCount': len(source['items']), 'withheldIds': missing,
                'status': 'visually-approved' if not missing and all(i['status'] == 'visually-approved' for i in items) else 'restoration-needs-review',
                'referenceConditions': source['referenceConditions'], 'items': items}
    write_json(out / 'manifest.json', manifest)
    description = 'Compare the restored artwork with its original. Check only drawings that still need work.'
    if any(item.get('sharedArtworkIds') for item in items):
        description += ' Some fittings share an original assembly illustration; their individual IDs and values are retained.'
    if group == 3:
        description += ' The source does not separately illustrate every corner variant; shared artwork does not depict those differences.'
    if missing:
        description += ' Withheld pending corrections: ' + ', '.join(missing) + '.'
    batch = {'id': f'group-{group}-enhanced', 'title': f'Group {group} · high-resolution restorations',
             'description': description, 'items': batch_items}
    write_json(PUBLIC / f'fitting-review/batches/{batch["id"]}.json', batch)
    if activate:
        (PUBLIC / 'fitting-review/data.js').write_text('window.FITTING_REVIEW = ' + json.dumps(batch, indent=2) + ';\n')
    print(f'Group {group}: {len(items)} packaged, {len(missing)} withheld, activated={activate}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--group', type=int, choices=[3, 5, 6, 7], required=True)
    parser.add_argument('--activate', action='store_true')
    args = parser.parse_args()
    package(args.group, args.activate)
