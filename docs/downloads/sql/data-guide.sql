-- Source: data-guide.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
WITH clean AS (
    SELECT
        user_id,
        card_id,
        SAFE.PARSE_DATE(
            '%Y-%m-%d', FORMAT('%04d-%02d-%02d', year, month, day)
        ) AS tx_date,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC)
            AS amount_usd,
        mcc,
        CASE
            WHEN use_chip = 'Online Transaction' THEN '온라인'
            WHEN use_chip IN ('Swipe Transaction', 'Chip Transaction')
                THEN '오프라인'
            ELSE '미분류'
        END AS channel,
        CASE
            WHEN LOWER(TRIM(is_fraud)) = 'yes' THEN TRUE
            WHEN LOWER(TRIM(is_fraud)) = 'no' THEN FALSE
            ELSE NULL
        END AS fraud_flag,
        errors
    FROM `bdai13-bigquery.tabformer.transactions`
)
SELECT *
FROM clean
LIMIT 20;
