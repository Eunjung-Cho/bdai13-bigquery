# 6주차 실습 · AI와 함께 Streamlit 완성하기

[강의](lecture.md) · [최종 제출](assignment.md) · [연결 준비](../reference/dashboard-connection.md)

직접 실습 60분입니다. 5주차 마트와 계정·서비스 계정·앱 저장소는 사전에 준비합니다. 기본 앱을 내려받아 한 부분씩 바꾸므로 Python 선수 지식은 필요하지 않습니다.

## A 연결과 첫 화면 확인 · 15분

1. [기본 앱 ZIP](../downloads/streamlit-starter.zip)을 풀고 파일을 읽습니다.
2. `app.py`는 화면, `data_access.py`는 연결, `requirements.txt`는 필요한 패키지 목록입니다.
3. [연결 안내](../reference/dashboard-connection.md)의 Secrets 설정을 적용합니다.
4. Community Cloud에서 기본 앱을 배포하거나 강사가 준비한 자신의 앱을 엽니다.
5. 실제 마트의 월·채널·MCC가 보이는지 확인합니다. 설정 전 안내 화면은 연결 완료가 아닙니다.

| 값 | 넣을 내용 |
| --- | --- |
| query_project | 학생의 쿼리 실행 프로젝트 |
| table | 학생의 `bdai13.mart_monthly_mcc` 전체 주소 |
| location | 마트의 실제 리전 |
| maximum_bytes_billed | 수업에서 정한 1회 쿼리 상한 |

서비스 계정을 만들 수 없지만 Colab의 사용자 로그인으로 마트 조회는 가능하다면 [노트북](../downloads/bigquery-duckdb.ipynb)으로 `mart.duckdb`를 만들고 앱의 backend를 duckdb로 설정합니다. 두 경로를 모두 수행하지 않습니다. DuckDB는 스냅샷이며 새 파일로 교체해야 갱신됩니다.

## B 화면을 한 부분씩 바꾸기 · 25분

### B1 제목과 질문을 맞추기 · 5분

`st.title('카드 소비 리포트')`의 글자만 자신의 프로젝트 질문에 맞게 바꿉니다. 저장하고 앱에서 바뀐 제목을 확인합니다. 다른 함수나 연결 코드는 아직 바꾸지 않습니다.

### B2 필터를 읽고 조작하기 · 10분

월을 하나만 선택하고 채널을 온라인만 남깁니다. 지표 카드와 두 차트가 같은 조건을 따르는지 봅니다. 이어서 모든 월을 해제합니다. 앱은 데이터 없음 안내를 보여야 하며, 다른 조건의 숫자를 계속 보여주면 안 됩니다.

필터는 이미 제공되어 있습니다. 선택 도전으로 AI에게 기본 선택 월만 바꿔 달라고 요청할 수 있습니다. 필터를 조작할 때마다 원천 전체를 다시 조회하게 바꾸지 않습니다.

### B3 AI에게 작은 수정 요청 · 10분

```text
이 Streamlit 앱의 업종 Top 10 막대 차트를 Top 5로 바꿔 줘.
데이터 연결·Secrets·캐시·쿼리 상한은 유지해 줘.
다른 차트나 지표 정의는 바꾸지 마.
어느 줄이 왜 바뀌는지 Python 초급자에게 설명해 줘.
```

AI에게 코드를 제공하기 전에 Secrets·인증키가 포함되지 않았는지 확인합니다. 변경 전후 순거래액 카드가 같고, 막대 수만 최대 5개로 줄었는지 봅니다. 업종 수가 원래 5개 미만이면 실제 개수만 보입니다. 가짜 업종을 채우지 않습니다.

## C SQL 대조와 공개 확인 · 20분

아래 쿼리는 기본 앱의 지표 정의와 같은 재집계입니다. 앱과 같은 마트 주소로 바꾸고 실행합니다.

```sql
SELECT
    SUM(amount_usd) AS net_amount_usd,
    SUM(txn_count) AS txn_count,
    SUM(fraud_count) AS fraud_count,
    SUM(fraud_labeled_count) AS labeled_count,
    SAFE_DIVIDE(SUM(amount_usd), SUM(txn_count)) AS amount_per_txn,
    SAFE_DIVIDE(SUM(fraud_count), SUM(fraud_labeled_count)) AS fraud_rate
FROM `YOUR_PROJECT.bdai13.mart_monthly_mcc`
WHERE tx_month >= DATE '2018-01-01' AND tx_month < DATE '2019-01-01';
```

한 달을 검증할 때는 `tx_month = DATE '2018-03-01'`로 기간 조건을 바꾸고 앱에서도 2018-03만 선택합니다. 온라인만 확인하려면 `AND channel = '온라인'`을 추가합니다. MCC를 하나 고르면 SQL에도 해당 코드 조건을 넣습니다.

| 검사 조건 | SQL 금액·건수 | 앱 금액·건수 | 분모·비율 | 일치 여부 |
| --- | --- | --- | --- | --- |
| 2018년 전체 | 직접 기록 | 직접 기록 | 직접 기록 | |
| 2018-03 | 직접 기록 | 직접 기록 | 직접 기록 | |
| 2018-03 온라인 | 직접 기록 | 직접 기록 | 직접 기록 | |

금액은 SQL의 정확한 값을 먼저 대조한 뒤 화면의 소수 둘째 자리 반올림을 확인합니다. 비율 0.01이 화면 1%로 표시되는 것은 같습니다. 1을 1%로 다시 표시하는 오류와 구분합니다.

동료에게 앱 URL을 열어 달라고 하고 필터를 조작하게 합니다. 앱에 연결된 집계 데이터는 공개 범위에 들어갑니다. 프로젝트의 실제 키·개별 거래 행은 공유하지 않습니다. 공유 정책 때문에 외부에서 볼 수 없으면 공개 미완료로 기록하고 교사와 해결합니다.

## 흔한 문제

| 현상 | 확인 |
| --- | --- |
| 연결 준비 안내만 보임 | 실제 Secrets가 설정되었는가? example 파일만 두지 않았는가? |
| 마트 조회 실패 | 테이블 주소·리전·실행/읽기 권한·상한·스키마 |
| 앱 숫자가 SQL과 다름 | 월·채널·MCC 선택, 마트 갱신과 최대 10분 캐시 |
| 사기율이 0%와 다르게 보임 | NULL 라벨 분모, 표시 반올림, 0분모 |
| DuckDB 파일이 없다고 나옴 | 노트북 실행·다운로드·저장소 루트 파일명 |
| 노트북에서도 조회가 실패함 | DuckDB로 우회할 수 없음. BigQuery 계정 권한부터 확인 |
| 앱이 잠들거나 느리게 시작함 | 무료 호스팅의 상태와 자원 확인, 발표 전 열어 준비 |

## 완료 기준

- 앱이 BigQuery 직접 연결 또는 명시한 DuckDB 경로로 실제 집계 데이터를 읽습니다.
- 제목/차트 수정과 검증 근거를 설명할 수 있습니다.
- 최소 두 조건에서 SQL과 앱 숫자가 일치합니다.
- AI 사용 기록과 연결·갱신 방식, 공개 범위를 남겼습니다.

출처: [Streamlit 연결](https://docs.streamlit.io/develop/tutorials/databases/bigquery), [Secrets](https://docs.streamlit.io/deploy/streamlit-community-cloud/deploy-your-app/secrets-management), [캐싱](https://docs.streamlit.io/develop/concepts/architecture/caching), 사용자 수정 지시.
