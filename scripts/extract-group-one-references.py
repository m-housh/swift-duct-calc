#!/usr/bin/env python3
"""Recreate Group 1 continuation source crops (requires Poppler and ImageMagick)."""
import subprocess
import tempfile
from pathlib import Path
from fitting_group_one import SOURCES

root=Path(__file__).resolve().parents[1]
out=root/'Public/images/fittings/references'
out.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='group1-reference-') as temp:
    prefix=Path(temp)/'source'
    subprocess.run(['pdfimages','-png',str(root/'Public/files/ManD.Groups.pdf'),str(prefix)],check=True)
    for letter,(index,_,_,crop) in SOURCES.items():
        x,y,w,h=crop
        subprocess.run(['magick',f'{prefix}-{index:03}.png','-crop',f'{w}x{h}+{x}+{y}','+repage',str(out/f'1{letter}.png')],check=True)
print('Extracted 14 unretouched Group 1 reference crops.')
