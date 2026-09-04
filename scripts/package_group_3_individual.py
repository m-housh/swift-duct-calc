#!/usr/bin/env python3
"""Package individual Group 3 artwork and retain its accepted full references."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
from xml.sax.saxutils import escape

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / 'Public'
OUT = PUBLIC / 'images/fittings/group-3-individual'
CONTEXT = PUBLIC / 'images/fittings/group-3-context'


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
    OUT.mkdir(exist_ok=True)
    CONTEXT.mkdir(exist_ok=True)
    original = json.loads((PUBLIC / 'images/fittings/group-3-enhanced/manifest.json').read_text())
    checks = {}
    for suffix in ['b-h', 'j-n', 'o-r', 'standalone']:
        path = ROOT / f'docs/fitting-preflight/group-3-individual-{suffix}.json'
        for item in json.loads(path.read_text())['items']:
            if item['id'] in checks:
                raise ValueError(f'Duplicate QA entry: {item["id"]}')
            checks[item['id']] = dict(item, qaRecord=str(path.relative_to(ROOT)))
    assert set(checks) == {i['id'] for i in original['items']}, 'Incomplete QA coverage'

    # Deduplicate the full accepted images, while retaining every fitting's link.
    references = {}
    reference_for = {}
    for item in original['items']:
        path = PUBLIC / item['restoredArt'].lstrip('/')
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest not in references:
            ref_id = 'reference-' + item['id']
            references[digest] = {'id': ref_id, 'fittingIds': [], 'art': item['restoredArt'],
                                  'svg': f'/images/fittings/group-3-context/{ref_id}.svg',
                                  'artSHA256': digest, 'status': 'accepted-reference-artwork'}
        ref = references[digest]
        ref['fittingIds'].append(item['id'])
        reference_for[item['id']] = ref
    cards = []
    for ref in references.values():
        label = ', '.join(ref['fittingIds'])
        (PUBLIC / ref['svg'].lstrip('/')).write_text(art_svg(
            PUBLIC / ref['art'].lstrip('/'), label + ' — full reference',
            'Accepted full reference artwork, preserved unchanged. High-resolution raster in SVG.'))
        cards.append(f'<article id="{ref["id"]}"><h2>{escape(label)}</h2>'
                     f'<a href="{ref["svg"]}" target="_blank" rel="noopener">Open full-size SVG</a>'
                     f'<img src="{ref["art"]}" alt="Full reference for {escape(label)}"></article>')
    write_json(CONTEXT / 'manifest.json', {'schemaVersion': 1, 'group': 3, 'items': list(references.values())})
    gallery = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Group 3 full references</title>
<link rel="stylesheet" href="review.css"><style>article{padding:24px;scroll-margin-top:20px}article img{display:block;width:100%;max-height:680px;object-fit:contain}h2{margin-bottom:12px}</style>
<header><a href="./">Back to fitting review</a><h1>Group 3 · full references</h1>
<p>Accepted reference artwork retained alongside the individual fitting illustrations.</p></header>
<main>''' + '\n'.join(cards) + '</main></html>\n'
    (PUBLIC / 'fitting-review/group-3-references.html').write_text(gallery)

    items, batch_items, withheld = [], [], []
    for source in original['items']:
        check = checks[source['id']]
        if check['status'] != 'ready-for-review':
            withheld.append({'id': source['id'], 'notes': check['notes'], 'qaRecord': check['qaRecord']})
            continue
        item = {k: source[k] for k in ['id', 'fittingNumber', 'name', 'variant', 'referenceEquivalentLengthFeet',
                'referenceValues', 'referenceConditions', 'source', 'originalReferenceImage', 'notes'] if k in source}
        item.update({k: check[k] for k in ['restoredArt', 'referenceImage', 'sharedArtworkIds', 'qaRecord']})
        ref = reference_for[item['id']]
        item.update({'contextId': ref['id'], 'contextArt': ref['art'], 'contextSVG': ref['svg'],
                     'unchangedStandalone': check.get('unchangedStandalone', False),
                     'restorationNotes': check['notes'], 'status': 'individual-needs-review',
                     'drawingMethod': 'High-resolution raster artwork embedded in an art-only, self-contained SVG.'})
        path = PUBLIC / item['restoredArt'].lstrip('/')
        svg_path = OUT / (item['id'] + '.svg')
        svg_path.write_text(art_svg(path, item['id'] + ' — ' + item['name'],
                                    'Individual fitting. ' + ' '.join(check['notes']) + ' High-resolution raster in SVG.'))
        item['svg'] = '/' + str(svg_path.relative_to(PUBLIC))
        item['revision'] = hashlib.sha256(svg_path.read_bytes() + (PUBLIC / item['referenceImage'].lstrip('/')).read_bytes()).hexdigest()
        with Image.open(path) as image:
            item['embeddedRasterSize'] = list(image.size)
        # Acceptance of the full reference does not approve a new extraction.
        items.append(item)
        src = item['source']
        page = src.get('referenceCropPdfPage') or src.get('pdfPage') or (src.get('pdfPages') or [1])[0]
        review_note = 'Original standalone artwork preserved.' if item['unchangedStandalone'] else 'A short portion of the existing connection is retained.'
        if item['id'] == '3V':
            review_note = 'One transition from the original mirrored pair.'
        elif item['id'] == '3B':
            review_note = 'The connecting duct is shown as a cutaway with short wall strips.'
        elif item['id'].startswith('3D-') or item['id'] == '3H':
            review_note = 'The short connecting duct fragment is schematic.'
        if item.get('variant') and len(item.get('sharedArtworkIds', [])) > 1:
            review_note += ' Generic source artwork does not distinguish these corner or vane variants.'
        batch_items.append({'id': item['id'], 'number': item['fittingNumber'], 'name': item['name'], 'group': 3,
                            'image': '..' + item['svg'] + '?revision=' + item['revision'][:12],
                            'reference': '..' + item['referenceImage'], 'sourcePage': 167 if page >= 12 else 166,
                            'sourcePDF': f'../files/ManD.Groups.pdf#page={page}', 'revision': item['revision'],
                            'contextURL': 'group-3-references.html#' + ref['id'],
                            'notes': check['notes'], 'reviewNote': review_note, 'priorApproval': False})
    write_json(OUT / 'manifest.json', {'schemaVersion': 1, 'group': 3, 'title': 'Group 3 individual fittings',
               'status': 'individual-needs-review', 'drawingCount': len(items), 'expectedDrawingCount': len(original['items']),
               'withheldIds': [i['id'] for i in withheld], 'withheld': withheld,
               'upstreamContextRule': 'Keep a small piece of the existing connecting neighbor only when separating shared assembly artwork. Leave original standalone fittings unchanged.',
               'referenceManifest': '/images/fittings/group-3-context/manifest.json', 'items': items})
    description = ('Standalone drawings retain their original geometry. Fittings separated from shared assemblies retain a short piece of their existing connection. '
                   'Open the full reference from any card. Corner and vane variants still share generic source artwork; their differences are recorded in the fitting metadata.')
    if withheld:
        description += ' Still being corrected: ' + ', '.join(i['id'] for i in withheld) + '.'
    batch = {'id': 'group-3-individual', 'title': 'Group 3 · individual fittings', 'description': description,
             'referenceGallery': 'group-3-references.html', 'items': batch_items}
    write_json(PUBLIC / 'fitting-review/batches/group-3-individual.json', batch)
    if activate:
        (PUBLIC / 'fitting-review/data.js').write_text('window.FITTING_REVIEW = ' + json.dumps(batch, indent=2) + ';\n')
    print(f'Group 3 individual: {len(items)} ready, {len(withheld)} withheld, {len(references)} full references; activated={activate}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--activate', action='store_true')
    package(parser.parse_args().activate)
