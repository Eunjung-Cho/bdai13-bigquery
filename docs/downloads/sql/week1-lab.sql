-- Source: week1/lab.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
SELECT
  user_id,
  card_id,
  amount,
  use_chip
FROM `finda-13-2026.tabformer.transactions`
LIMIT 10;


-- Example 2
SELECT user_id
FROM `finda-13-2026.tabformer.transactions`
LIMIT 10;


-- Example 3
SELECT
  COUNT(*) AS row_count,
  COUNT(DISTINCT user_id) AS observed_user_count,
  COUNTIF(user_id IS NULL) AS missing_user_rows,
  COUNTIF(amount IS NULL) AS null_amount_rows,
  COUNTIF(TRIM(amount) = '') AS blank_amount_rows,
  COUNTIF(mcc IS NULL) AS missing_mcc_rows,
  COUNTIF(year = 2018) AS year_2018_raw_rows
FROM `finda-13-2026.tabformer.transactions`;


-- Example 4
WITH profiled AS (
  SELECT
    amount,
    SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC)
      AS amount_usd,
    SAFE.PARSE_DATE(
      '%Y-%m-%d', FORMAT('%04d-%02d-%02d', year, month, day)
    ) AS tx_date
  FROM `finda-13-2026.tabformer.transactions`
)
SELECT
  COUNT(*) AS row_count,
  COUNTIF(amount_usd IS NULL) AS unusable_amount_rows,
  COUNTIF(amount_usd < 0) AS negative_amount_rows,
  COUNTIF(tx_date IS NULL) AS invalid_or_missing_date_rows,
  MIN(tx_date) AS first_valid_date,
  MAX(tx_date) AS last_valid_date,
  COUNTIF(tx_date >= DATE '2018-01-01'
    AND tx_date < DATE '2019-01-01') AS valid_2018_date_rows
FROM profiled;


-- Example 5
SELECT
  card_index,
  COUNT(*) AS card_rows,
  COUNT(DISTINCT `user`) AS user_count
FROM `finda-13-2026.tabformer.cards`
GROUP BY card_index
ORDER BY card_rows DESC
LIMIT 10;


-- Example 6
WITH dated AS (
  SELECT
    SAFE.PARSE_DATE(
      '%Y-%m-%d', FORMAT('%04d-%02d-%02d', year, month, day)
    ) AS tx_date
  FROM `finda-13-2026.tabformer.transactions`
)
SELECT
  COUNTIF(tx_date >= DATE '2018-01-01'
    AND tx_date < DATE '2019-01-01') AS valid_2018_rows,
  COUNTIF(tx_date IS NULL) AS all_invalid_or_missing_date_rows
FROM dated;


-- Example 7
SELECT COUNT(amount) AS transaction_count
FROM `finda-13-2026.tabformer.transactions`
WHERE year = 2018;
