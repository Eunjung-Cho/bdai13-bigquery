"""Export each page's SQL examples without maintaining a second editable copy."""
from pathlib import Path
import re
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / 'docs'
target = DOCS / 'downloads' / 'sql'
target.mkdir(parents=True, exist_ok=True)
count = 0
for page in sorted(DOCS.rglob('*.md')):
    blocks = re.findall(r'^([ \t]*)```sql[^\n]*\n(.*?)^\1```[ \t]*$',
                        page.read_text(encoding='utf-8'), re.M | re.S)
    if not blocks:
        continue
    sections = [f'-- Source: {page.relative_to(DOCS).as_posix()}\n'
                '-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.\n'
                '-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.\n'
                '-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.\n']
    for index, (indent, block) in enumerate(blocks, 1):
        code = '\n'.join(line[len(indent):] if line.startswith(indent) else line
                         for line in block.splitlines())
        sections.append(f'\n-- Example {index}\n{code}\n')
    destination = target / (page.relative_to(DOCS).with_suffix('').as_posix().replace('/', '-') + '.sql')
    destination.write_text('\n'.join(sections), encoding='utf-8')
    count += len(blocks)
print(f'Exported {count} SQL examples from Markdown.')
with ZipFile(DOCS/'downloads/course-sql.zip', 'w', ZIP_DEFLATED) as archive:
    for source in sorted(target.glob('*.sql')):
        archive.write(source, source.name)
with ZipFile(DOCS/'downloads/streamlit-starter.zip', 'w', ZIP_DEFLATED) as archive:
    for name in ['app.py', 'data_access.py', 'requirements.txt', 'README.md', '.gitignore',
                 '.streamlit/config.toml', '.streamlit/secrets.toml.example']:
        archive.write(ROOT/'starter'/name, name)
