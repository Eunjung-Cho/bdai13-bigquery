-- Source: week4/lecture.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
ROW_NUMBER() OVER (
    PARTITION BY age_band
    ORDER BY net_amount_usd DESC, mcc ASC NULLS LAST
) AS amount_rank


-- Example 2
WITH observed AS (
    SELECT DATE '2018-01-01' AS tx_month, NUMERIC '100' AS amount
    UNION ALL
    SELECT DATE '2018-03-01', NUMERIC '150'
), calendar AS (
    SELECT tx_month
    FROM UNNEST(GENERATE_DATE_ARRAY(
        DATE '2018-01-01', DATE '2018-03-01', INTERVAL 1 MONTH
    )) AS tx_month
), filled AS (
    SELECT c.tx_month, COALESCE(o.amount, NUMERIC '0') AS amount
    FROM calendar AS c LEFT JOIN observed AS o USING (tx_month)
), compared AS (
    SELECT *, LAG(amount) OVER (ORDER BY tx_month) AS previous_amount
    FROM filled
)
SELECT *, SAFE_DIVIDE(amount - previous_amount, previous_amount) AS mom_rate
FROM compared ORDER BY tx_month;
