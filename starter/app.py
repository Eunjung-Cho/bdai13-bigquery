"""BDAI 13기: 완성 코드 실행 → 한 부분 수정 → SQL과 대조."""
import pandas as pd
import streamlit as st
from data_access import load_mart, summarize

# 실습 1: 제목만 바꿔 봅니다.
st.set_page_config(page_title='카드 소비 리포트', layout='wide')
st.title('카드 소비 리포트')
st.caption('2018년 · 합성 카드 거래 · 월별 업종·채널 집계')

try:
    settings = dict(st.secrets['data'])
except (FileNotFoundError, KeyError):
    st.info('데이터 연결을 준비하세요. 강의의 앱 데이터 연결 안내에 따라 Secrets를 설정하면 마트를 조회합니다.')
    st.stop()

try:
    with st.spinner('집계 마트를 불러오는 중입니다.'):
        data, metadata = load_mart(**settings)
except Exception:
    # 인증값·계정정보가 담길 수 있는 원문 오류를 공개 화면에 출력하지 않습니다.
    st.error('마트를 읽지 못했습니다. 프로젝트·리전·조회 권한·쿼리 상한·마트 스키마를 강의 안내와 비교하세요.')
    st.stop()

st.caption(f"{metadata['mode']} · 데이터 취득 시각 {metadata['loaded_at']} · 앱 조회 캐시 최대 10분")
if data.empty:
    st.info('조회 기간에 집계 데이터가 없습니다. 원천 범위와 5주차 마트를 확인하세요.')
    st.stop()

# 실습 2: 이미 제공된 필터를 바꾸고 결과를 SQL과 비교합니다.
with st.sidebar:
    st.header('분석 조건')
    months = sorted(data.tx_month.dt.strftime('%Y-%m').unique())
    chosen_months = st.multiselect('월', months, default=months, key='months')
    channels = sorted(data.channel.unique())
    chosen_channels = st.multiselect('채널', channels, default=channels, key='channels')
    mcc_options = sorted(data.mcc.unique())
    chosen_mcc = st.multiselect('업종 코드', mcc_options, default=mcc_options, key='mcc')

filtered = data[
    data.tx_month.dt.strftime('%Y-%m').isin(chosen_months)
    & data.channel.isin(chosen_channels)
    & data.mcc.isin(chosen_mcc)
].copy()
if filtered.empty:
    st.info('선택한 조건에 해당하는 데이터가 없습니다. 필터를 하나 이상 선택하세요.')
    st.stop()

# 실습 3: 평균의 평균 대신 분자와 분모의 합으로 계산합니다.
metrics = summarize(filtered)
with st.container(horizontal=True):
    st.metric('순거래액 USD', f"${metrics['amount']:,.2f}")
    st.metric('거래 건수', f"{metrics['count']:,}")
    st.metric('거래당 순금액 USD', '계산 불가' if metrics['aov'] is None else f"${metrics['aov']:,.2f}")
    st.metric('사기 라벨 비율', '계산 불가' if metrics['fraud_rate'] is None else f"{metrics['fraud_rate']:.2%}")

st.subheader('월별 순거래액')
trend = filtered.groupby('tx_month', as_index=False).agg(amount_usd=('amount_usd', 'sum'))
# 차트 표현에만 float를 쓰며 지표 합산은 Decimal을 유지합니다.
trend['amount_usd'] = trend.amount_usd.astype(float)
st.line_chart(trend, x='tx_month', y='amount_usd', x_label='거래 월', y_label='순거래액 USD')

st.subheader('업종별 순거래액 상위 10개')
by_mcc = filtered.groupby('mcc', as_index=False).agg(amount_usd=('amount_usd', 'sum'))
by_mcc = by_mcc.sort_values(['amount_usd', 'mcc'], ascending=[False, True]).head(10)
by_mcc['amount_usd'] = by_mcc.amount_usd.astype(float)
st.bar_chart(by_mcc, x='mcc', y='amount_usd', horizontal=True,
             x_label='MCC 업종 코드', y_label='순거래액 USD')

with st.expander('집계표와 지표 정의 확인'):
    shown = filtered.copy()
    shown['amount_usd'] = shown.amount_usd.astype(float)
    st.dataframe(shown, hide_index=True)
    st.write('기간 내 날짜·금액이 유효하고 errors가 비어 있는 거래를 승인으로 간주한 교육용 정의입니다. 음수 금액을 포함합니다.')
    st.write('객단가 = 순거래액 합 / 거래 건수 합. 사기 라벨 비율 = 사기 건수 합 / 라벨 확인 건수 합.')
    st.write('활성 고객 수는 이 마트에서 합산하지 않습니다. 합성 데이터의 차이는 실제 고객 집단의 원인을 입증하지 않습니다.')
    if metadata['processed_bytes'] is not None:
        st.caption(f"조회 처리량: {metadata['processed_bytes']:,} bytes · BigQuery 캐시 적중: {metadata['cache_hit']}")

