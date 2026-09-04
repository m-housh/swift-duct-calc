#!/usr/bin/env python3
"""Build static review batches; browser decisions are never overwritten."""
import argparse
import json
from pathlib import Path
from fitting_review_decisions import reference_path, revision

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / 'Public'
PILOT_IDS = {'1A','1B','1C','1D','1E','2B','2K','2N','3A','3S-full','3S-tight','3S-mitered','3T'}


def main(batch='group-1'):
    items = []
    for fitting in json.loads((PUBLIC / 'images/fittings/catalog.json').read_text())['fittings']:
        key = fitting['id']
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
    batches = {
        'pilot-01': dict(id='pilot-01', title='Original pilot · 13 drawings',
                         description='Archived pilot batch; all 13 drawings accepted in the completed review.',
                         items=[i for i in items if i['id'] in PILOT_IDS]),
        'group-1': dict(id='group-1', title='Group 1 · 22 drawings',
                        description='All 19 fitting numbers in the source, with separate 1M and 1S vane variants. Includes five previously accepted drawings. The source skips 1J.',
                        items=[i for i in items if i['group']==1]),
    }
    folder=PUBLIC/'fitting-review/batches'
    folder.mkdir(exist_ok=True)
    for key, data in batches.items():
        (folder/f'{key}.json').write_text(json.dumps(data,indent=2)+'\n')
    (PUBLIC / 'fitting-review/data.js').write_text('window.FITTING_REVIEW = ' + json.dumps(batches[batch], indent=2) + ';\n')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--batch',choices=['group-1','pilot-01'],default='group-1')
    main(parser.parse_args().batch)
