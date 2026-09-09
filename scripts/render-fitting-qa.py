#!/usr/bin/env python3
"""Render fitting-specific source/SVG pairs into contact sheets for visual QA."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / 'Public'


def entries(manifest):
    return manifest.get('fittings') or manifest.get('items') or manifest.get('drawings') or []


def fields(group, entry):
    if group == 3:
        return entry['assetId'], entry['svg'], entry['source']['referenceImage']
    if group == 5:
        return entry['id'], entry['svgPath'], entry['referenceImagePath']
    return entry['id'], entry['svg'], entry['referenceImage']


def fit_panel(path, size=(620, 470)):
    with Image.open(path) as source:
        image = source.convert('RGB')
    image = ImageOps.contain(image, size)
    panel = Image.new('RGB', size, 'white')
    panel.paste(image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2))
    return panel


def main(group, output):
    manifest_path = PUBLIC / f'images/fittings/group-{group}/manifest.json'
    manifest = json.loads(manifest_path.read_text())
    output.mkdir(parents=True, exist_ok=True)
    font = ImageFont.load_default(size=18)
    pairs = []; revisions = {}
    for entry in entries(manifest):
        key, svg_url, reference_url = fields(group, entry)
        svg = PUBLIC / svg_url.lstrip('/')
        reference = PUBLIC / reference_url.lstrip('/')
        revisions[key] = hashlib.sha256(svg.read_bytes() + reference.read_bytes()).hexdigest()
        rendered = output / f'{key}-svg.png'
        subprocess.run(['magick', str(svg), '-background', 'white', '-alpha', 'remove',
                        '-resize', '620x470', str(rendered)], check=True)
        canvas = Image.new('RGB', (1280, 540), '#f1f5f9')
        draw = ImageDraw.Draw(canvas)
        draw.text((20, 12), f'{key}  ORIGINAL', fill='#243b53', font=font)
        draw.text((660, 12), f'{key}  SVG', fill='#243b53', font=font)
        canvas.paste(fit_panel(reference), (10, 55))
        canvas.paste(fit_panel(rendered), (650, 55))
        pair = output / f'{key}-pair.png'; canvas.save(pair); pairs.append((key, pair))
    sheets = []
    for start in range(0, len(pairs), 4):
        sheet = Image.new('RGB', (2560, 1080), 'white')
        for index, (_, pair) in enumerate(pairs[start:start + 4]):
            with Image.open(pair) as image:
                sheet.paste(image.convert('RGB'), ((index % 2) * 1280, (index // 2) * 540))
        path = output / f'sheet-{start // 4 + 1:02d}.png'; sheet.save(path); sheets.append(path)
    index = {'group': group, 'drawingCount': len(pairs), 'status': 'pending-visual-inspection',
             'revisions': revisions,
             'sheets': [str(path) for path in sheets]}
    (output / 'qa-index.json').write_text(json.dumps(index, indent=2) + '\n')
    print(f'Rendered {len(pairs)} Group {group} comparisons into {len(sheets)} sheets at {output}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('group', type=int)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    main(args.group, args.output or Path(f'/tmp/fitting-qa-group-{args.group}'))
