#!/usr/bin/env python3
"""Recreate new Group 2 crops; requires Poppler and ImageMagick.

The accepted 2B, 2K and 2N reference images remain unchanged.
"""
import subprocess
import tempfile
from pathlib import Path
from fitting_group_two import SOURCES

root=Path(__file__).resolve().parents[1]
out=root/'Public/images/fittings/references'
out.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='group2-reference-') as temp:
    prefix=Path(temp)/'source'
    subprocess.run(['pdfimages','-png',str(root/'Public/files/ManD.Groups.pdf'),str(prefix)],check=True)
    for letter,(index,_,_,crop) in SOURCES.items():
        x,y,w,h=crop
        subprocess.run(['magick',f'{prefix}-{index:03}.png','-crop',f'{w}x{h}+{x}+{y}','+repage',str(out/f'2{letter}.png')],check=True)
print('Extracted 14 unretouched Group 2 reference crops.')
