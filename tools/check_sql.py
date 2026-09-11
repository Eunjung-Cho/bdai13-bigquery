"""Parse lecture SQL as GoogleSQL; does not execute against live data."""
from pathlib import Path
import re
import json
import sqlglot

root=Path(__file__).resolve().parents[1]
count=0
fragments=0
issues=[]
for page in (root/'docs').rglob('*.md'):
    for index, match in enumerate(re.finditer(
            r'^([ \t]*)```sql[^\n]*\n(.*?)^\1```[ \t]*$',
            page.read_text(encoding='utf-8'),re.M|re.S),1):
        count+=1
        statement=match.group(2)
        uncommented=re.sub(r'--[^\n]*', '', statement).strip()
        if uncommented.startswith('LEFT JOIN'):
            # The page explicitly presents only JOIN clauses as a reading example.
            statement='SELECT * FROM `finda-13-2026.tabformer.transactions` AS t\n'+statement
            fragments+=1
        try:
            sqlglot.parse(statement,read='bigquery')
        except Exception as error:
            issues.append({'page':str(page.relative_to(root)), 'block':index,
                           'error':str(error)[:350]})
print(json.dumps({'sql_blocks':count,'join_fragments_parsed_in_context':fragments,'parse_issues':issues},ensure_ascii=False,indent=2))
raise SystemExit(bool(issues) or count==0)
