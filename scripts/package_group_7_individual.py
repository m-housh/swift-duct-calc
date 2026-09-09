#!/usr/bin/env python3
"""Package individual Group 7 fittings while preserving the full source artwork."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
from xml.sax.saxutils import escape

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / 'Public'
OUT = PUBLIC / 'images/fittings/group-7-individual'
QA = ROOT / 'docs/fitting-preflight/group-7-individual.json'


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n')


def art_svg(path, title, description):
    with Image.open(path) as image:
        width, height = image.size
        image.verify()
    data = base64.b64encode(path.read_bytes()).decode('ascii')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
            f'width="{width}" height="{height}" role="img" aria-labelledby="title desc">\n'
            f'<title id="title">{escape(title)}</title><desc id="desc">{escape(description)}</desc>\n'
            f'<image width="{width}" height="{height}" href="data:image/png;base64,{data}"/>\n</svg>\n')


def package(activate=False):
    original = json.loads((PUBLIC / 'images/fittings/group-7-enhanced/manifest.json').read_text())
    qa = json.loads(QA.read_text())
    checks = {item['id']: item for item in qa['items']}
    expected = {item['id'] for item in original['items']}
    if len(checks) != len(qa['items']) or set(checks) != expected:
        raise ValueError('Individual Group 7 QA must cover every fitting exactly once.')
    if any(item['status'] != 'ready-for-review' for item in checks.values()):
        raise ValueError('Every individual drawing must pass visual inspection before packaging.')
    decisions = {}
    reports = []
    for path in (ROOT / 'docs/fitting-reviews').glob('*.json'):
        report = json.loads(path.read_text())
        if report.get('batchId') == 'group-7-individual' and report.get('completedAt'):
            reports.append((report, path))
    for report, path in sorted(reports, key=lambda pair: pair[0]['completedAt']):
        for decision in report['drawings']:
            decisions[(decision['id'], decision['revision'])] = {
                **decision, 'completedAt': report['completedAt'], 'record': str(path.relative_to(ROOT))}
    OUT.mkdir(exist_ok=True)
    items, cards, references = [], [], {}
    for source in original['items']:
        check = checks[source['id']]
        item = dict(source)
        item.update(restoredArt=check['restoredArt'], sharedArtworkIds=[source['id']],
                    restorationNotes=check['notes'], qaRecord=str(QA.relative_to(ROOT)),
                    unchangedStandalone=check.get('unchangedStandalone', False),
                    contextArt=source['restoredArt'], contextSVG=source['svg'])
        art = PUBLIC / item['restoredArt'].lstrip('/')
        svg = OUT / (item['id'] + '.svg')
        svg.write_text(art_svg(art, item['id'] + ' — ' + item['name'],
                              'Individual fitting. ' + ' '.join(check['notes'])))
        item['svg'] = '/' + str(svg.relative_to(PUBLIC))
        item['revision'] = hashlib.sha256(svg.read_bytes() +
            (PUBLIC / item['referenceImage'].lstrip('/')).read_bytes()).hexdigest()
        with Image.open(art) as image:
            item['embeddedRasterSize'] = list(image.size)
        decision = decisions.get((item['id'], item['revision']))
        accepted = bool(decision and decision['status'] == 'accepted')
        item['status'] = 'visually-approved' if accepted else 'individual-needs-review'
        item.pop('visualReview', None)
        if decision:
            item['visualReview'] = decision
            if decision['status'] == 'needs-work':
                item['status'] = 'needs-work'
        digest = hashlib.sha256((PUBLIC / source['restoredArt'].lstrip('/')).read_bytes()).hexdigest()
        ref = references.setdefault(digest, {'id': 'reference-' + item['id'],
            'ids': [], 'art': source['restoredArt'], 'svg': source['svg']})
        ref['ids'].append(item['id'])
        item['contextId'] = ref['id']
        items.append(item)
        src = source['source']
        cards.append({'id': item['id'], 'number': item['fittingNumber'], 'name': item['name'], 'group': 7,
            'image': '..' + item['svg'] + '?revision=' + item['revision'][:12],
            'reference': '..' + item['referenceImage'], 'sourcePage': src['printedPage'],
            'sourcePDF': f"..{src['pdf']}#page={(src.get('pdfPage') or src['pdfPages'][0])}", 'revision': item['revision'],
            'contextURL': 'group-7-references.html#' + ref['id'], 'notes': check['notes'],
            'reviewNote': ('Original standalone fitting views retained.' if item['unchangedStandalone'] else
                'Only this fitting connection is shown. Original stud/joist construction and connecting context retained.'),
            'priorApproval': accepted})
    accepted = all(item['status'] == 'visually-approved' for item in items)
    write_json(OUT / 'manifest.json', {'schemaVersion': 1, 'group': 7, 'title': 'Group 7 individual fittings',
        'status': 'visually-approved' if accepted else 'individual-needs-review',
        'drawingCount': len(items), 'expectedDrawingCount': len(expected), 'withheldIds': [],
        'referenceConditions': original['referenceConditions'], 'items': items})
    batch = {'id': 'group-7-individual', 'title': 'Group 7 · individual fittings',
        'description': 'Each entry shows its own fitting. 7A–7C are separated from their shared assembly; '
        '7D–7E retain their original standalone views. Full source illustrations remain available for comparison.',
        'referenceGallery': 'group-7-references.html', 'items': cards}
    write_json(PUBLIC / 'fitting-review/batches/group-7-individual.json', batch)
    gallery = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Group 7 full references</title>
<link rel="stylesheet" href="review.css"><style>article{padding:24px;scroll-margin-top:20px}img{display:block;width:100%;max-height:680px;object-fit:contain}</style>
<header><a href="./">Back to fitting review</a><h1>Group 7 full references</h1>
<p>Preserved full illustrations for comparison with the individual fittings.</p></header><main>'''
    for ref in references.values():
        gallery += (f'<article id="{ref["id"]}"><h2>{escape(", ".join(ref["ids"]))}</h2>'
            f'<a href="{ref["svg"]}" target="_blank" rel="noopener">Open full-size SVG</a>'
            f'<img src="{ref["art"]}" alt="Full reference for {escape(", ".join(ref["ids"]))}"></article>')
    (PUBLIC / 'fitting-review/group-7-references.html').write_text(gallery + '</main></html>\n')
    if activate:
        (PUBLIC / 'fitting-review/data.js').write_text('window.FITTING_REVIEW = ' + json.dumps(batch, indent=2) + ';\n')
    print(f'Group 7 individual: {len(items)} drawings, {len(references)} full references; activated={activate}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--activate', action='store_true')
    package(parser.parse_args().activate)
