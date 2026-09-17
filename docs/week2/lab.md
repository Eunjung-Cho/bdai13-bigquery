# 2주차 실습 / 지표를 계산하고 검증하기

[강의](lecture.md) / [과제](assignment.md) / [지표 정의서](../templates/metric-spec.md)

실습 70분입니다. 완성 SQL을 먼저 실행하고 조건 한 곳을 바꾸는 방식으로 진행합니다. 아래 코드의 원본 프로젝트는 `bdai13-bigquery`입니다. 모든 결과 수치는 직접 실행해서 기록합니다.

## A. 어느 업종의 순거래액이 큰가 / 25분

2018년 거래 중 날짜와 금액을 읽을 수 있고, 수업에서 정한 승인 조건에 맞는 거래를 고릅니다. 환불 금액도 포함합니다. 결과는 업종 코드(MCC)마다 한 줄입니다. 업종 코드와 이름을 연결한 표가 없다면 코드를 그대로 쓰세요.

1. 지표 정의서에서 기간, 환불, 분모를 확인합니다.
2. 아래 SQL을 실행하고 출력 열을 읽습니다.
3. Top 10을 Top 5로 한 곳만 바꿉니다. 전체 합계가 바뀐 것인지 화면에 남긴 업종만 달라진 것인지 설명합니다.

<details markdown="1"><summary>업종 Top 10 참고 SQL</summary>

```sql
WITH clean AS (
    SELECT user_id, mcc, errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d', FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date,
        CASE WHEN use_chip = 'Online Transaction' THEN '온라인'
             WHEN use_chip IN ('Swipe Transaction', 'Chip Transaction') THEN '오프라인'
             ELSE '미분류' END AS channel,
        CASE WHEN LOWER(TRIM(is_fraud)) = 'yes' THEN TRUE
             WHEN LOWER(TRIM(is_fraud)) = 'no' THEN FALSE
             ELSE NULL END AS fraud_flag
    FROM `bdai13-bigquery.tabformer.transactions`
), base AS (
    SELECT * FROM clean
    WHERE tx_date >= DATE '2018-01-01' AND tx_date < DATE '2019-01-01'
        AND amount_usd IS NOT NULL
        AND (errors IS NULL OR TRIM(errors) = '')
)
SELECT mcc, SUM(amount_usd) AS net_amount_usd,
    COUNT(*) AS txn_count, COUNT(DISTINCT user_id) AS active_user_count,
    SAFE_DIVIDE(SUM(amount_usd), COUNT(*)) AS amount_per_txn
FROM base
GROUP BY mcc
ORDER BY net_amount_usd DESC, mcc ASC NULLS LAST
LIMIT 10;
```

</details>

`LIMIT`를 제거한 전체 업종 결과의 금액과 거래 건수를 합하면 아래 기준값과 같아야 합니다. Top 10만 남긴 결과는 전체 합과 같을 필요가 없습니다. 업종별 고유 고객 수는 중복 고객이 있으므로 합산하지 않습니다.

<details markdown="1"><summary>전체 기준값 참고 SQL</summary>

```sql
WITH clean AS (
    SELECT user_id, mcc, errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d', FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date,
        CASE WHEN use_chip = 'Online Transaction' THEN '온라인'
             WHEN use_chip IN ('Swipe Transaction', 'Chip Transaction') THEN '오프라인'
             ELSE '미분류' END AS channel,
        CASE WHEN LOWER(TRIM(is_fraud)) = 'yes' THEN TRUE
             WHEN LOWER(TRIM(is_fraud)) = 'no' THEN FALSE
             ELSE NULL END AS fraud_flag
    FROM `bdai13-bigquery.tabformer.transactions`
), base AS (
    SELECT * FROM clean
    WHERE tx_date >= DATE '2018-01-01' AND tx_date < DATE '2019-01-01'
        AND amount_usd IS NOT NULL
        AND (errors IS NULL OR TRIM(errors) = '')
)
SELECT COUNT(*) AS txn_count, SUM(amount_usd) AS net_amount_usd,
    COUNT(DISTINCT user_id) AS active_user_count
FROM base;
```

</details>

**설명할 것:** 거래액 1위가 고객 수 1위와 같지 않다면 어떤 추가 질문을 할 수 있나요? 이 결과만으로 수익성이 가장 높다고 말할 수 있나요?

## B. 2018년 월별 추이는 어떤가 / 20분

한 행을 월로 바꿉니다. 나머지 정의는 A와 같습니다. 월별 합계의 합과 A의 전체 기준값을 비교해야 하므로 WHERE 조건을 임의로 바꾸지 않습니다.

<details markdown="1"><summary>월별 추이 참고 SQL</summary>

```sql
WITH clean AS (
    SELECT user_id, mcc, errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d', FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date,
        CASE WHEN use_chip = 'Online Transaction' THEN '온라인'
             WHEN use_chip IN ('Swipe Transaction', 'Chip Transaction') THEN '오프라인'
             ELSE '미분류' END AS channel,
        CASE WHEN LOWER(TRIM(is_fraud)) = 'yes' THEN TRUE
             WHEN LOWER(TRIM(is_fraud)) = 'no' THEN FALSE
             ELSE NULL END AS fraud_flag
    FROM `bdai13-bigquery.tabformer.transactions`
), base AS (
    SELECT * FROM clean
    WHERE tx_date >= DATE '2018-01-01' AND tx_date < DATE '2019-01-01'
        AND amount_usd IS NOT NULL
        AND (errors IS NULL OR TRIM(errors) = '')
)
SELECT DATE_TRUNC(tx_date, MONTH) AS tx_month,
    SUM(amount_usd) AS net_amount_usd, COUNT(*) AS txn_count,
    COUNT(DISTINCT user_id) AS active_user_count,
    SAFE_DIVIDE(SUM(amount_usd), COUNT(*)) AS amount_per_txn
FROM base
GROUP BY tx_month
ORDER BY tx_month;
```

</details>

날짜가 아닌 월 번호만 쓰면 여러 연도 자료를 분석할 때 서로 다른 해의 같은 월이 섞일 수 있습니다. `DATE_TRUNC`는 날짜를 그달의 1일로 바꿉니다. 예를 들어 2018년 3월 15일을 2018년 3월 1일로 바꾸므로 같은 달끼리 묶으면서 연도도 구별할 수 있습니다. 어떤 달이 없으면 0건이라고 바로 확정하지 말고 원본 기간과 적재 범위를 확인합니다. 월 달력 보완은 4주차에 배웁니다.

**한 곳 수정:** `MONTH`를 `YEAR`로 바꿔 2018년 한 행이 되는지 확인합니다. 다시 MONTH로 되돌리고 결과를 저장합니다. 거래액이 큰 달의 건수와 거래당 금액을 함께 읽어 보세요.

## C. 채널별 사기율을 어떤 분모로 계산할까 / 25분

라벨은 사기인지 아닌지 표시한 값입니다. 사기율을 구할 때는 Yes 또는 No를 알 수 있는 거래 건수로 나눕니다. 이 건수가 분모입니다. 금액, 기간, 승인 조건은 앞과 같고, NULL 라벨은 전체 거래 건수에는 남지만 사기율 분모에서는 제외합니다.

<details markdown="1"><summary>채널과 라벨 검증 참고 SQL</summary>

```sql
WITH clean AS (
    SELECT user_id, mcc, errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d', FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date,
        CASE WHEN use_chip = 'Online Transaction' THEN '온라인'
             WHEN use_chip IN ('Swipe Transaction', 'Chip Transaction') THEN '오프라인'
             ELSE '미분류' END AS channel,
        CASE WHEN LOWER(TRIM(is_fraud)) = 'yes' THEN TRUE
             WHEN LOWER(TRIM(is_fraud)) = 'no' THEN FALSE
             ELSE NULL END AS fraud_flag
    FROM `bdai13-bigquery.tabformer.transactions`
), base AS (
    SELECT * FROM clean
    WHERE tx_date >= DATE '2018-01-01' AND tx_date < DATE '2019-01-01'
        AND amount_usd IS NOT NULL
        AND (errors IS NULL OR TRIM(errors) = '')
)
SELECT channel, COUNT(*) AS txn_count,
    SUM(amount_usd) AS net_amount_usd,
    COUNTIF(fraud_flag IS TRUE) AS fraud_count,
    COUNTIF(fraud_flag IS FALSE) AS nonfraud_count,
    COUNTIF(fraud_flag IS NULL) AS unknown_label_count,
    COUNTIF(fraud_flag IS NOT NULL) AS labeled_count,
    SAFE_DIVIDE(COUNTIF(fraud_flag IS TRUE),
        COUNTIF(fraud_flag IS NOT NULL)) AS fraud_rate
FROM base
GROUP BY channel
ORDER BY channel;
```

</details>

각 행에서 `fraud_count + nonfraud_count + unknown_label_count = txn_count`인지 확인합니다. `fraud_count + nonfraud_count = labeled_count`도 확인합니다. 사기율 값이 0.01이면 1%입니다. 분모가 0이면 NULL이며 “계산 불가”입니다.

### AI 오류를 찾는 작은 실험

AI에게 같은 정의와 스키마를 제공하고 사기율 쿼리를 요청합니다. `COUNT(*)`가 분모인지, NULL을 No로 바꿨는지, 온라인 외의 값을 전부 오프라인으로 묶었는지를 봅니다. 오류가 없으면 억지로 오류를 만들지 말고 실제 확인한 항목을 기록합니다.

**틀리기 쉬운 계산:** `AVG(채널별 사기율)`은 온라인과 오프라인의 거래 건수가 달라도 두 비율을 똑같은 비중으로 평균냅니다. 강의의 가상 표에서 전체 1/3과 두 채널 평균 1/4가 왜 다른지 손으로 확인하세요.

## 실행한 뒤 남길 기록

| 검사 | 기대하는 관계 | 실제 결과 |
| --- | --- | --- |
| 전체 업종의 금액 합 | 전체 기준 금액과 같음 | 직접 기록 |
| 월별 거래 건수 합 | 전체 기준 건수와 같음 | 직접 기록 |
| 라벨 3종 합 | 채널별 거래 건수와 같음 | 직접 기록 |
| 고유 고객 수 | 업종, 월 간 단순 합산하지 않음 | 설명 |
| 쿼리 처리량 | 실행 전후 바이트 확인 | 직접 기록 |

## 막혔을 때

| 증상 | 확인할 곳 |
| --- | --- |
| 금액이 모두 NULL | 원본 amount 형식과 실제 타입 |
| DATE 함수 오류 | 날짜 변환 방법과 원본의 연도, 월, 일 |
| 월별 합계와 업종별 합계가 다름 | Top 10 제한, 승인, 기간, 금액 조건 |
| 사기율이 지나치게 작음 | NULL 라벨을 분모에 넣었는지 |
| 미분류 채널이 생김 | 실제 use_chip 값, 임의 오프라인 통합 여부 |

출처: 제공된 강의계획서 2주차. [집계 함수](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/aggregate_functions), [SAFE_DIVIDE](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/mathematical_functions).
