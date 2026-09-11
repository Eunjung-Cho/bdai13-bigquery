-- Source: week5/lecture.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC)


-- Example 2
SAFE.PARSE_DATE(
  '%Y-%m-%d',
  FORMAT('%04d-%02d-%02d', year, month, day)
)


-- Example 3
CREATE OR REPLACE TABLE `YOUR_PROJECT.bdai13.mart_monthly_mcc`
PARTITION BY DATE_TRUNC(tx_month, MONTH)
CLUSTER BY mcc, channel
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
