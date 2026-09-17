# 4주차 실습. 순위, 변화, 미거래를 정의하기

[강의](lecture.md) / [과제](assignment.md) / [AI 검증](../reference/ai-verification.md)

아래 SQL은 독립 실행용입니다. 테이블 경로는 `finda-13-2026.tabformer`이며 실제 권한과 공유 상태는 [환경 준비](../setup.md)를 확인합니다. 각 실행 전 처리 바이트를 확인하고, 결과 수치와 실행 조건을 기록하세요.

완성 SQL을 먼저 펼쳐 실행합니다. 첫 실행 뒤에는 **한 곳만 바꿔 보세요**. Top 5를 Top 3으로, 휴면 90일을 180일로 바꾼 다음 원래 조건으로 돌아옵니다. 월 달력을 만드는 코드는 제공된 틀을 사용해도 됩니다. 기본 과제는 결과와 정의를 설명하는 것이며 전체 쿼리 암기는 요구하지 않습니다.

## 실습 1. 각 연령대가 가장 많이 쓴 MCC는? — 20분

**질문:** 고객 표의 나이로 나눈 연령대마다, 2018년 순거래액이 큰 업종 5개는 무엇인가?

**조건:** 유효 금액, 교육용 승인 조건, 환불 포함. 연령 미상을 남기고, 동액이면 MCC 오름차순으로 결정합니다. 한 연령대에 업종이 5개 미만이면 있는 만큼만 나옵니다. MCC는 분류 코드이므로 검증되지 않은 업종 이름을 AI에게 임의로 붙이게 하지 않습니다.

- (1) 집계 결과의 한 행이 연령대 × MCC인지 확인합니다.
- (2) 순위가 연령대마다 1부터 다시 시작하도록 만듭니다.
- (3) 상위 5개를 선택한 뒤 한 연령대의 전체 집계와 대조합니다.

<details markdown="1">
<summary>연령대별 Top 5 참고 SQL</summary>

```sql
WITH clean AS (
    SELECT user_id, mcc, errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d',
            FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date
    FROM `finda-13-2026.tabformer.transactions`
), base AS (
    SELECT * FROM clean
    WHERE tx_date >= DATE '2018-01-01' AND tx_date < DATE '2019-01-01'
        AND amount_usd IS NOT NULL AND (errors IS NULL OR TRIM(errors) = '')
), enriched AS (
    SELECT t.mcc, t.amount_usd,
        CASE WHEN u.current_age IS NULL OR u.current_age < 0 THEN '연령 미상'
            ELSE CONCAT(CAST(DIV(u.current_age, 10) * 10 AS STRING), '대')
        END AS age_band
    FROM base AS t
    LEFT JOIN `finda-13-2026.tabformer.users` AS u ON t.user_id = u.user_id
), grouped AS (
    SELECT age_band, mcc, SUM(amount_usd) AS net_amount_usd,
        COUNT(*) AS txn_count
    FROM enriched GROUP BY age_band, mcc
), ranked AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY age_band
        ORDER BY net_amount_usd DESC, mcc ASC NULLS LAST
    ) AS amount_rank
    FROM grouped
)
SELECT age_band, amount_rank, mcc, net_amount_usd, txn_count
FROM ranked WHERE amount_rank <= 5
ORDER BY age_band, amount_rank;
```

</details>

**검증:** 먼저 3주차 SQL로 users의 고객 번호가 겹치지 않는지 확인합니다. 최종 SELECT를 `SELECT * FROM grouped`로 바꿔 Top 5 선택 전 총합을 기준값과 대조합니다. Top 5 결과는 일부 행만 남긴 것이므로 그 금액 합이 전체 금액과 같을 필요는 없습니다. 같은 순거래액의 MCC가 있을 때 지정한 순서로 나오는지도 확인합니다.

**해석:** 한 연령대의 1위와 2위의 금액, 건수, 격차를 적습니다. 인접 연령대와 순위가 다르다는 사실은 확인할 수 있지만, 실제 고객 전체의 선호도라고 일반화하지 않습니다. 인공적으로 만든 데이터라는 점과, 나이가 거래 당시가 아닌 고객 정보 저장 시점의 값이라는 점도 적습니다.

## 실습 2. 전체 월별 변화는 어느 채널에서 왔는가? — 25분

**질문:** 2018년 월별 순거래액과 전월 대비 증감액/증감률을 구하고 온라인, 오프라인, 미분류 채널의 증감액 합이 전체 변화와 일치하는가?

**조건:** 12개월 × 3채널 = 36행을 먼저 만들고, 각 채널 안에서 LAG를 계산합니다. 1월은 2017년 12월을 읽지 않았으므로 전월 값과 변화율이 NULL입니다. 어떤 달이 표에 없으면, 거래가 없었던 것인지 데이터가 빠진 것인지 먼저 확인합니다. 실제로 거래가 없었던 달만 0으로 채웁니다.

<details markdown="1">
<summary>월 달력과 채널별 변화 참고 SQL</summary>

```sql
WITH clean AS (
    SELECT errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d',
            FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date,
        CASE WHEN use_chip = 'Online Transaction' THEN '온라인'
            WHEN use_chip IN ('Swipe Transaction', 'Chip Transaction') THEN '오프라인'
            ELSE '미분류' END AS channel
    FROM `finda-13-2026.tabformer.transactions`
), base AS (
    SELECT * FROM clean
    WHERE tx_date >= DATE '2018-01-01' AND tx_date < DATE '2019-01-01'
        AND amount_usd IS NOT NULL AND (errors IS NULL OR TRIM(errors) = '')
), monthly AS (
    SELECT DATE_TRUNC(tx_date, MONTH) AS tx_month, channel,
        SUM(amount_usd) AS net_amount_usd, COUNT(*) AS txn_count
    FROM base GROUP BY tx_month, channel
), calendar AS (
    SELECT tx_month
    FROM UNNEST(GENERATE_DATE_ARRAY(
        DATE '2018-01-01', DATE '2018-12-01', INTERVAL 1 MONTH
    )) AS tx_month
), channels AS (
    SELECT channel FROM UNNEST(['온라인', '오프라인', '미분류']) AS channel
), filled AS (
    SELECT c.tx_month, s.channel,
        COALESCE(m.net_amount_usd, NUMERIC '0') AS net_amount_usd,
        COALESCE(m.txn_count, 0) AS txn_count
    FROM calendar AS c CROSS JOIN channels AS s
    LEFT JOIN monthly AS m
        ON c.tx_month = m.tx_month AND s.channel = m.channel
), lagged AS (
    SELECT *, LAG(net_amount_usd) OVER (
        PARTITION BY channel ORDER BY tx_month
    ) AS previous_amount_usd
    FROM filled
)
SELECT tx_month, channel, net_amount_usd, txn_count, previous_amount_usd,
    net_amount_usd - previous_amount_usd AS change_usd,
    SAFE_DIVIDE(net_amount_usd - previous_amount_usd, previous_amount_usd) AS mom_rate
FROM lagged
ORDER BY tx_month, channel;
```

</details>

`mom_rate=0.12`라면 표시할 때 12%입니다. SQL 값에 이미 100을 곱한 뒤 시각화에서 다시 백분율 서식을 적용하지 않습니다. 이전 순거래액이 음수이면 일반적인 성장률 해석이 어려우므로 원래 금액과 증감액을 중심으로 설명하고 음수 분모를 표시합니다.

**네 가지 검증**

- (1) 36행인지, `(tx_month, channel)` 중복이 없는지 확인합니다.
- (2) 채널별 12개월이 있고 1월 previous_amount_usd가 NULL인지 확인합니다.
- (3) 전체 net_amount_usd 합이 원본 base의 순거래액 합과 같은지 확인합니다.
- (4) 한 달을 골라 세 채널 증감액을 합하고, 두 달 전체 순거래액 차이와 대조합니다.

<details markdown="1">
<summary>전체 월별 변화와의 대조용 마지막 SELECT</summary>

위 쿼리에서 `lagged` CTE까지 유지하고, 마지막 SELECT만 아래로 바꿉니다. 동일 원본/필터/달력을 쓰는 대조입니다.

```sql
SELECT tx_month, SUM(net_amount_usd) AS total_amount_usd,
    SUM(previous_amount_usd) AS previous_total_usd,
    SUM(net_amount_usd - previous_amount_usd) AS total_change_usd,
    SAFE_DIVIDE(SUM(net_amount_usd) - SUM(previous_amount_usd),
        SUM(previous_amount_usd)) AS total_mom_rate
FROM lagged GROUP BY tx_month ORDER BY tx_month;
```

</details>

총 변화가 0인 달에는 채널별 증감액/전체 증감액이라는 기여율을 계산하지 않습니다. 온라인은 늘고 오프라인은 줄어 두 변화가 서로 줄여 주는 경우가 있습니다. 이때 각 채널의 증감액을 전체 증감액으로 나눈 비율은 음수이거나 100%보다 클 수 있습니다. 처음에는 증감액 자체를 보여주는 편이 해석에 도움이 됩니다.

## 실습 3. 기준일에 90일 이상 거래가 없는 고객은? — 20분

**질문:** 2019-01-01 직전까지의 기록으로 90일 이상 미거래 후보, 90일 미만 거래 관측, 관측 이력 없음을 구분할 수 있는가?

2018년 필터를 그대로 복사하지 않습니다. 이 질문은 기준일 이전 전체 이력에서 마지막 유효 거래를 찾습니다. 환불도 유효 거래에 포함하는 정의를 유지합니다. 신규 여부와 실제 이탈 여부는 제공 열으로 확정할 수 없습니다.

<details markdown="1">
<summary>기준일 고객 분류 참고 SQL</summary>

```sql
WITH clean AS (
    SELECT user_id, errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d',
            FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date
    FROM `finda-13-2026.tabformer.transactions`
), last_seen AS (
    SELECT user_id, MAX(tx_date) AS last_tx_date
    FROM clean
    WHERE tx_date < DATE '2019-01-01' AND amount_usd IS NOT NULL
        AND (errors IS NULL OR TRIM(errors) = '')
    GROUP BY user_id
), classified AS (
    SELECT u.user_id, l.last_tx_date,
        DATE_DIFF(DATE '2019-01-01', l.last_tx_date, DAY) AS days_since_last,
        CASE WHEN l.last_tx_date IS NULL THEN '관측 이력 없음'
            WHEN DATE_DIFF(DATE '2019-01-01', l.last_tx_date, DAY) >= 90
                THEN '90일 이상 미거래 후보'
            ELSE '90일 미만 거래 관측' END AS activity_status
    FROM `finda-13-2026.tabformer.users` AS u
    LEFT JOIN last_seen AS l ON u.user_id = l.user_id
)
SELECT activity_status, COUNT(*) AS user_count,
    MIN(days_since_last) AS min_days, MAX(days_since_last) AS max_days
FROM classified GROUP BY activity_status ORDER BY activity_status;
```

</details>

이번에 분류하는 대상은 users 표에 있는 모든 고객입니다. 세 그룹의 고객 수를 더하면 users의 행 수와 같아야 합니다. 단, 같은 고객 번호가 여러 줄에 있으면 고객을 두 번 셀 수 있으므로 번호 중복부터 확인합니다. 관측 이력 없음의 min/max는 NULL이고, 미거래 후보의 min_days는 90 이상이어야 합니다.

<details markdown="1">
<summary>분류한 고객을 확인하는 마지막 SELECT</summary>

동일 쿼리의 `classified` CTE까지 유지하고 마지막 SELECT를 아래로 바꿉니다. 개인별 결과는 비공개 실습 화면에서만 확인하고 보고서에는 집계만 사용합니다.

```sql
SELECT user_id, last_tx_date, days_since_last
FROM classified
WHERE activity_status = '90일 이상 미거래 후보'
ORDER BY days_since_last DESC, user_id;
```

</details>

**경계 검사:** 강의의 2018-10-03과 2018-10-04 가상 날짜를 DATE_DIFF로 계산하여 90일/89일을 확인합니다. 마지막 거래가 없는 고객을 9999일로 치환하지 않습니다. 미래 거래가 last_seen에 포함되지 않는지 WHERE 조건을 읽습니다.

## 실습 4. AI가 요약한 문장을 증거와 연결하기 — 15분

실습 2의 집계 결과와 지표 정의를 AI에 전달합니다. “관찰 3개, 아직 확인할 수 없는 원인 2개, 추가 분석 1개를 구분해 달라”고 요청합니다. [분석 리포트](../templates/analysis-report.md)에 아래 형태로 기록합니다.

| AI 문장 | 근거가 되는 행/열 | 판정 | 수정 문장 |
| --- | --- | --- | --- |
| 실제 생성 결과를 붙임 | 실제 월, 채널, 값 | 유지/수정/근거 없음 | 범위를 좁혀 다시 씀 |

**교육용 오류 찾기:** “전체가 10% 줄었으므로 온라인도 줄었고, 고객 이탈이 원인이다.” 강의의 가상 표를 기준으로 어떤 부분이 맞고 어떤 부분이 근거가 없는지 표시하세요.

<details markdown="1">
<summary>오류 찾기 해설</summary>

전체 -10%는 맞습니다. 온라인은 +40%이므로 감소했다는 방향이 틀립니다. 이탈 원인은 이 표로 확인할 수 없습니다.

</details>

프로젝트 초안에는 질문 한 개와 검증 계획 두 개를 추가합니다. 실제 결과가 기대와 달라도 질문을 몰래 바꾸지 말고, 처음 가설과 달랐다는 점을 기록합니다.

## 막혔을 때

| 증상 | 확인과 수정 |
| --- | --- |
| 연령대마다 5개가 아니라 전체 5개만 나옴 | PARTITION BY와 최종 LIMIT 혼동 확인 |
| Top 5의 전체 합이 기준보다 작음 | 선택 전 grouped의 합계로 보존 검사 |
| 3월 전월 값이 1월 | 달력 누락 보완 후 LAG |
| 채널 간 전월 값이 섞임 | LAG에 PARTITION BY channel 추가 |
| 증감률 NULL | 첫 월/0 분모인지 구분; 0으로 대체하지 않음 |
| 모든 고객이 휴면 후보처럼 나옴 | CURRENT_DATE 사용 여부, 기준일과 데이터 시계 확인 |
| 거래 이력이 없는데 미거래 90일로 분류됨 | NULL 분기를 먼저 두고 별도 그룹 유지 |

## 출처

- 제공 강의계획서, 4주차 실습 및 AI 교차 확인.
- [ROW_NUMBER](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/numbering_functions#row_number), [LAG](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/navigation_functions#lag).
- [GENERATE_DATE_ARRAY](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/array_functions#generate_date_array), [DATE_DIFF](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/date_functions#date_diff).
