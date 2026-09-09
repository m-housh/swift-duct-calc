#!/usr/bin/env python3
"""Package source-supported Group 5 artwork by fitting family and return-duct shape."""
import argparse
import hashlib
import json

from PIL import Image
from package_group_5_individual import ROOT, PUBLIC, art_svg, write_json

OUT = PUBLIC / 'images/fittings/group-5-shapes'
QA = ROOT / 'docs/fitting-preflight/group-5-shape-variants.json'


def package(activate=False):
    individual = json.loads((PUBLIC / 'images/fittings/group-5-individual/manifest.json').read_text())
    sources = {item['id']: item for item in individual['items']}
    config = json.loads(QA.read_text())
    overrides = {item['id']: item for item in config['items']}
    reports = []
    for path in (ROOT / 'docs/fitting-reviews').glob('*.json'):
        report = json.loads(path.read_text())
        if report.get('batchId') == 'group-5-shapes' and report.get('completedAt'):
            reports.append((report, path))
    decisions = {}
    for report, path in sorted(reports, key=lambda pair: pair[0]['completedAt']):
        for decision in report['drawings']:
            decisions[(decision['id'], decision['revision'])] = {
                **decision, 'completedAt': report['completedAt'], 'record': str(path.relative_to(ROOT))}
    OUT.mkdir(exist_ok=True)
    items, cards, families, aliases = [], [], [], {}
    for family in config['families']:
        family_id = family['id']
        if family_id in {f['id'] for f in families}:
            raise ValueError(f'Duplicate family {family_id}')
        lookup = {}
        for alias in family['sourceIds']:
            if alias not in sources or alias in aliases:
                raise ValueError(f'Invalid or duplicate source alias {alias}')
            aliases[alias] = family_id
        for shape, variant in family['variants'].items():
            if shape not in {'rectangular', 'round'}:
                raise ValueError(f'Unsupported duct shape {shape}')
            source_id = variant['sourceFittingId']
            if source_id not in family['sourceIds']:
                raise ValueError(f'{source_id} is outside family {family_id}')
            source = sources[source_id]
            override = overrides.get(variant.get('artworkOverrideId'))
            if 'artworkOverrideId' in variant and not override:
                raise ValueError(f'Missing artwork override for {family_id}/{shape}')
            if override and override['status'] != 'ready-for-review':
                raise ValueError(f'Artwork has not been inspected: {override["id"]}')
            item = dict(source)
            item_id = family_id + '-' + shape
            item.update(id=item_id, familyId=family_id, fittingNumber=family_id,
                        name=family['name'], variant=shape, ductShape=shape,
                        sourceFittingId=source_id, sourceFittingNumber=source['fittingNumber'],
                        sourceAliases=family['sourceIds'], sharedArtworkIds=[item_id],
                        restoredArt=override['restoredArt'] if override else source['restoredArt'],
                        artworkOrigin=override.get('artworkOrigin', 'shape-adaptation') if override else 'existing-individual',
                        qaRecord=str(QA.relative_to(ROOT)))
            note = f'{shape.capitalize()} return duct. Source fitting {source_id}.'
            if override:
                note += ' ' + override.get('reviewNote', 'The source explicitly allows square or round; rectangular artwork is adapted from the round drawing.')
            item['restorationNotes'] = [note]
            svg = OUT / (item_id + '.svg')
            art = PUBLIC / item['restoredArt'].lstrip('/')
            svg.write_text(art_svg(art, family_id + ' — ' + shape.capitalize() + ' — ' + family['name'], note))
            item['svg'] = '/' + str(svg.relative_to(PUBLIC))
            item['revision'] = hashlib.sha256(svg.read_bytes() +
                (PUBLIC / item['referenceImage'].lstrip('/')).read_bytes()).hexdigest()
            with Image.open(art) as image:
                item['embeddedRasterSize'] = list(image.size)
            decision = decisions.get((item_id, item['revision']))
            accepted = bool(decision and decision['status'] == 'accepted')
            item.pop('visualReview', None)
            item['status'] = 'visually-approved' if accepted else 'individual-needs-review'
            if decision:
                item['visualReview'] = decision
                if decision['status'] == 'needs-work':
                    item['status'] = 'needs-work'
            items.append(item)
            lookup[shape] = {'itemId': item_id, 'image': item['svg'], 'sourceFittingId': source_id}
            src = item['source']
            cards.append({'id': item_id, 'number': family_id + ' · ' + shape.capitalize(),
                'name': family['name'], 'group': 5, 'familyId': family_id, 'ductShape': shape,
                'sourceFittingId': source_id, 'image': '..' + item['svg'] + '?revision=' + item['revision'][:12],
                'reference': '..' + item['referenceImage'], 'revision': item['revision'],
                'sourcePage': src['printedPage'], 'sourcePDF': f"..{src['pdf']}#page={src['pdfPage']}",
                'contextURL': 'group-5-references.html#' + source['contextId'],
                'notes': [note], 'reviewNote': note, 'priorApproval': accepted})
        families.append({'id': family_id, 'name': family['name'], 'sourceIds': family['sourceIds'],
                         'artworkByShape': lookup})
    if set(aliases) != set(sources):
        raise ValueError('Shape families must preserve every original source fitting ID.')
    write_json(OUT / 'manifest.json', {'schemaVersion': 1, 'group': 5,
        'title': 'Group 5 fittings by return-duct shape', 'drawingCount': len(items),
        'familyCount': len(families), 'status': 'visually-approved' if all(
            item['status'] == 'visually-approved' for item in items) else 'individual-needs-review',
        'sourceIdToFamilyId': aliases, 'families': families, 'items': items})
    batch = {'id': 'group-5-shapes', 'title': 'Group 5 · round and rectangular fittings',
        'description': 'Choose artwork by fitting family and return-duct shape. Paired source IDs '
        '(5A/5B, 5C/5D, 5F/5G) share a family; each variant retains its original source ID and values. '
        '5H–5O currently have rectangular artwork only.',
        'referenceGallery': 'group-5-references.html', 'items': cards}
    write_json(PUBLIC / 'fitting-review/batches/group-5-shapes.json', batch)
    if activate:
        (PUBLIC / 'fitting-review/data.js').write_text('window.FITTING_REVIEW = ' + json.dumps(batch, indent=2) + ';\n')
    print(f'Group 5 shapes: {len(families)} families, {len(items)} artwork variants; activated={activate}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--activate', action='store_true')
    package(parser.parse_args().activate)
