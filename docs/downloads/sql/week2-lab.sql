-- Source: week2/lab.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
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


-- Example 2
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


-- Example 3
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


-- Example 4
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
