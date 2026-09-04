"""Apply saved visual decisions only to the exact SVG/reference pair reviewed."""
import hashlib
import json
from pathlib import Path

REFERENCES = {'1A': '1AB', '1B': '1AB', '1C': '1CD', '1D': '1CD', '1E': '1E',
              '2B': '2B', '2K': '2K', '2N': '2N', '3A': '3A',
              '3S-full': '3S', '3S-tight': '3S', '3S-mitered': '3S', '3T': '3T'}


def reference_path(public, fitting):
    explicit = fitting['source'].get('referenceImage')
    return public / (explicit.lstrip('/') if explicit else
                     f"images/fittings/references/{REFERENCES[fitting['id']]}.png")


def revision(public, fitting):
    drawing = public / fitting['image'].lstrip('/')
    return hashlib.sha256(drawing.read_bytes() + reference_path(public, fitting).read_bytes()).hexdigest()


def apply_saved_reviews(root, catalog):
    reports = []
    for path in (root / 'docs/fitting-reviews').glob('*.json'):
        report = json.loads(path.read_text())
        if report.get('schemaVersion') != 1 or not report.get('completedAt'):
            raise ValueError(f'Invalid completed review: {path}')
        reports.append((report, path))
    # The most recent applicable review wins; a redraw never inherits approval.
    for report, path in sorted(reports, key=lambda pair: pair[0]['completedAt']):
        decisions = {d['id']: d for d in report['drawings']}
        for fitting in catalog['fittings']:
            decision = decisions.get(fitting['id'])
            if not decision or decision['revision'] != revision(root / 'Public', fitting):
                continue
            if decision['status'] not in {'accepted', 'needs-work'}:
                raise ValueError(f'Invalid completed decision in {path}')
            fitting['status'] = 'visually-approved' if decision['status'] == 'accepted' else 'needs-work'
            fitting['visualReview'] = dict(
                revision=decision['revision'], completedAt=report['completedAt'],
                batchId=report['batchId'], note=decision['note'],
                record=str(path.relative_to(root)))
