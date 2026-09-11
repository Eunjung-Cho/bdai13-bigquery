# SQL 기초 리프레셔

약 40분 동안 작은 표로 SELECT, WHERE, GROUP BY, JOIN을 다시 익힙니다. 아래 표는 **직접 만든 교육용 가상 데이터**이며 실제 TabFormer 분석 결과가 아닙니다. 모든 예제는 외부 테이블 권한 없이 BigQuery에서 실행할 수 있습니다.

## 1. 질문을 한 문장으로 쓰기

오늘의 질문은 “2018년 1월에 고객별로 얼마를 썼는가?”입니다. 먼저 기간, 금액의 단위, 한 행의 의미를 확인합니다.

| tx_id | user_id | tx_date | amount_usd |
| --- | --- | --- | --- |
| T1 | 1 | 2018-01-01 | 100 |
| T2 | 1 | 2018-01-02 | -20 |
| T3 | 2 | 2018-01-03 | 50 |
| T4 | 2 | 2018-02-01 | 70 |

가상 예시의 `tx_id`는 설명용입니다. 수업 원천 데이터에 같은 컬럼이 있다고 가정하지 마세요. 1월의 순거래액은 손으로 `100 - 20 + 50 = 130`달러라고 계산할 수 있습니다.

## 2. 필요한 열 선택과 행 필터

```sql
WITH sample AS (
    SELECT 'T1' AS tx_id, 1 AS user_id, DATE '2018-01-01' AS tx_date,
        NUMERIC '100' AS amount_usd
    UNION ALL SELECT 'T2', 1, DATE '2018-01-02', NUMERIC '-20'
    UNION ALL SELECT 'T3', 2, DATE '2018-01-03', NUMERIC '50'
    UNION ALL SELECT 'T4', 2, DATE '2018-02-01', NUMERIC '70'
)
SELECT user_id, tx_date, amount_usd
FROM sample
WHERE tx_date >= DATE '2018-01-01'
  AND tx_date < DATE '2018-02-01'
ORDER BY tx_date;
```

`WITH sample AS (...)`는 쿼리 안에서 사용할 임시 이름을 정의합니다. 영구 테이블을 만드는 문장이 아닙니다. SELECT는 열을 고르고, WHERE는 행을 고르며, ORDER BY는 결과의 순서를 정합니다. 정렬을 쓰지 않으면 결과 순서는 보장되지 않습니다.

**손풀기:** 금액이 음수인 행만 남기려면 WHERE에 어떤 조건을 추가할까요? 기간 끝을 `< 2018-02-01`로 쓰면 다음 달 첫날이 포함될까요?

??? success "확인"
    `AND amount_usd < 0`을 추가하면 T2 한 행입니다. 끝 날짜가 미포함 조건이므로 2월 1일은 포함되지 않습니다.

## 3. GROUP BY로 한 행의 의미 바꾸기

```sql
WITH sample AS (
    SELECT 1 AS user_id, NUMERIC '100' AS amount_usd
    UNION ALL SELECT 1, NUMERIC '-20'
    UNION ALL SELECT 2, NUMERIC '50'
)
SELECT
    user_id,
    COUNT(*) AS txn_count,
    SUM(amount_usd) AS net_amount_usd,
    SAFE_DIVIDE(SUM(amount_usd), COUNT(*)) AS amount_per_transaction
FROM sample
GROUP BY user_id
ORDER BY user_id;
```

| user_id | txn_count | net_amount_usd | amount_per_transaction |
| --- | --- | --- | --- |
| 1 | 2 | 80 | 40 |
| 2 | 1 | 50 | 50 |

집계 전에는 한 행이 거래이고, 집계 후에는 한 행이 고객입니다. `GROUP BY`에 없는 열을 SELECT에 그냥 추가하면 어떤 값을 보여줄지 정할 수 없습니다. 예를 들어 고객별 표에서 여러 거래 날짜 중 어느 날짜를 보여줄 것인지부터 정해야 합니다.

전체 객단가는 `(80 + 50) / (2 + 1) = 약 43.33`입니다. 고객별 객단가의 평균 `(40 + 50) / 2 = 45`는 다른 지표입니다. 이 구분은 6주차 대시보드에서도 반복됩니다.

## 4. NULL을 모르는 값으로 읽기

```sql
WITH sample AS (
    SELECT NUMERIC '100' AS amount_usd
    UNION ALL SELECT CAST(NULL AS NUMERIC)
    UNION ALL SELECT NUMERIC '0'
)
SELECT
    COUNT(*) AS rows_all,
    COUNT(amount_usd) AS rows_known,
    COUNTIF(amount_usd IS NULL) AS rows_missing,
    SUM(amount_usd) AS amount_sum,
    AVG(amount_usd) AS amount_avg
FROM sample;
```

기대값은 전체 3행, 알려진 값 2행, 결측 1행, 합계 100, 평균 50입니다. `COUNT(*)`는 모든 행을 세지만 `COUNT(열)`은 NULL을 제외합니다. `AVG` 역시 NULL을 제외합니다. `WHERE amount_usd = NULL`로 결측을 찾지 말고 `IS NULL`을 씁니다.

**손풀기:** NULL을 0으로 바꾼 뒤 평균을 구하면 왜 약 33.33이 될까요? 이것이 값이 실제로 0이었다는 증거일까요?

## 5. JOIN은 관계를 붙이는 작업

```sql
WITH customers AS (
    SELECT 1 AS user_id, 'A' AS segment
    UNION ALL SELECT 2, 'B'
    UNION ALL SELECT 3, 'A'
), transactions AS (
    SELECT 1 AS user_id, NUMERIC '100' AS amount_usd
    UNION ALL SELECT 1, NUMERIC '-20'
    UNION ALL SELECT 2, NUMERIC '50'
)
SELECT
    c.user_id,
    c.segment,
    COUNT(t.user_id) AS txn_count,
    SUM(t.amount_usd) AS net_amount_usd
FROM customers AS c
LEFT JOIN transactions AS t
    ON c.user_id = t.user_id
GROUP BY c.user_id, c.segment
ORDER BY c.user_id;
```

고객 3은 거래가 없지만 LEFT JOIN이므로 결과에 남습니다. 이때 `COUNT(*)`를 쓰면 조인이 만든 보존 행도 한 행으로 세어 거래 1건처럼 보입니다. `COUNT(t.user_id)`는 오른쪽에서 실제 매칭된 거래만 셉니다. 금액 합은 NULL이며, 보고 목적에 따라 “거래 없음”을 확인한 뒤 0으로 표시할 수 있습니다.

INNER JOIN으로 바꾸면 고객 3은 사라집니다. 어느 조인이 맞는지는 “거래한 고객만 볼 것인가, 전체 고객을 기준으로 볼 것인가?”라는 질문에서 결정됩니다.

## 6. 작성 순서와 읽는 순서

```mermaid
flowchart LR
    F[FROM과 JOIN] --> W[WHERE]
    W --> G[GROUP BY]
    G --> H[HAVING]
    H --> S[SELECT]
    S --> O[ORDER BY]
    O --> L[LIMIT]
```

개념을 이해하기 위한 논리적 순서이며 실제 엔진의 물리 실행 계획은 최적화에 따라 달라집니다. WHERE는 집계 전 행 조건, HAVING은 집계 후 그룹 조건입니다.

```sql
WITH sample AS (
    SELECT 1 AS user_id, 100 AS amount_usd
    UNION ALL SELECT 1, -20
    UNION ALL SELECT 2, 50
)
SELECT user_id, SUM(amount_usd) AS net_amount_usd
FROM sample
GROUP BY user_id
HAVING SUM(amount_usd) >= 70;
```

결과는 고객 1, 순거래액 80입니다. `WHERE SUM(amount_usd) >= 70`은 집계가 생기기 전 집계값을 참조하므로 잘못된 위치입니다.

## 7. AI에게 질문을 맡길 때

먼저 표와 원하는 결과 한 행의 의미를 주세요. “고객별 매출 쿼리 짜줘”보다 다음처럼 쓰면 검증할 조건이 분명해집니다.

```text
BigQuery GoogleSQL로 작성해 줘.
입력: user_id INT64, tx_date DATE, amount_usd NUMERIC.
결과 한 행: 고객 1명.
기간: 2018-01-01 이상 2018-02-01 미만.
환불을 포함한 순거래액과 거래 건수가 필요해.
없는 컬럼을 만들지 말고, 가정과 NULL 처리 방식을 설명해 줘.
```

AI 답을 실행한 뒤 위 가상 데이터로 고객 1의 합이 80인지 확인하세요. 실행 오류를 고치는 것과 지표 오류를 고치는 것은 다릅니다.

## 마무리 자가 점검

1. `WHERE`와 `HAVING`은 무엇이 다른가?
2. `COUNT(*)`와 `COUNT(amount_usd)`는 언제 달라지는가?
3. LEFT JOIN에서 거래가 없는 고객은 어떻게 보이는가?
4. 음수 금액을 제외하면 순거래액과 어떤 차이가 생기는가?
5. 결과가 실행됐다는 사실만으로 정답임을 알 수 있는가?

이 중 세 가지를 자신의 말로 설명할 수 있으면 [1주차 강의](week1/lecture.md)를 시작할 준비가 됐습니다. 어려운 항목은 정답을 외우기보다 작은 표의 행을 직접 세어 보세요.

출처: 제공된 강의계획서 선수 지식 안내. [GoogleSQL 쿼리 구문](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/query-syntax), [집계 함수](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/aggregate_functions), [SAFE_DIVIDE](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/mathematical_functions). 표와 수치는 교육용 가상 예시.
