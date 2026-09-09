#!/usr/bin/env python3
"""Regenerate both fitting pilots. Standard library only; no source image tracing dependency."""
import importlib.util
import json
from pathlib import Path
from xml.sax.saxutils import escape
from fitting_source_traces import TRACES, geometry, write_comparisons
from fitting_review_decisions import apply_saved_reviews
from fitting_group_one import generate as generate_group_one
from fitting_group_two import generate as generate_group_two

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Public/images/fittings'
spec = importlib.util.spec_from_file_location('pilot', Path(__file__).with_name('generate-fitting-pilot.py'))
pilot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pilot)


def path(d, fill='white', extra=''):
    return f'<path d="{d}" fill="{fill}" {extra}/>'


def text(x, y, s, size=15):
    return f'<text x="{x}" y="{y}" font-size="{size}">{escape(s)}</text>'


def rect_trunk():
    return path('M115 210L205 155L555 220L465 275Z', '#f1f5f9') + path('M115 210V270L465 335V275Z', '#e2e8f0') + path('M465 275L555 220V280L465 335Z', '#f8fafc')


def shape(key):
    if key in TRACES:
        return geometry(key)
    if key == '2K':
        surface = path('M104 326L194 270L548 325L459 384Z', '#f1f5f9')
        pipe = path('M267 215L431 84Q440 78 448 86L456 94Q462 102 454 109L294 234Z', 'white') + '<ellipse cx="444" cy="96" rx="11" ry="17" transform="rotate(-39 444 96)" fill="white"/>'
        plate = path('M190 330L250 292L360 310L300 350Z', 'white') + path('M190 330V339L300 359L360 319V310', 'white')
        transition = path('M210 324Q221 271 249 231Q257 219 267 215Q282 211 294 234Q324 265 340 317L300 341Z', 'white')
        return surface+pipe+plate+transition+text(100, 408, 'Rectangular base transitions continuously to an angled round outlet')
    if key == '2N':
        trunk = path('M138 225L505 291Q530 296 529 326Q528 354 501 354L135 286Q111 280 112 253Q113 226 138 225Z', '#f1f5f9') + '<ellipse cx="510" cy="323" rx="19" ry="31" transform="rotate(-8 510 323)" fill="white"/>'
        branch = path('M276 252Q267 241 273 224L383 142Q394 135 403 144Q412 154 406 165L309 245Q298 254 302 265Q287 263 276 252Z', 'white') + '<ellipse cx="395" cy="153" rx="12" ry="18" transform="rotate(-36 395 153)" fill="white"/>'
        joint = path('M276 252Q287 263 302 265', 'none')
        return trunk+branch+joint+text(113, 408, 'Angled round branch joins the crown of a round trunk')
    if key == '3A':
        # Plan outline extruded to an axonometric sheet-metal fitting.
        return extrude([('M',130,120),('L',460,120),('L',460,185),('L',355,185),('C',355,210,385,225,430,225),('L',465,225),('L',465,295),('L',420,295),('C',335,295,280,240,280,205),('L',130,205),('Z',)]) + text(120, 410, 'Full-radius branch at a reducing trunk')
    if key.startswith('3S'):
        # Orthographic plan view makes the inside-corner choice legible.
        body = path('M150 140H230V210' + ('Q230 310 330 310H465V390H330Q150 390 150 210Z' if key=='3S-full' else ('V285Q230 310 255 310H465V390H330Q150 390 150 210Z' if key=='3S-tight' else 'V310H465V390H330Q150 390 150 210Z')), '#f8fafc')
        return body + path('M190 170V215Q190 350 335 350H420','none','stroke="#64748b" stroke-dasharray="6 6"') + path('M420 350H443','none','marker-end="url(#arrow)"') + text(285, 245, key.split('-')[1].capitalize() + ' inside corner') + path('M300 254L243 289' if key!='3S-full' else 'M310 254L274 278','none','stroke="#64748b"') + text(115, 430, 'Same fitting number; corner geometry selects the variant')
    raise ValueError(key)


def extrude(commands):
    def project(x,y,z=0):
        return (x*.85+y*.32-10, y*.63-x*.14+125+z)
    def d(z):
        parts=[]
        for c in commands:
            parts.append(c[0])
            for i in range(1,len(c),2):
                a,b=project(c[i],c[i+1],z); parts.append(f'{a:.1f},{b:.1f}')
        return ' '.join(parts)
    # Bottom outline and selected exposed edges precede the opaque top face.
    result=path(d(45),'#e2e8f0')
    for x,y in [(130,120),(130,205),(460,120),(460,185),(420,295),(465,295),(465,225)]:
        a,b=project(x,y); result+=path(f'M{a},{b}v45','none')
    return result+path(d(0),'#f8fafc')


ITEMS = [
    ('2B','Round tapered branch takeoff',5,163,[20,30,35,40,45,50]),
    ('2K','Angled round takeoff on rectangular base',6,164,[50,60,65,70,75,80]),
    ('2N','Angled branch on round trunk',8,165,[35,35,40,40,40,40]),
    ('3A','Full-radius takeoff',10,166,15),
    ('3S-full','Hard-bend takeoff · full radius',11,167,15),
    ('3S-tight','Hard-bend takeoff · tight radius',11,167,35),
    ('3S-mitered','Hard-bend takeoff · mitered corner',11,167,90),
    ('3T','In-line eased takeoff',11,167,10),
]


def main():
    pilot.main()
    catalog=json.loads((OUT/'catalog.json').read_text())
    conditions=catalog.pop('referenceConditions')
    for old in catalog['fittings']:
        old['referenceConditions']=conditions
        old['fittingNumber']=old['id']
        old['variant']=None
    catalog['fittings'].extend(generate_group_one(OUT))
    for key,name,page,printed,value in ITEMS:
        number=key.split('-')[0]
        variant=key.split('-')[1] if '-' in key else None
        group=int(number[0]); view='PLAN VIEW' if key.startswith('3S') else 'PERSPECTIVE SCHEMATIC'
        if key in TRACES:
            view='SOURCE-CONTOUR TRACE'
        note='EL varies with downstream branch count.' if group==2 else 'Reference geometry; review against source before use.'
        svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="640" height="520" viewBox="0 0 640 520" role="img" aria-labelledby="title desc">
<title id="title">{escape(number+' — '+name)}</title><desc id="desc">{escape(name)}. {escape(note)} Source PDF page {page}, printed page {printed}. Schematic, not to scale.</desc>
<defs><marker id="arrow" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><path d="M0 0L8 3L0 6Z" fill="#64748b"/></marker></defs>
<style>text{{font-family:Arial,sans-serif;fill:#243b53;stroke:none}}path,ellipse{{stroke-linejoin:round;stroke-linecap:round}}</style>
<rect width="640" height="520" rx="16" fill="white"/>
{text(32,44,number,28)}{text(96,43,name,18)}{text(32,76,f'GROUP {group} · SUPPLY AIR · {view}',13)}
<g stroke="#243b53" stroke-width="2.3" fill="none">{shape(key)}</g>
{text(32,465,note,14)}{text(32,493,f'REVIEW PILOT · NOT TO SCALE · Source: PDF p. {page} / printed p. {printed}',12)}
</svg>'''
        (OUT/f'{key}.svg').write_text(svg+'\n')
        entry=dict(id=key,fittingNumber=number,group=group,letter=number[1:],name=name,system='supply',variant=variant,image=f'/images/fittings/{key}.svg',status='schematic-pilot-needs-review',referenceConditions=conditions,source=dict(pdf='/files/ManD.Groups.pdf',pdfPage=page,printedPage=printed))
        if key in TRACES:
            entry['status']='source-trace-needs-review'
            entry['source']['referenceImage']=f'/images/fittings/references/{key}.png'
            entry['source']['cropPixels']=TRACES[key]['crop']
            entry['source']['embeddedImageIndex']=TRACES[key]['sourceImage']
            entry['drawingMethod']='Manual contour trace; source perspective retained.'
        if group==2:
            entry['referenceEquivalentLengthByDownstreamBranches']=[dict(branchCountMin=i,branchCountMax=i if i<5 else None,feet=v) for i,v in enumerate(value)]
            entry['notes']=['Count downstream branches to trunk end or next reducer; restart count after a reducer.']
        else:
            entry['referenceEquivalentLengthFeet']=value
        catalog['fittings'].append(entry)
    catalog['fittings'].extend(generate_group_two(OUT))
    catalog['fittings'].sort(key=lambda item: (item['group'], item['letter'], item['id']))
    write_comparisons(OUT)
    catalog['schemaVersion']=2
    catalog['scope']='Complete Group 1 and Group 2 drawing coverage: 22 Group 1 drawings and 17 Group 2 drawings. Also retains five Group 3 pilot drawings. New Group 2 drawings await review.'
    catalog['groupCoverage']=[dict(group=1,sourceFittingNumbers=['1'+letter for letter in 'ABCDEFGHIKLMNOPQRST'],drawingCount=22,omittedSourceLetters=['J'],status='all-source-numbers-drawn')]
    catalog['groupCoverage'].append(dict(group=2,sourceFittingNumbers=['2'+letter for letter in 'ABCDEFGHIJKLMNOPQ'],drawingCount=17,status='all-source-numbers-drawn'))
    catalog['sourceIssues']=[dict(fittingNumber='3U',overviewPdfPage=10,detailPdfPage=11,description='Overview groups 3S/3U at 15/35/90 feet by inside radius. Detail labels a mitered 3U at 10 feet with vanes and 80 without. Unresolved; no automatic value or 3U asset supplied.')]
    apply_saved_reviews(ROOT, catalog)
    (OUT/'catalog.json').write_text(json.dumps(catalog,indent=2)+'\n')


if __name__=='__main__':
    main()
