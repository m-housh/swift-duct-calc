#!/usr/bin/env python3
"""Validate and archive a completed browser export, then update the catalog."""
import argparse
import hashlib
import json
from pathlib import Path
from fitting_review_decisions import apply_saved_reviews, revision


def validate(report, manifest, catalog, public):
    if report.get('schemaVersion') != 1 or report.get('batchId') != manifest['id']:
        raise ValueError('Review schema or batch does not match the current review page.')
    if not isinstance(report.get('completedAt'), str) or not report['completedAt']:
        raise ValueError('Finish the review before importing it.')
    decisions = report.get('drawings', [])
    ids = [d['id'] for d in decisions]
    if len(ids) != len(set(ids)) or set(ids) != {i['id'] for i in manifest['items']}:
        raise ValueError('Review must contain each drawing in the current batch exactly once.')
    fittings = {f['id']: f for f in catalog['fittings']}
    for d in decisions:
        if d['status'] not in {'accepted', 'needs-work'} or not isinstance(d.get('note'), str):
            raise ValueError(f"Incomplete or invalid decision for {d['id']}.")
        if d['revision'] != revision(public, fittings[d['id']]):
            raise ValueError(f"{d['id']} changed since this review. Review the current drawing before importing.")


def validate_manifest_review(report, manifest, public):
    if report.get('schemaVersion') != 1 or report.get('batchId') != manifest['id']:
        raise ValueError('Review schema or batch does not match the current review page.')
    if not isinstance(report.get('completedAt'), str) or not report['completedAt']:
        raise ValueError('Finish the review before importing it.')
    decisions = report.get('drawings', [])
    ids = [d.get('id') for d in decisions]
    items = {item['id']: item for item in manifest['items']}
    if len(ids) != len(set(ids)) or set(ids) != set(items):
        raise ValueError('Review must contain each drawing in the current batch exactly once.')
    for decision in decisions:
        if decision.get('status') not in {'accepted', 'needs-work'} or not isinstance(decision.get('note'), str):
            raise ValueError(f"Incomplete or invalid decision for {decision.get('id')}.")
        item = items[decision['id']]
        drawing = public / item['image'].removeprefix('../')
        reference = public / item['reference'].removeprefix('../')
        current = hashlib.sha256(drawing.read_bytes() + reference.read_bytes()).hexdigest()
        if decision.get('revision') != item.get('revision') or decision['revision'] != current:
            raise ValueError(f"{decision['id']} changed since this review. Review the current drawing before importing.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('review', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    public = root / 'Public'
    raw = args.review.read_bytes()
    report = json.loads(raw)
    batch_id = report.get('batchId')
    manifest_path = public / 'fitting-review/batches' / f'{batch_id}.json'
    if not isinstance(batch_id, str) or not manifest_path.is_file():
        raise ValueError('Unknown review batch.')
    manifest = json.loads(manifest_path.read_text())
    catalog_path = public / 'images/fittings/catalog.json'
    catalog = json.loads(catalog_path.read_text())
    catalog_batches = {'pilot-01', 'group-1', 'group-2'}
    if batch_id in catalog_batches:
        validate(report, manifest, catalog, public)
    else:
        validate_manifest_review(report, manifest, public)
    archive = root / 'docs/fitting-reviews'
    archive.mkdir(exist_ok=True)
    # Content-derived names make repeat imports idempotent without overwriting history.
    (archive / f'review-{hashlib.sha256(raw).hexdigest()[:16]}.json').write_bytes(raw)
    if batch_id in catalog_batches:
        apply_saved_reviews(root, catalog)
        catalog_path.write_text(json.dumps(catalog, indent=2) + '\n')
    accepted = sum(d['status'] == 'accepted' for d in report['drawings'])
    print(f"Imported {accepted} accepted; {len(report['drawings']) - accepted} need work.")


if __name__ == '__main__':
    main()
