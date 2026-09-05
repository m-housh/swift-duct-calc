#!/usr/bin/env python3
"""Package optional Group 7 assembly views alongside accepted individual artwork."""
import argparse
import hashlib
import json

from PIL import Image

from package_group_7_individual import package as package_individual
from package_group_5_individual import ROOT, PUBLIC, art_svg, write_json


def package(activate=False):
    package_individual()
    source = json.loads((PUBLIC / 'images/fittings/group-7-individual/manifest.json').read_text())
    individual_batch = json.loads((PUBLIC / 'fitting-review/batches/group-7-individual.json').read_text())
    config_path = ROOT / 'docs/fitting-preflight/group-7-assemblies.json'
    config = json.loads(config_path.read_text())
    checks = {(item['fittingId'], item.get('artworkView', 'assembly')): item for item in config['items']}
    required = {('7A', 'assembly'), ('7B', 'assembly'), ('7C', 'assembly')}
    allowed = required | {('7C', 'assembly-merging')}
    if not required <= set(checks) <= allowed or len(checks) != len(config['items']):
        raise ValueError('Assembly QA requires 7A–7C, with an optional distinct 7C merging view.')
    out = PUBLIC / 'images/fittings/group-7-options'
    out.mkdir(exist_ok=True)
    decisions = {}
    reports = []
    for path in (ROOT / 'docs/fitting-reviews').glob('*.json'):
        report = json.loads(path.read_text())
        if report.get('batchId') == 'group-7-options' and report.get('completedAt'):
            reports.append((report, path))
    for report, path in sorted(reports, key=lambda pair: pair[0]['completedAt']):
        for decision in report['drawings']:
            decisions[(decision['id'], decision['revision'])] = {
                **decision, 'completedAt': report['completedAt'], 'record': str(path.relative_to(ROOT))}
    items, cards, families = [], [], []
    original_cards = {item['id']: item for item in individual_batch['items']}
    for original in source['items']:
        fitting_id = original['id']
        individual = dict(original, fittingId=fitting_id, artworkView='individual')
        items.append(individual)
        cards.append(dict(original_cards[fitting_id]))
        views = {'individual': {'itemId': fitting_id, 'image': original['svg']}}
        for (check_id, view), check in checks.items():
            if check_id != fitting_id:
                continue
            if check['status'] != 'ready-for-review' or not check['visualReview']['checked']:
                raise ValueError(f'{fitting_id} assembly must be visually inspected first.')
            item_id = fitting_id + '-' + view
            view_label = 'Assembly · Merging' if view == 'assembly-merging' else 'Assembly'
            note = check['reviewNote']
            art = PUBLIC / check['restoredArt'].lstrip('/')
            svg = out / (item_id + '.svg')
            title_view = 'assembly merging emphasis' if view == 'assembly-merging' else 'assembly emphasis'
            svg.write_text(art_svg(art, fitting_id + ' — ' + title_view + ' — ' + original['name'], note))
            reference = PUBLIC / original['referenceImage'].lstrip('/')
            revision = hashlib.sha256(svg.read_bytes() + reference.read_bytes()).hexdigest()
            decision = decisions.get((item_id, revision))
            accepted = bool(decision and decision['status'] == 'accepted')
            item = dict(original, id=item_id, fittingId=fitting_id, artworkView=view,
                        restoredArt=check['restoredArt'], svg='/' + str(svg.relative_to(PUBLIC)),
                        revision=revision, restorationNotes=[note], sharedArtworkIds=[item_id],
                        qaRecord=str(config_path.relative_to(ROOT)), unchangedStandalone=False,
                        status='visually-approved' if accepted else 'assembly-needs-review')
            item.pop('visualReview', None)
            if view == 'assembly-merging':
                item['artworkCondition'] = {'upstreamReturn': True, 'mergingFlow': True}
                item['equivalentLengthAdjustment'] = {
                    'operation': 'add',
                    'feet': original['referenceValues']['mergingFlowEquivalentLengthFeet'],
                    'sourceValueKey': 'referenceValues.mergingFlowEquivalentLengthFeet',
                    'condition': 'Upstream return flow merges with the joist return.'}
            with Image.open(art) as image:
                item['embeddedRasterSize'] = list(image.size)
            if decision:
                item['visualReview'] = decision
                if decision['status'] == 'needs-work':
                    item['status'] = 'needs-work'
            items.append(item)
            card = dict(original_cards[fitting_id], id=item_id, number=fitting_id + ' · ' + view_label,
                        image='..' + item['svg'] + '?revision=' + revision[:12], revision=revision,
                        notes=[note], reviewNote=note, priorApproval=accepted)
            cards.append(card)
            views[view] = {'itemId': item_id, 'image': item['svg']}
        families.append({'id': fitting_id, 'name': original['name'], 'artworkByView': views})
    write_json(out / 'manifest.json', {'schemaVersion': 1, 'group': 7, 'drawingCount': len(items),
        'familyCount': len(families), 'families': families, 'items': items,
        'status': 'visually-approved' if all(i['status'] == 'visually-approved' for i in items) else 'needs-review'})
    batch = {'id': 'group-7-options', 'title': 'Group 7 · individual and assembly options',
        'description': 'Individual drawings are retained. Additional 7A–7C assembly views emphasize '
                       'the selected fitting with bold blue airflow arrows.',
        'referenceGallery': 'group-7-references.html', 'items': cards}
    write_json(PUBLIC / 'fitting-review/batches/group-7-options.json', batch)
    if activate:
        (PUBLIC / 'fitting-review/data.js').write_text('window.FITTING_REVIEW = ' + json.dumps(batch, indent=2) + ';\n')
    print(f'Group 7 options: {len(items)} drawings; activated={activate}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--activate', action='store_true')
    package(parser.parse_args().activate)
