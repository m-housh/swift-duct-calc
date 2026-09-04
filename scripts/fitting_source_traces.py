"""Manual contours in enlarged source-crop coordinates, not inferred 3D geometry.

Reference PNGs are native-resolution crops from pdfimages output. Coordinates
below use 4x crop pixels solely for convenient tracing. No raster is embedded
in the standalone fitting assets; review comparisons embed the reference.
"""
import base64
from pathlib import Path

TRACES = {
    '2B': dict(
        size=(544, 500), crop=[176, 307, 136, 125], sourceImage=14,
        printedPage=163,
        contours='''
<path d="M0 48L544 88L544 276L0 236Z" fill="#e2e8f0"/>
<path d="M324 28L490 40V151L324 136Z" fill="white"/>
<path d="M324 28L369 73M490 40L421 79M490 151L421 116M324 136L369 110"/>
<path d="M28 401L339 88C357 70 379 68 398 79C411 87 417 101 416 114Q416 123 409 130L90 463Z" fill="white"/>
<ellipse cx="59" cy="432" rx="44" ry="43" fill="white"/>
'''),
    '3T': dict(
        size=(448, 604), crop=[574, 737, 112, 151], sourceImage=32,
        printedPage=167,
        contours='''
<path d="M33 157L54 152L253 77Q256 72 263 69Q270 65 279 66L331 52C357 52 386 128 398 195C409 250 410 284 398 308L329 333L314 336L110 530L88 539L33 407Z" fill="white"/>
<path d="M54 152L110 287V530M33 157L88 291V539M88 291L110 287M33 407L51 399L88 505"/>
<path d="M51 200.855V399"/>
<path d="M253 77C280 82 309 164 324 230C335 280 331 315 314 336"/>
<path d="M263 69C291 77 320 160 336 228C348 280 343 315 329 333"/>
'''),
}


def geometry(key):
    """Uniform scaling preserves the traced silhouette and source perspective."""
    spec = TRACES[key]
    w, h = spec['size']
    scale = min(390 / w, 325 / h)
    x, y = (640 - w * scale) / 2, 105
    return (f'<g transform="translate({x:.4f} {y}) scale({scale:.6f})" '
            f'fill="none" stroke="#243b53" stroke-width="3" '
            f'stroke-linecap="round" stroke-linejoin="round">{spec["contours"]}</g>')


def write_comparisons(out: Path):
    for key, spec in TRACES.items():
        w, h = spec['size']
        scale = min(500 / w, 530 / h)
        x, y = (560 - w * scale) / 2, 90
        png = base64.b64encode((out / 'references' / f'{key}.png').read_bytes()).decode()
        svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1120" height="700" viewBox="0 0 1120 700">
<rect width="1120" height="700" fill="white"/>
<g font-family="Arial,sans-serif" fill="#243b53">
<text x="28" y="36" font-size="24">{key} — source comparison</text>
<text x="28" y="68" font-size="16">Original crop · printed page {spec['printedPage']}</text>
<text x="588" y="68" font-size="16">New SVG · contours traced in the same coordinates</text>
<text x="28" y="656" font-size="15">Source crop retains surrounding marks. SVG isolates the fitting and omits leader lines.</text>
<text x="28" y="682" font-size="14">Manual trace for visual review; native source resolution limits fine detail.</text>
</g>
<path d="M560 88V620" stroke="#cbd5e1"/>
<image x="{x}" y="{y}" width="{w*scale}" height="{h*scale}" href="data:image/png;base64,{png}"/>
<g transform="translate({560+x} {y}) scale({scale})" stroke="#243b53" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round">{spec['contours']}</g>
</svg>'''
        (out / 'references' / f'{key}-comparison.svg').write_text(svg + '\n')
