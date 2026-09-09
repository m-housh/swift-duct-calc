#!/usr/bin/env python3
"""Package individually reviewed Group 2 source restorations and picker variants."""
import argparse
import hashlib
import json

from PIL import Image
from package_group_5_individual import ROOT, PUBLIC, art_svg, write_json


def package(activate=False):
    out = PUBLIC / 'images/fittings/group-2-restored'
    source = json.loads((out / 'source-metadata.json').read_text())
    qa_path = ROOT / 'docs/fitting-preflight/group-2-restored.json'
    qa = json.loads(qa_path.read_text())
    checks = {item['id']: item for item in qa['items']}
    expected = {item['id'] for item in source['items']}
    if set(checks) != expected or len(checks) != len(qa['items']):
        raise ValueError('QA must cover every source variant exactly once.')
    reports = []
    for path in (ROOT / 'docs/fitting-reviews').glob('*.json'):
        report = json.loads(path.read_text())
        if report.get('batchId') == 'group-2-restored' and report.get('completedAt'):
            reports.append((report, path))
    decisions = {}
    for report, path in sorted(reports, key=lambda pair: pair[0]['completedAt']):
        for decision in report['drawings']:
            decisions[(decision['id'], decision['revision'])] = {
                **decision, 'completedAt': report['completedAt'], 'record': str(path.relative_to(ROOT))}
    items, cards, families = [], [], {}
    for original in source['items']:
        item_id = original['id']
        check = checks[item_id]
        if check['status'] != 'ready-for-review' or not check['visualReview']['checked']:
            raise ValueError(f'{item_id} must pass visual inspection.')
        art = PUBLIC / check['restoredArt'].lstrip('/')
        svg = out / (item_id + '.svg')
        note = check['reviewNote']
        svg.write_text(art_svg(art, item_id + ' — ' + original['name'], note))
        reference = PUBLIC / original['referenceImage'].lstrip('/')
        revision = hashlib.sha256(svg.read_bytes() + reference.read_bytes()).hexdigest()
        decision = decisions.get((item_id, revision))
        accepted = bool(decision and decision['status'] == 'accepted')
        item = dict(original, svg='/' + str(svg.relative_to(PUBLIC)),
                    restoredArt=check['restoredArt'], revision=revision,
                    qaRecord=str(qa_path.relative_to(ROOT)),
                    status='visually-approved' if accepted else 'needs-review',
                    drawingMethod='AI-assisted raster restoration embedded in self-contained SVG.')
        with Image.open(art) as image:
            item['embeddedRasterSize'] = list(image.size)
        if decision:
            item['visualReview'] = decision
            if decision['status'] == 'needs-work':
                item['status'] = 'needs-work'
        items.append(item)
        family = families.setdefault(item['fittingId'], {'id': item['fittingId'], 'artworkByVariant': {}})
        family['artworkByVariant'][item['variant'] or 'default'] = {
            'itemId': item_id, 'image': item['svg'], 'ductShape': item['ductShape']}
        family['artworkByShape'] = {item['ductShape']: {'itemId': item_id, 'image': item['svg']}}
        src = item['source']
        cards.append({'id': item_id, 'number': item_id, 'name': item['name'], 'group': 2,
                      'image': '..' + item['svg'] + '?revision=' + revision[:12],
                      'reference': '..' + item['referenceImage'], 'revision': revision,
                      'sourcePage': src['printedPage'], 'sourcePDF': f"..{src['pdf']}#page={src['pdfPage']}",
                      'contextURL': 'group-2-restored-references.html#page-' + str(src['printedPage']),
                      'notes': [note], 'reviewNote': note, 'priorApproval': accepted})
    write_json(out / 'manifest.json', {'schemaVersion': 1, 'group': 2, 'title': source['title'],
        'drawingCount': len(items), 'familyCount': len(families), 'families': list(families.values()),
        'status': 'visually-approved' if all(i['status'] == 'visually-approved' for i in items) else 'needs-review',
        'items': items})
    batch = {'id': 'group-2-restored', 'title': 'Group 2 · branch takeoffs · renewed review',
             'description': 'Fresh individual restorations 2A–2Q with full main-trunk context. '
                            'Original entry details retained; full source tables remain linked.',
             'referenceGallery': 'group-2-restored-references.html', 'items': cards}
    write_json(PUBLIC / 'fitting-review/batches/group-2-restored.json', batch)
    gallery = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Group 2 original references</title><link rel="stylesheet" href="review.css">
<style>article{padding:24px}img{display:block;max-width:100%;height:auto;margin:auto}</style>
<header><a href="./">Back to fitting review</a><h1>Group 2 original references</h1></header><main>'''
    for page in source['sourcePages']:
        gallery += f'<article id="page-{page}"><h2>Source page {page}</h2><img src="../images/fittings/group-2-restored/source-art/page-{page}.png" alt="Original Group 2 drawings and tables, page {page}"></article>'
    (PUBLIC / 'fitting-review/group-2-restored-references.html').write_text(gallery + '</main></html>\n')
    if activate:
        (PUBLIC / 'fitting-review/data.js').write_text('window.FITTING_REVIEW = ' + json.dumps(batch, indent=2) + ';\n')
    print(f'Group 2: {len(items)} drawings in {len(families)} families; activated={activate}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--activate', action='store_true')
    package(parser.parse_args().activate)
