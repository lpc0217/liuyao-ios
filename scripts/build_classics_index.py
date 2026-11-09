#!/usr/bin/env python3
"""为本机个人 App 生成带书名、章节和 PDF 页码的古籍检索资料。"""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
folder = root/'build/classics-extracted'
manifest = json.loads((folder/'manifest.json').read_text())
pages = json.loads((folder/'pages.json').read_text())
chapters = manifest['chapters']
starts = [c for c in chapters if c['level'] == 0 and c['title'].startswith('《')]
books = []
for index, chapter in enumerate(starts):
    end = starts[index+1]['pdfPage']-1 if index+1<len(starts) else manifest['pageCount']
    books.append({'title':chapter['book'],'startPage':chapter['pdfPage'],'endPage':end})

passages = []
current_book = ''
current_chapter = ''
for page in pages:
    number = page['pdfPage']
    headings = [c for c in chapters if c['pdfPage'] == number]
    if headings:
        current_book = headings[-1]['book']
        current_chapter = '、'.join(dict.fromkeys(c['title'] for c in headings if not c['title'].startswith('《')))
        if not current_chapter:
            current_chapter = '卷首'
    if not current_book:
        continue
    text = page['text']
    # 目录密集点线不作为论断依据；图表保留原样，提示模型不得据此重算排盘。
    if len(re.findall(r'\.{8,}', text)) >= 4:
        continue
    text = re.sub(r'(?<=[\u3400-\u9fff]) +(?=[\u3400-\u9fff])', '', text)
    text = re.sub(r'\n[ \t]*\n+', '\n\n', text).strip()
    if len(text)<30:
        continue
    offset = 0
    index = 0
    while offset < len(text):
        end = min(offset+800,len(text))
        if end<len(text):
            boundary = max(text.rfind('。',offset+450,end),text.rfind('\n',offset+450,end))
            if boundary>offset:
                end=boundary+1
        excerpt = text[offset:end].strip()
        if len(excerpt)>=30:
            index += 1
            passages.append({'id':f'P{number:04d}-{index:02d}','book':current_book,
                             'chapter':current_chapter,'pdfPage':number,'text':excerpt})
        if end == len(text):
            break
        offset = max(end-80,offset+1)

document = {'title':'六爻古籍经典合集','sourceSHA256':manifest['sourceSHA256'],
            'pageCount':manifest['pageCount'],'characterCount':manifest['characters'],
            'books':books,'passages':passages}
output = root/'Sources/LiuYaoCore/Resources/classics.json'
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(document,ensure_ascii=False,separators=(',',':')))
print(json.dumps({'books':len(books),'pages':document['pageCount'],'passages':len(passages),'bytes':output.stat().st_size},ensure_ascii=False))
