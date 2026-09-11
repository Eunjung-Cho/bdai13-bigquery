-- Source: week3/lab.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
WITH user_duplicates AS (
    SELECT user_id
    FROM `finda-13-2026.tabformer.users`
    GROUP BY user_id
    HAVING COUNT(*) > 1
), card_duplicates AS (
    SELECT user, card_index
    FROM `finda-13-2026.tabformer.cards`
    GROUP BY user, card_index
    HAVING COUNT(*) > 1
)
SELECT
    (SELECT COUNT(*) FROM user_duplicates) AS duplicate_user_keys,
    (SELECT COUNT(*) FROM card_duplicates) AS duplicate_card_keys,
    (SELECT COUNTIF(user_id IS NULL)
        FROM `finda-13-2026.tabformer.users`) AS null_user_keys,
    (SELECT COUNTIF(user IS NULL OR card_index IS NULL)
        FROM `finda-13-2026.tabformer.cards`) AS null_card_keys;


-- Example 2
WITH clean AS (
    SELECT user_id, card_id, errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d',
            FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date
    FROM `finda-13-2026.tabformer.transactions`
), base AS (
    SELECT * FROM clean
    WHERE tx_date >= DATE '2018-01-01' AND tx_date < DATE '2019-01-01'
        AND amount_usd IS NOT NULL
        AND (errors IS NULL OR TRIM(errors) = '')
), joined AS (
    SELECT t.amount_usd, u.user_id AS matched_user, c.user AS matched_card
    FROM base AS t
    LEFT JOIN `finda-13-2026.tabformer.users` AS u ON t.user_id = u.user_id
    LEFT JOIN `finda-13-2026.tabformer.cards` AS c
        ON t.user_id = c.user AND t.card_id = c.card_index
), before_join AS (
    SELECT COUNT(*) AS rows_before, SUM(amount_usd) AS amount_before FROM base
), after_join AS (
    SELECT COUNT(*) AS rows_after, SUM(amount_usd) AS amount_after,
        COUNTIF(matched_user IS NULL) AS missing_user_rows,
        COUNTIF(matched_card IS NULL) AS missing_card_rows
    FROM joined
)
SELECT b.*, a.*,
    a.rows_after - b.rows_before AS row_difference,
    a.amount_after - b.amount_before AS amount_difference
FROM before_join AS b CROSS JOIN after_join AS a;


-- Example 3
WITH clean AS (
    SELECT user_id, errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d',
            FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date
    FROM `finda-13-2026.tabformer.transactions`
), base AS (
    SELECT * FROM clean
    WHERE tx_date >= DATE '2018-01-01' AND tx_date < DATE '2019-01-01'
        AND amount_usd IS NOT NULL AND (errors IS NULL OR TRIM(errors) = '')
), enriched AS (
    SELECT t.user_id, t.amount_usd,
        CASE WHEN u.current_age IS NULL OR u.current_age < 0 THEN '연령 미상'
            ELSE CONCAT(CAST(DIV(u.current_age, 10) * 10 AS STRING), '대')
        END AS age_band,
        COALESCE(NULLIF(TRIM(u.gender), ''), '성별 미상') AS gender
    FROM base AS t
    LEFT JOIN `finda-13-2026.tabformer.users` AS u ON t.user_id = u.user_id
)
SELECT age_band, gender, SUM(amount_usd) AS net_amount_usd,
    COUNT(*) AS txn_count, COUNT(DISTINCT user_id) AS active_user_count,
    SAFE_DIVIDE(SUM(amount_usd), COUNT(*)) AS net_amount_per_txn
FROM enriched
GROUP BY age_band, gender
ORDER BY net_amount_usd DESC, age_band, gender;


-- Example 4
WITH clean AS (
    SELECT user_id, card_id, errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d',
            FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date
    FROM `finda-13-2026.tabformer.transactions`
), used_cards AS (
    SELECT DISTINCT user_id, card_id
    FROM clean
    WHERE tx_date IS NOT NULL AND amount_usd IS NOT NULL
        AND (errors IS NULL OR TRIM(errors) = '')
), card_status AS (
    SELECT c.user, c.card_index, c.card_brand,
        t.user_id IS NULL AS is_unused
    FROM `finda-13-2026.tabformer.cards` AS c
    LEFT JOIN used_cards AS t
        ON c.user = t.user_id AND c.card_index = t.card_id
)
SELECT card_brand, COUNT(*) AS all_cards,
    COUNTIF(is_unused) AS unused_cards,
    COUNTIF(NOT is_unused) AS used_cards,
    SAFE_DIVIDE(COUNTIF(is_unused), COUNT(*)) AS unused_share
FROM card_status
GROUP BY card_brand
ORDER BY unused_cards DESC;


-- Example 5
WITH clean AS (
    SELECT user_id, errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d',
            FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date
    FROM `finda-13-2026.tabformer.transactions`
), base AS (
    SELECT * FROM clean
    WHERE tx_date >= DATE '2018-01-01' AND tx_date < DATE '2019-01-01'
        AND amount_usd IS NOT NULL AND (errors IS NULL OR TRIM(errors) = '')
), customer AS (
    SELECT user_id,
        SAFE_CAST(REPLACE(REPLACE(yearly_income, '$', ''), ',', '') AS NUMERIC) AS income_usd
    FROM `finda-13-2026.tabformer.users`
), enriched AS (
    SELECT t.user_id, t.amount_usd,
        CASE WHEN u.income_usd IS NULL OR u.income_usd < 0 THEN '0. 소득 미상'
            WHEN u.income_usd < 30000 THEN '1. 3만 미만'
            WHEN u.income_usd < 60000 THEN '2. 3만 이상 6만 미만'
            WHEN u.income_usd < 100000 THEN '3. 6만 이상 10만 미만'
            ELSE '4. 10만 이상' END AS income_band
    FROM base AS t LEFT JOIN customer AS u ON t.user_id = u.user_id
)
SELECT income_band, SUM(amount_usd) AS net_amount_usd,
    COUNT(*) AS txn_count, COUNT(DISTINCT user_id) AS active_user_count,
    SAFE_DIVIDE(SUM(amount_usd), COUNT(*)) AS net_amount_per_txn
FROM enriched
GROUP BY income_band
ORDER BY income_band;
