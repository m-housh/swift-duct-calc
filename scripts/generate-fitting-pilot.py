#!/usr/bin/env python3
"""Generate the reviewed-by-eye Group 1 pilot using only Python's standard library."""
import json
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Public/images/fittings'
FITTINGS = [
    ('A', 'Round straight takeoff', 35, 'Round duct connects directly to the plenum.'),
    ('B', 'Round tapered takeoff', 10, 'Round duct connects through a tapered entry.'),
    ('C', 'Rectangular straight takeoff', 35, 'Maintain the illustrated 10-inch minimum clearance.'),
    ('D', 'Rectangular 45-degree entry', 10, 'Entry extends H/2 at 45 degrees; 10-inch minimum clearance.'),
    ('E', 'Rectangular angled takeoff', 10, 'Upper transition: 30 degrees. Lower transition: 45 degrees.'),
]


def drawing(letter, name, note):
    # Side elevations isolate the selected connection from the paired PDF drawing.
    left = letter in 'AC'
    plenum = 'M220 130H360V300H220Z' if not left else 'M320 130H460V300H320Z'
    base = ('M205 300H375V410L348 395L319 410L290 395L261 410L234 395L205 410Z'
            if not left else
            'M305 300H475V410L448 395L419 410L390 395L361 410L334 395L305 410Z')
    geometry = {
        'A': '<path d="M108 178H320M108 222H320"/><ellipse cx="108" cy="200" rx="8" ry="22"/>',
        'B': '<path d="M360 154L402 178H540M360 246L402 222H540M402 178V222"/><ellipse cx="540" cy="200" rx="8" ry="22"/>',
        'C': '<path d="M108 178H320V222H108L119 211L101 200L119 189Z"/>',
        'D': '<path d="M360 178H540L528 189L546 200L528 211L540 222H382L360 244Z"/><path d="M382 178V222" stroke-dasharray="5 5"/>',
        'E': '<path d="M360 178L423 142H540L528 153L546 164L528 175L540 186H408L360 234Z"/><path d="M408 151V186" stroke-dasharray="5 5"/>',
    }[letter]
    arrow = 'M267 200H165' if left else ('M443 164H510' if letter == 'E' else 'M437 200H510')
    annotations = ''
    if letter in 'CD':
        x = 288 if left else 433
        annotations += f'<path d="M{x} 226V296M{x-6} 226H{x+6}M{x-6} 296H{x+6}" class="dimension"/><text x="{x+12}" y="280" class="small">10″ min.</text>'
    if letter == 'D':
        annotations += '<text x="393" y="253" class="small">45°</text><text x="405" y="133" class="small">H/2 entry</text><text x="550" y="206" class="small">H</text>'
    if letter == 'E':
        annotations += '<text x="413" y="124" class="small">30°</text><text x="396" y="237" class="small">45°</text>'
    center = 390 if left else 290
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="640" height="520" viewBox="0 0 640 520" role="img" aria-labelledby="title desc">
<title id="title">1{letter} — {escape(name)}</title>
<desc id="desc">Schematic side elevation of supply air fitting 1{letter}. Plenum large compared with duct. {escape(note)} Redrawn from ManD.Groups.pdf, PDF page 1, printed page 159. Review prototype; not to scale.</desc>
<defs><marker id="arrow" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><path d="M0 0L8 3L0 6Z" fill="#243b53"/></marker></defs>
<style>text{{font-family:Arial,sans-serif;fill:#243b53;stroke:none}}.small{{font-size:15px}}.dimension{{stroke:#64748b;stroke-width:1.2}}</style>
<rect width="640" height="520" rx="16" fill="white"/>
<text x="32" y="47" font-size="28" font-weight="700">1{letter}</text><text x="95" y="45" font-size="21">{escape(name)}</text>
<text x="32" y="77" font-size="14" fill="#64748b">GROUP 1 · SUPPLY AIR · SIDE ELEVATION</text>
<g fill="none" stroke="#243b53" stroke-width="2.5" stroke-linejoin="round"><path d="{plenum}"/>
{geometry}<path d="{base}" fill="#f1f5f9"/>
<path d="{arrow}" marker-end="url(#arrow)"/>{annotations}</g>
<text x="{center}" y="260" text-anchor="middle" font-size="14">Large plenum</text>
<text x="{center}" y="348" text-anchor="middle" font-size="14">Air handler</text>
<text x="32" y="460" font-size="14">Plenum size is large compared with duct size.</text>
<text x="32" y="488" font-size="12">SCHEMATIC PILOT · NOT TO SCALE · Source: PDF p. 1 / printed p. 159</text>
</svg>
'''


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    entries = []
    for letter, name, length, note in FITTINGS:
        fitting_id = f'1{letter}'
        (OUT / f'{fitting_id}.svg').write_text(drawing(letter, name, note))
        entries.append(dict(id=fitting_id, group=1, letter=letter, name=name,
                            system='supply', image=f'/images/fittings/{fitting_id}.svg',
                            status='schematic-pilot-needs-review',
                            referenceEquivalentLengthFeet=length,
                            notes=[note, 'Plenum size is large compared with duct size.'],
                            source=dict(pdf='/files/ManD.Groups.pdf', pdfPage=1, printedPage=159)))
    catalog = dict(schemaVersion=1, scope='Pilot: fittings 1A–1E only; not the full PDF.',
                   referenceConditions=dict(velocityFpm=900, frictionRateIwcPer100Feet=0.08),
                   fittings=entries)
    (OUT / 'catalog.json').write_text(json.dumps(catalog, indent=2) + '\n')


if __name__ == '__main__':
    main()
