"""데이터 연결용 코드. 학생은 먼저 app.py의 화면 부분을 수정합니다."""
from datetime import date, datetime, timezone
from decimal import Decimal
from pathlib import Path
import re

import pandas as pd
import streamlit as st

COLUMNS = ['tx_month', 'mcc', 'channel', 'amount_usd', 'txn_count',
           'fraud_count', 'fraud_labeled_count']
MAX_ROWS = 50000


def validate_mart(frame):
    """빈 마트는 허용하지만 잘못된 스키마·중복 그레인은 화면에 올리지 않습니다."""
    missing = set(COLUMNS) - set(frame.columns)
    if missing:
        raise ValueError('필수 마트 컬럼 누락: ' + ', '.join(sorted(missing)))
    frame = frame[COLUMNS].copy()
    frame['tx_month'] = pd.to_datetime(frame['tx_month'], errors='raise')
    if frame['tx_month'].isna().any() or (frame['tx_month'].dt.day != 1).any():
        raise ValueError('tx_month는 NULL이 아닌 월초 날짜여야 합니다.')
    if frame[['tx_month', 'mcc', 'channel']].duplicated().any():
        raise ValueError('월 × MCC × 채널이 중복됩니다. 5주차 마트 그레인을 확인하세요.')
    if frame['channel'].isna().any():
        raise ValueError('알 수 없는 채널은 NULL 대신 미분류로 표준화하세요.')
    for name in ['txn_count', 'fraud_count', 'fraud_labeled_count']:
        values = pd.to_numeric(frame[name], errors='raise')
        if values.isna().any() or (values < 0).any() or (values % 1 != 0).any():
            raise ValueError(f'{name}는 0 이상의 정수여야 합니다.')
        frame[name] = values.astype('int64')
    if ((frame.fraud_count > frame.fraud_labeled_count) |
            (frame.fraud_labeled_count > frame.txn_count)).any():
        raise ValueError('사기 건수 ≤ 라벨 확인 건수 ≤ 거래 건수가 아닙니다.')
    if frame.amount_usd.isna().any():
        raise ValueError('마트의 금액 합에 NULL이 있습니다. 정제와 집계를 확인하세요.')
    frame['amount_usd'] = frame.amount_usd.map(lambda value: Decimal(str(value)))
    if not frame.amount_usd.map(lambda value: value.is_finite()).all():
        raise ValueError('금액에 무한대 또는 잘못된 숫자가 있습니다.')
    # 식별 코드이며 합산할 숫자가 아닙니다. 결측도 별도 그룹으로 남깁니다.
    frame['mcc'] = frame.mcc.map(
        lambda value: '미분류' if pd.isna(value) else str(int(value)))
    return frame


@st.cache_resource(max_entries=4)
def get_client(query_project):
    from google.cloud import bigquery
    from google.oauth2 import service_account

    if 'gcp_service_account' in st.secrets:
        credentials = service_account.Credentials.from_service_account_info(
            dict(st.secrets['gcp_service_account']))
        return bigquery.Client(project=query_project, credentials=credentials)
    # 강사 로컬/Cloud Shell에서 ADC가 준비되어 있을 때만 쓰는 경로입니다.
    return bigquery.Client(project=query_project)


@st.cache_data(ttl=600, max_entries=4, show_spinner=False)
def load_mart(backend, query_project='', table='', location='US',
              maximum_bytes_billed=100000000, snapshot='mart.duckdb'):
    loaded_at = datetime.now(timezone.utc).isoformat(timespec='seconds')
    if backend == 'bigquery':
        from google.cloud import bigquery

        if not re.fullmatch(r'[a-z][a-z0-9-]{4,61}[a-z0-9]\.[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*', table):
            raise ValueError('Secrets의 table을 본인의 프로젝트.데이터셋.마트 주소로 바꾸세요.')
        if not 1 <= maximum_bytes_billed <= 1000000000:
            raise ValueError('교육용 상한은 1–1,000,000,000바이트 범위입니다.')
        client = get_client(query_project)
        # 테이블 이름은 배포자 설정에서만 받고 검증합니다. 날짜는 쿼리 매개변수입니다.
        sql = f'''SELECT tx_month, mcc, channel, amount_usd,
                         txn_count, fraud_count, fraud_labeled_count
                  FROM `{table}`
                  WHERE tx_month >= @start_date AND tx_month < @end_date
                  ORDER BY tx_month, mcc, channel
                  LIMIT {MAX_ROWS + 1}'''
        config = bigquery.QueryJobConfig(
            maximum_bytes_billed=maximum_bytes_billed,
            query_parameters=[
                bigquery.ScalarQueryParameter('start_date', 'DATE', date(2018, 1, 1)),
                bigquery.ScalarQueryParameter('end_date', 'DATE', date(2019, 1, 1))])
        job = client.query(sql, job_config=config, location=location)
        rows = job.result(timeout=90)
        # 작은 집계 결과는 REST 경로로 가져옵니다. Storage API는 사용하지 않습니다.
        frame = rows.to_dataframe(create_bqstorage_client=False)
        if len(frame) > MAX_ROWS:
            raise ValueError('집계 행 수가 상한을 넘었습니다. 마트의 그레인과 기간을 확인하세요.')
        metadata = {'mode': 'BigQuery 직접 연결', 'loaded_at': loaded_at,
                    'processed_bytes': job.total_bytes_processed,
                    'cache_hit': job.cache_hit, 'table': table}
    elif backend == 'duckdb':
        import duckdb

        path = Path(snapshot)
        if not path.is_absolute():
            path = Path(__file__).parent / path
        if not path.is_file():
            raise ValueError('Colab에서 만든 mart.duckdb를 앱 폴더에 넣으세요.')
        with duckdb.connect(str(path), read_only=True) as connection:
            arrow = connection.execute(
                f"SELECT {', '.join(COLUMNS)} FROM mart_monthly_mcc LIMIT {MAX_ROWS + 1}"
            ).fetch_arrow_table()
            frame = arrow.to_pandas()
            row = connection.execute(
                'SELECT extracted_at, source_table FROM snapshot_metadata LIMIT 1').fetchone()
        if len(frame) > MAX_ROWS:
            raise ValueError('스냅샷의 집계 행이 너무 많습니다.')
        metadata = {'mode': 'DuckDB 스냅샷', 'loaded_at': str(row[0]),
                    'processed_bytes': None, 'cache_hit': None, 'table': row[1]}
    else:
        raise ValueError('backend는 bigquery 또는 duckdb입니다.')
    return validate_mart(frame), metadata


def summarize(frame):
    amount = sum(frame.amount_usd, Decimal('0'))
    count = int(frame.txn_count.sum())
    fraud = int(frame.fraud_count.sum())
    labeled = int(frame.fraud_labeled_count.sum())
    return {'amount': amount, 'count': count,
            'aov': amount / count if count else None,
            'fraud_rate': Decimal(fraud) / labeled if labeled else None}
