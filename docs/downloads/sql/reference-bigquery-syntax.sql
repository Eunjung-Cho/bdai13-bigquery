-- Source: reference/bigquery-syntax.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
SELECT
    t.mcc,
    COUNT(*)   AS tx_cnt
FROM `bdai13-bigquery.tabformer.transactions` AS t
WHERE t.year = 2018
GROUP BY t.mcc
ORDER BY tx_cnt DESC
LIMIT 10;


-- Example 2
SELECT
    u.gender,
    COUNT(*)   AS tx_cnt
FROM `bdai13-bigquery.tabformer.transactions` AS t
INNER JOIN `bdai13-bigquery.tabformer.users` AS u
    ON t.user_id = u.user_id
GROUP BY u.gender;


-- Example 3
SELECT
    COUNTIF(t.is_fraud = "Yes")                        AS fraud_cnt,       -- BigQuery
    COUNT(CASE WHEN t.is_fraud = "Yes" THEN 1 END)     AS fraud_cnt_std    -- 다른 DB에서도 통하는 방식
FROM `bdai13-bigquery.tabformer.transactions` AS t;


-- Example 4
SAFE_CAST(REPLACE(t.amount, "$", "") AS NUMERIC)   AS amount_usd


-- Example 5
CASE
    WHEN u.current_age < 30 THEN "20대 이하"
    WHEN u.current_age < 40 THEN "30대"
    WHEN u.current_age < 50 THEN "40대"
    ELSE "50대 이상"
END   AS age_group


-- Example 6
SELECT COUNT(*) AS tx_cnt
FROM `bdai13-bigquery.tabformer.transactions` AS t
WHERE t.year = 2018 AND t.month = 12     -- 조립 불필요


-- Example 7
SELECT
    t.use_chip,
    COUNT(*)                                                 AS tx_cnt,
    COUNTIF(t.is_fraud = "Yes")                              AS fraud_cnt,
    ROUND(COUNTIF(t.is_fraud = "Yes") / COUNT(*) * 100, 3)   AS fraud_rate_pct
FROM `bdai13-bigquery.tabformer.transactions` AS t
GROUP BY t.use_chip
ORDER BY fraud_rate_pct DESC;
