-- Source: week6/lab.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
SELECT
    SUM(amount_usd) AS net_amount_usd,
    SUM(txn_count) AS txn_count,
    SUM(fraud_count) AS fraud_count,
    SUM(fraud_labeled_count) AS labeled_count,
    SAFE_DIVIDE(SUM(amount_usd), SUM(txn_count)) AS amount_per_txn,
    SAFE_DIVIDE(SUM(fraud_count), SUM(fraud_labeled_count)) AS fraud_rate
FROM `YOUR_PROJECT.bdai13.mart_monthly_mcc`
WHERE tx_month >= DATE '2018-01-01' AND tx_month < DATE '2019-01-01';
