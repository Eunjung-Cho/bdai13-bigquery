-- Source: refresher.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
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


-- Example 2
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


-- Example 3
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


-- Example 4
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


-- Example 5
WITH sample AS (
    SELECT 1 AS user_id, 100 AS amount_usd
    UNION ALL SELECT 1, -20
    UNION ALL SELECT 2, 50
)
SELECT user_id, SUM(amount_usd) AS net_amount_usd
FROM sample
GROUP BY user_id
HAVING SUM(amount_usd) >= 70;
