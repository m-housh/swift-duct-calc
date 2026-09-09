"""Remaining Group 2 contours traced in the embedded source images' coordinates.

2B, 2K and 2N are accepted pilot assets and are deliberately not regenerated here.
Names describe visible shapes; the PDF identifies these fittings by number.
"""
from xml.sax.saxutils import escape

# Image index, first PDF page containing it, printed page, reference crop x/y/w/h.
SOURCES={
 'A':(14,5,163,(70,230,210,270)), 'C':(14,5,163,(195,240,215,265)),
 'D':(14,5,163,(265,245,225,265)), 'E':(14,5,163,(365,250,230,265)),
 'F':(14,5,163,(455,255,230,265)), 'G':(14,5,163,(545,260,235,265)),
 'H':(14,5,163,(635,265,235,265)), 'I':(18,6,164,(60,245,245,285)),
 'J':(18,6,164,(190,250,245,285)), 'L':(18,6,164,(450,275,245,285)),
 'M':(18,6,164,(620,290,250,285)), 'O':(24,8,165,(330,290,145,150)),
 'P':(24,8,165,(515,365,125,102)), 'Q':(24,8,165,(692,424,135,105)),
}
VALUES={
 'A':[35,45,55,65,70,80], 'C':[65,65,65,65,70,80],
 'D':[40,50,60,65,75,85], 'E':[25,30,35,40,45,50],
 'F':[20,20,20,20,25,25], 'G':[65,65,65,70,80,90], 'H':[70,70,70,75,85,95],
 'I':[65,75,85,95,100,110], 'J':[50,60,65,70,75,80],
 'L':[70,80,90,95,105,115], 'M':[70,80,90,95,105,115],
 'O':[55,65,75,85,90,100], 'P':[50,55,60,65,70,75], 'Q':[10,10,15,20,20,25],
}
NAMES={
 'A':'Straight round branch takeoff', 'C':'Round takeoff with projecting entry',
 'D':'Straight rectangular branch takeoff', 'E':'Rectangular takeoff with flared entry',
 'F':'Flared takeoff with projecting entry', 'G':'Rectangular takeoff with projecting tab',
 'H':'Rectangular takeoff with raised entry edge', 'I':'Round elbow takeoff',
 'J':'Eased round elbow takeoff', 'L':'Rectangular takeoff with curved heel',
 'M':'Rectangular takeoff with square heel', 'O':'Elbow branch on round trunk',
 'P':'Straight collar on round trunk', 'Q':'Tapered collar on round trunk',
}
NOTES={
 'C':'Dashed lines retain the projecting entry shown in the source.',
 'F':'Dashed lines retain the projecting entry shown in the source.',
 'G':'Dashed lines retain the projecting tab shown in the source.',
 'H':'Raised entry-edge detail follows the source drawing.',
 'O':'Round trunk section retained to show the elbow connection.',
 'P':'Round trunk section retained to show the straight collar.',
 'Q':'Round trunk section retained to show the tapered collar.',
}


def p(d,**attrs):
    return '<path d="'+d+'" '+ ' '.join(f'{k.replace("_","-")}="{v}"' for k,v in attrs.items())+'/>'


def ellipse(cx,cy,rx,ry):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="white"/>'


def rectangular_trunk(letter):
    """Local source-perspective trunk patch behind a selected branch."""
    centers={'A':190,'C':300,'D':390,'E':490,'F':585,'G':675,'H':765,
             'I':175,'J':300,'L':575,'M':750}
    center=centers[letter]; left=center-115; right=center+115
    if letter in 'ACDEFGH':
        far=lambda x:298+.073*x
        near=lambda x:347+.073*x
    else:
        far=lambda x:350+.09*x
        near=lambda x:400+.09*x
    # Three traced, parallel edges define two visible surfaces. The selected
    # fitting intersects the darker side surface between far() and near().
    top=lambda x:far(x)-48
    return (p(f'M{left} {top(left):.2f}L{right} {top(right):.2f}L{right} {far(right):.2f}L{left} {far(left):.2f}Z',fill='#f8fafc')+
            p(f'M{left} {far(left):.2f}L{right} {far(right):.2f}L{right} {near(right):.2f}L{left} {near(left):.2f}Z',fill='#e2e8f0'))


def art(letter):
    context=rectangular_trunk(letter) if letter in 'ACDEFGHIJLM' else ''
    if letter=='A':
        return context+p('M120 400L192 323Q201 314 211 320Q220 326 215 334L134 415Z',fill='white')+ellipse(127,408,10,10)
    if letter=='C':
        return context+p('M318 338L331 325Q339 321 346 328Q352 334 347 340L337 350',stroke_dasharray='3 2',stroke_width=1.1)+p('M244 415L316 340Q324 331 334 336Q342 341 338 348L257 430Z',fill='white')+ellipse(250,422,10,11)
    if letter=='D':
        return context+'<g transform="translate(0 10)">'+p('M306 422L394 330L435 334V353L347 444L306 440Z',fill='white')+p('M306 422L347 426L435 334M347 426V444M306 440L322 424')+'</g>'
    if letter=='E':
        top=p('M477 338L537 344L449 436L409 433L487 352Z',fill='white')
        side=p('M537 344V365L449 455V436Z',fill='white')+p('M449 436V455L409 452V433Z',fill='white')
        return context+top+side+p('M537 344V365L449 455L409 452V433M449 436V455M409 452L425 434M477 338V354L481 358')
    if letter=='F':
        top=p('M575 348L635 355L547 446L506 442L585 362Z',fill='white')
        side=p('M635 355V376L547 466V446Z',fill='white')+p('M547 446V466L506 462V442Z',fill='white')
        return context+p('M597 350V338L635 355',stroke_dasharray='4 2',stroke_width=1.1)+top+side+p('M635 355V376L547 466L506 462V442M547 446V466M506 462L522 444M575 348V364L579 369')
    if letter=='G':
        return context+p('M691 358V350L724 363',stroke_dasharray='4 2',stroke_width=1.1)+p('M594 452L683 357L724 363V384L634 475L594 472Z',fill='white')+p('M594 452L634 456L724 363M634 456V475M594 472L610 454')
    if letter=='H':
        # Dashed verticals are the source's hidden raised-entry detail, not
        # an invented set of internal turning vanes.
        hidden=p('M774 368L814 358V385',stroke_dasharray='3 2',stroke_width=1.1)
        for x in range(780,814,5):
            top=368-(x-774)*.25; bottom=368+(x-774)*.1
            hidden+=p(f'M{x} {top}V{bottom}',stroke_dasharray='2 1',stroke_width=1)
        return context+hidden+p('M686 461L774 368L814 372V391L725 481L686 479Z',fill='white')+p('M686 461L725 465L814 372M725 465V481M686 479L702 463')
    if letter=='I':
        return context+'<g transform="translate(0 -55)">'+p('M156 383L277 260Q283 255 290 259Q296 262 297 269L183 391',fill='white')+p('M156 383Q166 371 180 383L185 389V404Q170 418 156 404Z',fill='white')+p('M156 383Q163 379 173 383Q181 386 185 391M156 385Q168 397 183 390')+'</g>'
    if letter=='J':
        body=p('M266 386L393 270Q400 264 408 269Q414 272 416 277L310 385Q317 394 315 405Q313 419 302 426Q286 434 272 424Q259 415 260 400Q260 392 266 386Z',fill='white')
        face=p('M260 400Q270 387 285 389Q305 391 315 405M260 400Q271 417 288 418Q306 419 315 405')
        seam=p('M266 386Q279 376 294 382Q305 385 310 395')
        return context+'<g transform="translate(0 -45)">'+body+face+seam+'</g>'
    if letter=='L':
        return context+'<g transform="translate(0 -35)">'+p('M500 451Q493 431 510 409L532 383L620 293L672 298V319L586 411V429L553 455Z',fill='white')+p('M532 383L585 388L672 298M585 388Q549 421 553 455M585 388V411')+'</g>'
    if letter=='M':
        return context+'<g transform="translate(0 -35)">'+p('M666 456L674 425L694 399L786 309L839 315V336L754 420V442L721 470L666 466Z',fill='white')+p('M694 399L753 404L839 315M674 425L727 430L753 404V420M666 456L721 460L727 430M721 460V470')+'</g>'
    if letter=='O':
        trunk=p('M338 339L461 379M338 389L459 424M369 349C350 344 340 384 356 394M451 376C432 371 422 408 438 418')
        elbow=p('M389 333L402 316Q412 310 420 317Q426 324 426 331Q425 336 417 340L403 347Z',fill='white')+p('M402 316Q416 316 419 335')
        neck=p('M388 337V358Q390 367 402 367Q415 367 417 359V337Z',fill='white')+p('M388 348Q403 361 417 348')+ellipse(402.5,337,14.5,10)
        return trunk+'<g transform="translate(0 9)">'+elbow+neck+'</g>'
    if letter=='P':
        trunk=p('M515 387L639 423M515 432L637 467M550 397C531 392 521 428 537 438M616 416C597 411 587 447 603 457')
        return trunk+p('M564 386V405Q564 415 578 415Q593 415 593 405V386Z',fill='white')+p('M564 396Q578 409 593 396')+ellipse(578.5,386,14.5,10)
    if letter=='Q':
        trunk=p('M692 436L827 473M692 480L826 517M729 446C710 441 700 477 716 487M799 465C780 460 770 496 786 506')
        return trunk+p('M733 458V464Q734 469 747 469Q761 469 762 463V458Z',fill='white')+p('M737 447L733 458Q747 470 762 458L757 447Z',fill='white')+p('M737 440V448Q745 457 757 448V440Z',fill='white')+ellipse(747,440,10,6)
    raise ValueError(letter)


def generate(out):
    entries=[]
    for letter,spec in SOURCES.items():
        index,page,printed,crop=spec; x,y,w,h=crop; key='2'+letter
        scale=min(450/w,320/h); offset=(640-w*scale)/2
        contours=art(letter); name=NAMES[letter]; note=NOTES.get(letter,'Connection contours follow the source perspective.')
        svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="640" height="520" viewBox="0 0 640 520" role="img" aria-labelledby="title desc">
<title id="title">{key} — {escape(name)}</title><desc id="desc">{escape(note)} Source printed page {printed}. Reference equivalent length depends on downstream branch count. Review drawing, not to scale.</desc>
<style>text{{font-family:Arial,sans-serif;fill:#243b53}}path,ellipse{{stroke-linecap:round;stroke-linejoin:round}}</style>
<rect width="640" height="520" rx="16" fill="white"/>
<text x="32" y="44" font-size="28" font-weight="700">{key}</text><text x="96" y="43" font-size="18">{escape(name)}</text>
<text x="32" y="76" font-size="13">GROUP 2 · SUPPLY AIR · SOURCE PERSPECTIVE</text>
<g transform="translate({offset:.4f} 105) scale({scale:.6f}) translate({-x} {-y})" fill="none" stroke="#243b53" stroke-width="1.2">{contours}</g>
<text x="32" y="448" font-size="13">{escape(note)}</text>
<text x="32" y="473" font-size="13">Reference EL varies with downstream branch count.</text>
<text x="32" y="499" font-size="12">REVIEW DRAWING · NOT TO SCALE · Source: PDF p. {page} / printed p. {printed}</text>
</svg>'''
        (out/f'{key}.svg').write_text(svg+'\n')
        entries.append(dict(id=key,fittingNumber=key,group=2,letter=letter,variant=None,name=name,system='supply',image=f'/images/fittings/{key}.svg',status='source-trace-needs-review',drawingMethod='Source-perspective contours in scan coordinates; adjacent branches omitted.',referenceConditions=dict(velocityFpm=900,frictionRateIwcPer100Feet=.08),referenceEquivalentLengthByDownstreamBranches=[dict(branchCountMin=i,branchCountMax=i if i<5 else None,feet=v) for i,v in enumerate(VALUES[letter])],notes=[note,'Count downstream branches to trunk end or next reducer; restart count after a reducer.'],source=dict(pdf='/files/ManD.Groups.pdf',pdfPage=page,printedPage=printed,referenceImage=f'/images/fittings/references/{key}.png',embeddedImageIndex=index,cropPixels=list(crop))))
    return entries
