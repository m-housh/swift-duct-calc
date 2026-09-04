#!/usr/bin/env python3
"""Build the static review manifest; decisions are never stored in this output."""
import json
from pathlib import Path
from fitting_review_decisions import reference_path, revision

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / 'Public'
items = []
for fitting in json.loads((PUBLIC / 'images/fittings/catalog.json').read_text())['fittings']:
    key = fitting['id']
    drawing = PUBLIC / fitting['image'].lstrip('/')
    reference = reference_path(PUBLIC, fitting)
    if not reference.is_file():
        raise FileNotFoundError(reference)
    items.append(dict(id=key, number=fitting['fittingNumber'], name=fitting['name'],
                      group=fitting['group'], image='../' + fitting['image'].lstrip('/'),
                      reference='../' + str(reference.relative_to(PUBLIC)),
                      sourcePage=167 if key=='3A' else fitting['source']['printedPage'],
                      sourcePDF='../files/ManD.Groups.pdf#page=' + str(11 if key=='3A' else fitting['source']['pdfPage']),
                      priorApproval=fitting['status']=='visually-approved',
                      revision=revision(PUBLIC, fitting)))
result = dict(id='pilot-01', title='Existing pilot · 13 drawings',
              description='Groups 1–3 selections. This batch is the existing pilot, not the complete groups.', items=items)
(PUBLIC / 'fitting-review/data.js').write_text('window.FITTING_REVIEW = ' + json.dumps(result, indent=2) + ';\n')
