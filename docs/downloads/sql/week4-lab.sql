-- Source: week4/lab.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
WITH clean AS (
    SELECT user_id, mcc, errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d',
            FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date
    FROM `finda-13-2026.tabformer.transactions`
), base AS (
    SELECT * FROM clean
    WHERE tx_date >= DATE '2018-01-01' AND tx_date < DATE '2019-01-01'
        AND amount_usd IS NOT NULL AND (errors IS NULL OR TRIM(errors) = '')
), enriched AS (
    SELECT t.mcc, t.amount_usd,
        CASE WHEN u.current_age IS NULL OR u.current_age < 0 THEN '연령 미상'
            ELSE CONCAT(CAST(DIV(u.current_age, 10) * 10 AS STRING), '대')
        END AS age_band
    FROM base AS t
    LEFT JOIN `finda-13-2026.tabformer.users` AS u ON t.user_id = u.user_id
), grouped AS (
    SELECT age_band, mcc, SUM(amount_usd) AS net_amount_usd,
        COUNT(*) AS txn_count
    FROM enriched GROUP BY age_band, mcc
), ranked AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY age_band
        ORDER BY net_amount_usd DESC, mcc ASC NULLS LAST
    ) AS amount_rank
    FROM grouped
)
SELECT age_band, amount_rank, mcc, net_amount_usd, txn_count
FROM ranked WHERE amount_rank <= 5
ORDER BY age_band, amount_rank;


-- Example 2
WITH clean AS (
    SELECT errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d',
            FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date,
        CASE WHEN use_chip = 'Online Transaction' THEN '온라인'
            WHEN use_chip IN ('Swipe Transaction', 'Chip Transaction') THEN '오프라인'
            ELSE '미분류' END AS channel
    FROM `finda-13-2026.tabformer.transactions`
), base AS (
    SELECT * FROM clean
    WHERE tx_date >= DATE '2018-01-01' AND tx_date < DATE '2019-01-01'
        AND amount_usd IS NOT NULL AND (errors IS NULL OR TRIM(errors) = '')
), monthly AS (
    SELECT DATE_TRUNC(tx_date, MONTH) AS tx_month, channel,
        SUM(amount_usd) AS net_amount_usd, COUNT(*) AS txn_count
    FROM base GROUP BY tx_month, channel
), calendar AS (
    SELECT tx_month
    FROM UNNEST(GENERATE_DATE_ARRAY(
        DATE '2018-01-01', DATE '2018-12-01', INTERVAL 1 MONTH
    )) AS tx_month
), channels AS (
    SELECT channel FROM UNNEST(['온라인', '오프라인', '미분류']) AS channel
), filled AS (
    SELECT c.tx_month, s.channel,
        COALESCE(m.net_amount_usd, NUMERIC '0') AS net_amount_usd,
        COALESCE(m.txn_count, 0) AS txn_count
    FROM calendar AS c CROSS JOIN channels AS s
    LEFT JOIN monthly AS m
        ON c.tx_month = m.tx_month AND s.channel = m.channel
), lagged AS (
    SELECT *, LAG(net_amount_usd) OVER (
        PARTITION BY channel ORDER BY tx_month
    ) AS previous_amount_usd
    FROM filled
)
SELECT tx_month, channel, net_amount_usd, txn_count, previous_amount_usd,
    net_amount_usd - previous_amount_usd AS change_usd,
    SAFE_DIVIDE(net_amount_usd - previous_amount_usd, previous_amount_usd) AS mom_rate
FROM lagged
ORDER BY tx_month, channel;


-- Example 3
SELECT tx_month, SUM(net_amount_usd) AS total_amount_usd,
    SUM(previous_amount_usd) AS previous_total_usd,
    SUM(net_amount_usd - previous_amount_usd) AS total_change_usd,
    SAFE_DIVIDE(SUM(net_amount_usd) - SUM(previous_amount_usd),
        SUM(previous_amount_usd)) AS total_mom_rate
FROM lagged GROUP BY tx_month ORDER BY tx_month;


-- Example 4
WITH clean AS (
    SELECT user_id, errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d',
            FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date
    FROM `finda-13-2026.tabformer.transactions`
), last_seen AS (
    SELECT user_id, MAX(tx_date) AS last_tx_date
    FROM clean
    WHERE tx_date < DATE '2019-01-01' AND amount_usd IS NOT NULL
        AND (errors IS NULL OR TRIM(errors) = '')
    GROUP BY user_id
), classified AS (
    SELECT u.user_id, l.last_tx_date,
        DATE_DIFF(DATE '2019-01-01', l.last_tx_date, DAY) AS days_since_last,
        CASE WHEN l.last_tx_date IS NULL THEN '관측 이력 없음'
            WHEN DATE_DIFF(DATE '2019-01-01', l.last_tx_date, DAY) >= 90
                THEN '90일 이상 미거래 후보'
            ELSE '90일 미만 거래 관측' END AS activity_status
    FROM `finda-13-2026.tabformer.users` AS u
    LEFT JOIN last_seen AS l ON u.user_id = l.user_id
)
SELECT activity_status, COUNT(*) AS user_count,
    MIN(days_since_last) AS min_days, MAX(days_since_last) AS max_days
FROM classified GROUP BY activity_status ORDER BY activity_status;


-- Example 5
SELECT user_id, last_tx_date, days_since_last
FROM classified
WHERE activity_status = '90일 이상 미거래 후보'
ORDER BY days_since_last DESC, user_id;
