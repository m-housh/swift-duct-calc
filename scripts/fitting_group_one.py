"""Group 1 continuation: side-elevation contours in original scan coordinates.

The source omits 1J. Vane-count variants get distinct asset IDs, while keeping
Manual D fitting numbers. Tables are reference transcriptions, not calculators.
"""
from xml.sax.saxutils import escape

# index, PDF page, printed page, crop (x,y,width,height). Crops retain source tables.
SOURCES = {
 'F':(2,1,160,(75,225,790,205)), 'G':(2,1,160,(45,460,820,215)),
 'H':(2,1,160,(80,720,520,215)), 'I':(2,1,160,(80,945,525,195)),
 'K':(6,2,161,(105,225,550,210)), 'L':(6,2,161,(110,460,790,215)),
 'M':(6,2,161,(135,700,590,210)), 'N':(6,2,161,(80,935,535,210)),
 'O':(10,3,162,(45,230,565,185)), 'P':(10,3,162,(45,455,565,190)),
 'Q':(10,3,162,(530,640,325,225)), 'R':(10,3,162,(530,640,325,225)),
 'S':(10,3,162,(45,805,340,350)), 'T':(10,3,162,(45,950,340,205)),
}


def p(d, **attrs):
    return '<path d="'+d+'" '+ ' '.join(f'{k.replace("_","-")}="{v}"' for k,v in attrs.items())+'/>'


def txt(x,y,value,size=11):
    return f'<text x="{x}" y="{y}" font-size="{size}" stroke="none" fill="#243b53">{escape(value)}</text>'


def arrow(d):
    return p(d, marker_end='url(#flow)', stroke_width=1.4)


def base(x,y,w,h):
    return p(f'M{x} {y}h{w}v{h}l{-w*.18} {-h*.12}l{-w*.18} {h*.2}l{-w*.16} {-h*.1}l{-w*.24} {h*.27}v{-h*.27}l{-w*.24} {h*.18}Z')+arrow(f'M{x+w*.5} {y+h*.72}V{y+h*.28}')


def dimension(x1,y1,x2,y2,label,tx,ty):
    return p(f'M{x1} {y1}L{x2} {y2}',stroke='#8192a2',stroke_width=.8)+txt(tx,ty,label)


def diagonal_vanes(x,y,dx,dy,count=7,left_turn=False):
    # Preserve the source's curved vane symbols along its diagonal guide.
    result=p(f'M{x} {y}l{dx} {dy}',stroke='#8192a2',stroke_width=.7)
    for i in range(count):
        t=(i+.5)/count; a=x+t*dx; b=y+t*dy
        curve = f'M{a+4} {b+5}q0 -8 -9 -7' if left_turn else f'M{a-4} {b+5}q0 -8 9 -7'
        result+=p(curve,stroke_width=.9)
    return result


def art(letter,variant=None):
    if letter=='F':
        return (75,225,280,205),p('M101 237H312L303 249L319 254L308 260L325 270L302 276L313 284H101Z')+p('M107 284V320M226 284V320')+base(95,320,143,83)+arrow('M202 261H240')+dimension(255,287,255,319,'10″ min.',260,306)+dimension(110,302,223,302,'W',157,307)+dimension(278,240,278,280,'H',274,265)
    if letter=='G':
        return (280,465,290,210),p('M301 478H529L520 490L535 496L525 503L541 511L522 516L529 523H301Z')+p('M301 523L330 552H444L473 523M330 552V563M444 552V563')+base(318,563,138,82)+arrow('M422 501H459')+dimension(330,541,444,541,'W',377,548)+dimension(496,482,496,520,'H',492,506)+txt(487,556,'45°')
    if letter in ('H','I'):
        y=737 if letter=='H' else 959
        shape=p(f'M104 {y}H312l-8 12l17 5l-9 7l15 10l-22 4l10 10H222v35H104Z')+base(92,y+83,142,86)+arrow(f'M264 {y+24}h37')
        if letter=='I':shape+=diagonal_vanes(105,y,119,47)
        else:shape+=p(f'M234 {y}v47')+dimension(110,y+65,219,y+65,'W',153,y+70)+dimension(247,y+3,247,y+44,'H',243,y+27)
        return (80,y-8,255,190),shape
    if letter=='K':
        return (105,225,280,205),p('M126 300V282Q126 238 171 237H365L354 249L370 255L360 262L377 274L353 279L365 287H265V300Z')+p('M272 237V287M126 300V313M265 300V313')+base(120,313,152,88)+arrow('M296 262H338')
    if letter=='L':
        return (115,465,265,205),p('M134 549V520Q133 479 178 478H360L350 490L365 496L355 503L370 514L350 519L361 525H273Q252 525 252 545V549Z')+p('M270 478V525M134 549V560M252 549V560')+base(127,560,144,82)+arrow('M296 501H333')+dimension(136,574,251,574,'W',191,581)+txt(288,558,'R')+p('M286 550L256 535',stroke_width=.7)
    if letter=='M':
        shape=p('M155 796V764Q155 712 208 712H337L329 723L345 729L334 735L350 742L330 747L340 753H281Q260 753 260 777V796Z')+p('M282 712V753M155 796V807M260 796V807')+base(149,807,127,75)+arrow('M300 733H329')
        paths=['M187 795V765Q187 727 220 727H281'] if variant=='1-vane' else ['M178 795V766Q178 723 216 723H281','M231 795V766Q231 743 250 743H281']
        shape+=''.join(p(d,stroke_dasharray='7 4',stroke_width=1.5) for d in paths)
        shape+=dimension(157,818,260,818,'W',202,825)+txt(294,792,'R')+p('M291 785L265 771',stroke_width=.7)
        return (137,701,220,205),shape
    if letter=='N':
        return (280,950,325,190),p('M295 960H572L562 972L579 978L568 984L585 991L563 998L575 1009H432V1022H295Z')+p('M433 960V1009M523 960V1009M295 1022V1029M428 1022V1029')+base(289,1029,144,82)+arrow('M448 995H514')+arrow('M574 984H598')+txt(442,1042,'Transition')
    if letter in ('O','P'):
        y=244 if letter=='O' else 466
        shape=p(f'M74 {y}H347l-8 12l16 6l-12 5l19 10l-26 4l12 6H73l14 -9l-25 -4l17 -7l-17 -5l20 -3Z')+p(f'M149 {y}v50h116v-50M154 {y+50}v10M265 {y+50}v10')+base(143 if letter=='O' else 140,y+60,134 if letter=='O' else 139,78)+arrow(f'M121 {y+23}H85')+arrow(f'M297 {y+23}h34')
        if letter=='P':shape+=diagonal_vanes(149,512,60,-46,5,left_turn=True)+diagonal_vanes(209,466,60,46,5)
        else:shape+=dimension(154,277,264,277,'W',201,283)+dimension(287,247,287,283,'H',283,270)
        return (48,y-10,325,180),shape
    if letter in ('Q','R'):
        shape=base(633,765,131,80)
        if letter=='Q':shape+=p('M565 689H693V765H644V733H566L576 725L557 720L570 711L561 704L575 701Z')+p('M639 689V733M644 738H693')+diagonal_vanes(642,733,51,-44,7,left_turn=True)+arrow('M615 711H581')+dimension(617,735,617,763,'10″ min.',553,780)
        else:shape+=p('M704 689H834L825 701L840 708L828 714L844 723L825 727L837 733H753V765H704Z')+p('M758 689V733M704 738H753')+arrow('M781 711H816')+dimension(780,735,780,763,'10″ min.',786,780)
        return (540,678,325,185),shape
    if letter=='S':
        shape=p('M73 961H152Q205 961 205 1011V1042H154V1019Q154 1007 142 1007H73L85 998L63 994L75 985L66 978L80 975Z')+p('M131 961V1007M154 1031H205')+base(141,1042,139,81)+arrow('M123 984H85')+dimension(112,1010,112,1040,'10″ min.',54,1052)
        count=int(variant[0])
        for d in ['M188 1030V1011Q187 973 151 973H143','M171 1030V1011Q171 988 150 988H143'][:count]:shape+=p(d,stroke_dasharray='6 4',stroke_width=1)
        return (49,950,245,200),shape
    if letter=='T':
        return (133,950,245,200),p('M216 962H353L344 974L360 981L348 988L365 998L344 1002L355 1007H286L268 1027V1042H216Z')+p('M286 962V1007M216 1032H268')+base(141,1042,139,81)+arrow('M308 984H345')
    raise ValueError(letter)


def ratio_table(parameter, pairs, **extra):
    return dict(parameter=parameter,rows=[dict(ratio=r,feet=v,**extra) for r,v in pairs])


ITEMS=[
 ('F',None,'Bull-head outlet',ratio_table('H/W',[(.5,120),(1,85)]),'Maintain 10″ minimum clearance.'),
 ('G',None,'Tapered-head outlet',ratio_table('H/W',[(.5,35),(1,25)]),'45° tapered entry.'),
 ('H',None,'Square elbow without vanes',ratio_table('H/W',[(.5,120),(1,85)]),'No turning vanes.'),
 ('I',None,'Square elbow with vanes',20,'Turning vanes follow the diagonal shown in the source.'),
 ('K',None,'Radius elbow with mitered inside corner',85,'Mitered inside corner; curved outer wall.'),
 ('L',None,'Radius elbow without vanes',ratio_table('R/W',[(.25,40),(.5,20),(1,10)]),'Radius varies with R/W.'),
 ('M','1-vane','Radius elbow · one vane',ratio_table('R/W',[(.05,30),(.25,20),(.5,10)],vaneCount=1),'One internal turning vane.'),
 ('M','2-vanes','Radius elbow · two vanes',ratio_table('R/W',[(.05,20),(.25,10),(.5,10)],vaneCount=2),'Two internal turning vanes.'),
 ('N',None,'Outlet transition',15,'Add transition EL to the upstream elbow or tee EL.'),
 ('O',None,'Bull-head tee without vanes',ratio_table('H/W',[(.5,120),(1,85)]),'Two outlets; no turning vanes.'),
 ('P',None,'Vaned tee',20,'Turning vanes divide flow between the two outlets.'),
 ('Q',None,'Vaned elbow at plenum',50,'Maintain 10″ minimum clearance.'),
 ('R',None,'Square elbow at plenum',120,'Maintain 10″ minimum clearance.'),
 ('S','0-vanes','Radius elbow at plenum · no vanes',60,'Maintain 10″ minimum clearance.'),
 ('S','1-vane','Radius elbow at plenum · one vane',40,'Maintain 10″ minimum clearance.'),
 ('S','2-vanes','Radius elbow at plenum · two vanes',30,'Maintain 10″ minimum clearance.'),
 ('T',None,'Elbow with angled inside corner',60,'Angled inside corner as illustrated in the source.'),
]


def generate(out):
    entries=[]
    for letter,variant,name,values,note in ITEMS:
        number='1'+letter; key=number+('-'+variant if variant else '')
        index,page,printed,crop=SOURCES[letter]
        (x,y,w,h),contours=art(letter,variant)
        scale=min(530/w,315/h); ox=(640-w*scale)/2
        svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="640" height="520" viewBox="0 0 640 520" role="img" aria-labelledby="title desc">
<title id="title">{number} — {escape(name)}</title><desc id="desc">{escape(note)} Side elevation traced from printed page {printed}. Review drawing, not to scale.</desc>
<defs><marker id="flow" viewBox="0 0 8 5" markerWidth="6" markerHeight="4" refX="7" refY="2.5" orient="auto"><path d="M0 0L8 2.5L0 5Z" fill="#243b53"/></marker></defs>
<style>text{{font-family:Arial,sans-serif}}path{{stroke-linejoin:round;stroke-linecap:round}}</style>
<rect width="640" height="520" rx="16" fill="white"/>
<g fill="#243b53"><text x="32" y="44" font-size="28" font-weight="700">{number}</text><text x="96" y="43" font-size="18">{escape(name)}</text><text x="32" y="76" font-size="13">GROUP 1 · SUPPLY AIR · SOURCE SIDE ELEVATION</text></g>
<g transform="translate({ox:.4f} 105) scale({scale:.6f}) translate({-x} {-y})" fill="none" stroke="#243b53" stroke-width="1.6">{contours}</g>
<text x="32" y="459" fill="#243b53" font-size="14">{escape(note)}</text>
<text x="32" y="490" fill="#4b6274" font-size="12">REVIEW DRAWING · NOT TO SCALE · Source: PDF p. {page} / printed p. {printed}</text>
</svg>'''
        (out/f'{key}.svg').write_text(svg+'\n')
        entry=dict(id=key,fittingNumber=number,group=1,letter=letter,variant=variant,name=name,system='supply',image=f'/images/fittings/{key}.svg',status='source-trace-needs-review',notes=[note],drawingMethod='Side-elevation contours traced in source scan coordinates; selected connection isolated for paired drawings.',referenceConditions=dict(velocityFpm=900,frictionRateIwcPer100Feet=.08),source=dict(pdf='/files/ManD.Groups.pdf',pdfPage=page,printedPage=printed,referenceImage=f'/images/fittings/references/{number}.png',embeddedImageIndex=index,cropPixels=list(crop)))
        if isinstance(values,dict):entry['referenceEquivalentLengthTable']=values
        else:entry['referenceEquivalentLengthFeet']=values
        if letter=='S':entry['vaneCount']=int(variant[0])
        if letter=='M':entry['vaneCount']=int(variant[0])
        entries.append(entry)
    return entries
