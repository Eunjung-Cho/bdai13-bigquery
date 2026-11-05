-- Source: reference/query-execution-order.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
SELECT
    t.user_id,
    SAFE_CAST(REPLACE(t.amount, "$", "") AS NUMERIC)   AS amount_usd
FROM `bdai13-bigquery.tabformer.transactions` AS t
WHERE amount_usd > 1000        -- 오류: amount_usd를 아직 모른다


-- Example 2
SELECT
    t.user_id,
    SAFE_CAST(REPLACE(t.amount, "$", "") AS NUMERIC)   AS amount_usd
FROM `bdai13-bigquery.tabformer.transactions` AS t
WHERE SAFE_CAST(REPLACE(t.amount, "$", "") AS NUMERIC) > 1000


-- Example 3
WITH clean AS (        -- 한 행 = 거래 1건 (금액 정제)
    SELECT
        t.user_id,
        SAFE_CAST(REPLACE(t.amount, "$", "") AS NUMERIC)   AS amount_usd
    FROM `bdai13-bigquery.tabformer.transactions` AS t
)
SELECT c.user_id, c.amount_usd
FROM clean AS c
WHERE c.amount_usd > 1000      -- 안쪽 SELECT가 이미 끝났으므로 사용 가능


-- Example 4
SELECT
    t.mcc,
    COUNT(*)   AS tx_cnt
FROM `bdai13-bigquery.tabformer.transactions` AS t
WHERE t.year = 2018            -- 2018년 거래만 남긴다 (행 단위)
GROUP BY t.mcc
HAVING COUNT(*) >= 10000       -- 1만 건 이상인 업종만 남긴다 (그룹 단위)


-- Example 5
SELECT
    c.mcc,
    c.merchant_city,
    RANK() OVER (PARTITION BY c.mcc ORDER BY c.spend DESC)   AS rk
FROM city_spend AS c
WHERE rk <= 3                  -- 오류: 순위는 아직 계산되지 않았다


-- Example 6
WITH ranked AS (
    SELECT
        c.mcc,
        c.merchant_city,
        RANK() OVER (PARTITION BY c.mcc ORDER BY c.spend DESC)   AS rk
    FROM city_spend AS c
)
SELECT r.mcc, r.merchant_city
FROM ranked AS r
WHERE r.rk <= 3


-- Example 7
SELECT c.mcc, c.merchant_city
FROM city_spend AS c
QUALIFY RANK() OVER (PARTITION BY c.mcc ORDER BY c.spend DESC) <= 3


-- Example 8
-- Top 10이 아니라 "아무 10행"
SELECT t.mcc, COUNT(*) AS tx_cnt
FROM `bdai13-bigquery.tabformer.transactions` AS t
GROUP BY t.mcc
LIMIT 10;

-- 이것이 Top 10
SELECT t.mcc, COUNT(*) AS tx_cnt
FROM `bdai13-bigquery.tabformer.transactions` AS t
GROUP BY t.mcc
ORDER BY tx_cnt DESC
LIMIT 10;


-- Example 9
SELECT
    u.gender,
    COUNT(*)                    AS tx_cnt,
    ROUND(AVG(c.amount_usd), 2) AS avg_amount
FROM `YOUR_PROJECT.bdai13.silver_transactions` AS c
INNER JOIN `bdai13-bigquery.tabformer.users` AS u
    ON c.user_id = u.user_id
WHERE c.tx_date >= DATE "2018-01-01"
GROUP BY u.gender
HAVING COUNT(*) >= 1000
ORDER BY avg_amount DESC
LIMIT 10;


-- Example 10
-- 나이대별로 묶는 패턴 (BigQuery에서 동작)
SELECT
    CASE
        WHEN u.current_age < 30 THEN "20대 이하"
        WHEN u.current_age < 40 THEN "30대"
        ELSE "40대 이상"
    END        AS age_group,
    COUNT(*)   AS tx_cnt
FROM `bdai13-bigquery.tabformer.transactions` AS t
INNER JOIN `bdai13-bigquery.tabformer.users` AS u
    ON t.user_id = u.user_id
GROUP BY age_group       -- 별칭으로 묶기 (BigQuery 허용)
ORDER BY tx_cnt DESC     -- 별칭으로 정렬
