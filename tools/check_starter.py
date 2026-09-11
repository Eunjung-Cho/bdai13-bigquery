"""Meaningful fixture checks: weighted metrics, filters, 0 denominator, no secrets."""
from pathlib import Path
import sys
import os
from decimal import Decimal
from datetime import date

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'starter'))
from data_access import summarize, validate_mart
import pandas as pd
import duckdb
from streamlit.testing.v1 import AppTest

temp=ROOT/'.build'
temp.mkdir(exist_ok=True)
frame=pd.DataFrame([
    [date(2018,1,1),5411,'온라인',Decimal('100.00'),2,1,2],
    [date(2018,2,1),5411,'오프라인',Decimal('900.00'),3,0,1],
    [date(2018,3,1),None,'미분류',Decimal('-20.00'),1,0,0],
],columns=['tx_month','mcc','channel','amount_usd','txn_count','fraud_count','fraud_labeled_count'])
validated=validate_mart(frame)
result=summarize(validated)
assert result['amount']==Decimal('980')
assert result['count']==6
assert result['fraud_rate']==Decimal(1)/3
assert summarize(validated[validated.channel=='미분류'])['fraud_rate'] is None
try:
    validate_mart(pd.concat([frame, frame.iloc[:1]]))
    raise AssertionError('Duplicate grain accepted')
except ValueError:
    pass
db=temp/'fixture.duckdb'
with duckdb.connect(str(db)) as con:
    con.register('source_df',frame)
    con.execute('CREATE OR REPLACE TABLE mart_monthly_mcc AS SELECT * FROM source_df')
    con.execute("CREATE OR REPLACE TABLE snapshot_metadata AS SELECT '2026-09-11T00:00:00+00:00' AS extracted_at, '교육용 검증 fixture' AS source_table")

at=AppTest.from_file(str(ROOT/'starter/app.py'),default_timeout=30)
at.secrets['data']={'backend':'duckdb','snapshot':str(db)}
at.run()
assert not at.exception, at.exception
assert at.metric[0].value=='$980.00'
assert at.metric[1].value=='6'
assert at.metric[3].value=='33.33%'
at.multiselect(key='channels').set_value(['온라인']).run()
assert not at.exception
assert at.metric[0].value=='$100.00'
assert at.metric[3].value=='50.00%'
at.multiselect(key='channels').set_value(['미분류']).run()
assert not at.exception
assert at.metric[3].value=='계산 불가'
at.multiselect(key='months').set_value([]).run()
assert not at.exception
assert len(at.metric)==0 and at.info
fresh=AppTest.from_file(str(ROOT/'starter/app.py'),default_timeout=30).run()
assert not fresh.exception and fresh.info
print('PASS: exact totals, weighted ratios, duplicate rejection, app filters, zero denominator, empty result, missing configuration.')
