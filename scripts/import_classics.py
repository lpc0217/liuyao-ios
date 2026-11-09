#!/usr/bin/env python3
"""从用户提供的古籍 PDF 恢复字形对应的文字，并保留目录和 PDF 页码。"""
import argparse
import hashlib
import io
import json
import re
from pathlib import Path
import sys

root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / 'build/reference-deps'))
from fontTools.ttLib import TTFont
from pypdf import PdfReader
from pypdf._cmap import _parse_to_unicode
from pypdf.generic import DecodedStreamObject, NameObject

parser = argparse.ArgumentParser()
parser.add_argument('pdf', type=Path)
parser.add_argument('--output', type=Path, default=root/'build/classics-extracted')
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
reader = PdfReader(args.pdf)
seen = set()
font_report = []

for page in reader.pages:
    for ref in page.get('/Resources', {}).get('/Font', {}).values():
        font = ref.get_object()
        key = getattr(ref, 'idnum', id(font))
        if key in seen:
            continue
        seen.add(key)
        if font.get('/Subtype') != '/Type0' or not font.get('/DescendantFonts'):
            continue
        child = font['/DescendantFonts'][0].get_object()
        descriptor = child.get('/FontDescriptor')
        if not descriptor or not descriptor.get_object().get('/FontFile2'):
            continue
        embedded = TTFont(io.BytesIO(descriptor.get_object()['/FontFile2'].get_data()))
        order = embedded.getGlyphOrder()
        reverse = {}
        for unicode, glyph in (embedded.getBestCmap() or {}).items():
            reverse.setdefault(glyph, unicode)
        original, codes = _parse_to_unicode(font)
        gid_map = child.get('/CIDToGIDMap', '/Identity')
        gid_bytes = None if str(gid_map) == '/Identity' else gid_map.get_object().get_data()
        pairs = []
        changes = 0
        for cid in sorted(set(codes)):
            gid = cid if gid_bytes is None else int.from_bytes(gid_bytes[cid*2:cid*2+2], 'big')
            if gid >= len(order):
                continue
            unicode = reverse.get(order[gid])
            if unicode is None:
                continue
            text = chr(unicode)
            if text != original.get(chr(cid)):
                changes += 1
            pairs.append(f'<{cid:04X}> <{text.encode("utf-16-be").hex().upper()}>')
        if not pairs:
            continue
        lines = ['/CIDInit /ProcSet findresource begin', '12 dict begin', 'begincmap',
                 '/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def',
                 '/CMapName /Recovered-UCS def', '/CMapType 2 def',
                 '1 begincodespacerange', '<0000> <FFFF>', 'endcodespacerange']
        for start in range(0,len(pairs),100):
            chunk = pairs[start:start+100]
            lines += [f'{len(chunk)} beginbfchar', *chunk, 'endbfchar']
        lines += ['endcmap', 'CMapName currentdict /CMap defineresource pop', 'end', 'end']
        stream = DecodedStreamObject()
        stream.set_data('\n'.join(lines).encode('ascii'))
        font[NameObject('/ToUnicode')] = stream
        font_report.append({'font': str(font.get('/BaseFont')), 'codes':len(pairs), 'repaired':changes})

chapters = []
def walk(items, book='', parents=()):
    current_book = book
    previous_title = ''
    for item in items:
        if isinstance(item,list):
            walk(item,current_book,parents+(previous_title,))
            continue
        title = item.title.strip()
        previous_title = title
        if title.startswith('《'):
            current_book = title.strip('《》')
        page = reader.get_destination_page_number(item)+1
        chapters.append({'book':current_book,'title':title,'pdfPage':page,'level':len(parents)})
walk(reader.outline)
chapters.sort(key=lambda c:c['pdfPage'])
pages = []
for index, page in enumerate(reader.pages):
    text = page.extract_text() or ''
    # 仅移除扫描集合页眉与页脚，不重写原文措辞。
    text = re.sub(r'^《六爻古籍经典合集》\s*\n', '', text)
    text = re.sub(r'(?m)^\s*~\s*\d+\s*~\s*$', '', text).strip()
    pages.append({'pdfPage':index+1,'text':text})
    if (index+1)%100 == 0:
        print(f'Extracted {index+1}/{len(reader.pages)}',flush=True)
manifest = {'title':'六爻古籍经典合集','sourceSHA256':hashlib.sha256(args.pdf.read_bytes()).hexdigest(),
            'pageCount':len(reader.pages),'characters':sum(len(p['text']) for p in pages),
            'fontRepairs':font_report,'chapters':chapters}
(args.output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
(args.output/'pages.json').write_text(json.dumps(pages,ensure_ascii=False))
print(json.dumps({k:manifest[k] for k in ['pageCount','characters']},ensure_ascii=False))
print('Font maps repaired:',len(font_report),'Chapter entries:',len(chapters))
print('Page 12:',pages[11]['text'][:600])
