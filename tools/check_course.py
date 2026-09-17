"""Local content checks. SQL parse checks cannot replace a BigQuery dry run."""
from pathlib import Path
import re
import json
import ast
from functools import lru_cache
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote

ROOT = Path(__file__).resolve().parents[1]
docs = ROOT/'docs'
pages = list(docs.rglob('*.md'))
errors = []
for page in pages:
    text = page.read_text(encoding='utf-8')
    if len(re.findall(r'^\s*```', text, re.M)) % 2:
        errors.append(f'Unclosed fence: {page.relative_to(ROOT)}')
    if re.search(r'finda-week7-505502|finda-13-2026|SOURCE_PROJECT|스크린샷 추가 예정', text):
        errors.append(f'Stale source or placeholder: {page.relative_to(ROOT)}')
for week in range(1,7):
    for name in ['lecture','lab','assignment']:
        if not (docs/f'week{week}'/f'{name}.md').is_file():
            errors.append(f'Missing week{week}/{name}')
nb=json.loads((docs/'downloads/bigquery-duckdb.ipynb').read_text(encoding='utf-8'))
for index, cell in enumerate(nb['cells']):
    if cell['cell_type']=='code':
        src=''.join(cell['source'])
        if not src.startswith('%'):
            ast.parse(src, filename=f'notebook cell {index}')

class Links(HTMLParser):
    def __init__(self):
        super().__init__(); self.links=[]; self.ids=set()
    def handle_starttag(self, tag, attrs):
        attrs=dict(attrs)
        if 'id' in attrs: self.ids.add(attrs['id'])
        for attr in ['href','src']:
            if attr in attrs: self.links.append(attrs[attr])

site=ROOT/'site'
checked=0
@lru_cache(maxsize=None)
def parsed(path):
    parser=Links()
    parser.feed(path.read_text(encoding='utf-8'))
    return parser
for page in site.rglob('*.html'):
    page=page.resolve()
    p=parsed(page)
    for link in p.links:
        u=urlsplit(link)
        if u.scheme or u.netloc or link.startswith('/'):
            continue
        target=(page.parent/unquote(u.path)).resolve() if u.path else page
        if target.is_dir(): target=target/'index.html'
        if not target.exists(): errors.append(f'Broken local URL {page.name}: {link}')
        elif target.suffix=='.html' and u.fragment:
            t=parsed(target)
            if unquote(u.fragment) not in t.ids:
                errors.append(f'Broken fragment {page.name}: {link}')
        checked+=1
print(json.dumps({'markdown_pages':len(pages), 'local_urls_checked':checked,
                  'errors':errors},ensure_ascii=False,indent=2))
raise SystemExit(bool(errors))
