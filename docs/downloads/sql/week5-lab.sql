-- Source: week5/lab.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
CREATE OR REPLACE VIEW `YOUR_PROJECT.bdai13.v_transactions_clean` AS
SELECT
  user_id,
  card_id,
  year,
  month,
  day,
  time,
  amount AS amount_raw,
  SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC)
    AS amount_usd,
  SAFE.PARSE_DATE(
    '%Y-%m-%d',
    FORMAT('%04d-%02d-%02d', year, month, day)
  ) AS tx_date,
  use_chip,
  CASE
    WHEN use_chip = 'Online Transaction' THEN '온라인'
    WHEN use_chip IN ('Swipe Transaction', 'Chip Transaction') THEN '오프라인'
    ELSE '미분류'
  END AS channel,
  merchant_name,
  merchant_city,
  merchant_state,
  zip,
  mcc,
  errors,
  (errors IS NULL OR TRIM(errors) = '') AS approved_for_analysis,
  is_fraud AS is_fraud_raw,
  CASE
    WHEN LOWER(TRIM(is_fraud)) = 'yes' THEN TRUE
    WHEN LOWER(TRIM(is_fraud)) = 'no' THEN FALSE
    ELSE NULL
  END AS fraud_flag
FROM `bdai13-bigquery.tabformer.transactions`;


-- Example 2
SELECT
  COUNT(*) AS source_row_count,
  COUNTIF(amount_usd IS NULL) AS invalid_or_missing_amount_count,
  COUNTIF(tx_date IS NULL) AS invalid_or_missing_date_count,
  COUNTIF(fraud_flag IS NULL) AS unknown_fraud_label_count,
  COUNTIF(channel = '미분류') AS unclassified_channel_count,
  COUNTIF(approved_for_analysis) AS analysis_approved_count,
  MIN(tx_date) AS min_tx_date,
  MAX(tx_date) AS max_tx_date
FROM `YOUR_PROJECT.bdai13.v_transactions_clean`;


-- Example 3
CREATE OR REPLACE TABLE `YOUR_PROJECT.bdai13.mart_monthly_mcc`
PARTITION BY DATE_TRUNC(tx_month, MONTH)
CLUSTER BY mcc, channel
OPTIONS (
  description = '2018년 월 x MCC x 채널. 유효 금액, 승인 교육용 조건, 환불 포함 순거래액.'
)
AS
SELECT
  DATE_TRUNC(tx_date, MONTH) AS tx_month,
  mcc,
  channel,
  SUM(amount_usd) AS amount_usd,
  COUNT(*) AS txn_count,
  COUNTIF(fraud_flag) AS fraud_count,
  COUNTIF(fraud_flag IS NOT NULL) AS fraud_labeled_count
FROM `YOUR_PROJECT.bdai13.v_transactions_clean`
WHERE tx_date >= DATE '2018-01-01'
  AND tx_date < DATE '2019-01-01'
  AND amount_usd IS NOT NULL
  AND approved_for_analysis
GROUP BY tx_month, mcc, channel;


-- Example 4
-- 결과가 0행이면 월 × MCC × 채널 중복이 없습니다.
SELECT tx_month, mcc, channel, COUNT(*) AS row_count
FROM `YOUR_PROJECT.bdai13.mart_monthly_mcc`
GROUP BY tx_month, mcc, channel
HAVING COUNT(*) > 1;


-- Example 5
-- 아래 위반 건수들은 모두 0이어야 합니다.
SELECT
  COUNTIF(tx_month != DATE_TRUNC(tx_month, MONTH)) AS not_month_start,
  COUNTIF(tx_month < DATE '2018-01-01'
    OR tx_month >= DATE '2019-01-01') AS out_of_range,
  COUNTIF(txn_count <= 0) AS invalid_txn_count,
  COUNTIF(fraud_count > fraud_labeled_count) AS fraud_exceeds_labeled,
  COUNTIF(fraud_labeled_count > txn_count) AS labeled_exceeds_txn
FROM `YOUR_PROJECT.bdai13.mart_monthly_mcc`;


-- Example 6
WITH detail_total AS (
  SELECT
    SUM(amount_usd) AS amount_usd,
    COUNT(*) AS txn_count,
    COUNTIF(fraud_flag) AS fraud_count,
    COUNTIF(fraud_flag IS NOT NULL) AS fraud_labeled_count
  FROM `YOUR_PROJECT.bdai13.v_transactions_clean`
  WHERE tx_date >= DATE '2018-01-01'
    AND tx_date < DATE '2019-01-01'
    AND amount_usd IS NOT NULL
    AND approved_for_analysis
), mart_total AS (
  SELECT
    SUM(amount_usd) AS amount_usd,
    SUM(txn_count) AS txn_count,
    SUM(fraud_count) AS fraud_count,
    SUM(fraud_labeled_count) AS fraud_labeled_count
  FROM `YOUR_PROJECT.bdai13.mart_monthly_mcc`
  WHERE tx_month >= DATE '2018-01-01'
    AND tx_month < DATE '2019-01-01'
)
SELECT
  d.amount_usd - m.amount_usd AS amount_difference,
  d.txn_count - m.txn_count AS txn_difference,
  d.fraud_count - m.fraud_count AS fraud_difference,
  d.fraud_labeled_count - m.fraud_labeled_count AS labeled_difference
FROM detail_total AS d
CROSS JOIN mart_total AS m;


-- Example 7
WITH clean AS (
  SELECT
    SAFE.PARSE_DATE('%Y-%m-%d',
      FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date,
    SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC)
      AS amount_usd,
    (errors IS NULL OR TRIM(errors) = '') AS approved_for_analysis
  FROM `bdai13-bigquery.tabformer.transactions`
)
SELECT
  DATE_TRUNC(tx_date, MONTH) AS tx_month,
  SUM(amount_usd) AS amount_usd,
  COUNT(*) AS txn_count
FROM clean
WHERE tx_date >= DATE '2018-01-01'
  AND tx_date < DATE '2019-01-01'
  AND amount_usd IS NOT NULL
  AND approved_for_analysis
GROUP BY tx_month
ORDER BY tx_month;


-- Example 8
SELECT
  DATE_TRUNC(tx_date, MONTH) AS tx_month,
  SUM(amount_usd) AS amount_usd,
  COUNT(*) AS txn_count
FROM `YOUR_PROJECT.bdai13.v_transactions_clean`
WHERE tx_date >= DATE '2018-01-01'
  AND tx_date < DATE '2019-01-01'
  AND amount_usd IS NOT NULL
  AND approved_for_analysis
GROUP BY tx_month
ORDER BY tx_month;


-- Example 9
SELECT
  tx_month,
  SUM(amount_usd) AS amount_usd,
  SUM(txn_count) AS txn_count
FROM `YOUR_PROJECT.bdai13.mart_monthly_mcc`
WHERE tx_month >= DATE '2018-01-01'
  AND tx_month < DATE '2019-01-01'
GROUP BY tx_month
ORDER BY tx_month;


-- Example 10
CREATE OR REPLACE TABLE `YOUR_PROJECT.bdai13.silver_transactions`
PARTITION BY DATE_TRUNC(tx_date, MONTH)
CLUSTER BY mcc, channel
OPTIONS (
  require_partition_filter = TRUE,
  description = '2018년 유효 금액 거래. 승인 교육용 조건. 환불 포함.'
)
AS
SELECT
  tx_date, user_id, card_id, mcc, channel, amount_usd, fraud_flag
FROM `YOUR_PROJECT.bdai13.v_transactions_clean`
WHERE tx_date >= DATE '2018-01-01'
  AND tx_date < DATE '2019-01-01'
  AND amount_usd IS NOT NULL
  AND approved_for_analysis;

-- 조회에도 파티션 조건을 명시합니다.
SELECT
  mcc,
  SUM(amount_usd) AS amount_usd,
  COUNT(*) AS txn_count
FROM `YOUR_PROJECT.bdai13.silver_transactions`
WHERE tx_date >= DATE '2018-10-01'
  AND tx_date < DATE '2018-11-01'
GROUP BY mcc
ORDER BY amount_usd DESC;
