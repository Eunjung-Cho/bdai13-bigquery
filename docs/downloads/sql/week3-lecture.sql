-- Source: week3/lecture.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
-- 고객 속성 연결
LEFT JOIN `finda-13-2026.tabformer.users` AS u
    ON t.user_id = u.user_id
-- 카드 속성 연결: 두 조건이 한 세트입니다.
LEFT JOIN `finda-13-2026.tabformer.cards` AS c
    ON t.user_id = c.user
    AND t.card_id = c.card_index


-- Example 2
WITH tx AS (
    SELECT 10 AS user_id, 0 AS card_id, NUMERIC '100' AS amount_usd
    UNION ALL
    SELECT 10, 1, NUMERIC '50'
), cards AS (
    SELECT 10 AS user_id, 0 AS card_id
    UNION ALL
    SELECT 10, 1
), wrong_join AS (
    SELECT t.amount_usd
    FROM tx AS t
    LEFT JOIN cards AS c ON t.user_id = c.user_id
), correct_join AS (
    SELECT t.amount_usd
    FROM tx AS t
    LEFT JOIN cards AS c
        ON t.user_id = c.user_id AND t.card_id = c.card_id
)
SELECT '고객만 연결' AS method, COUNT(*) AS row_count, SUM(amount_usd) AS amount
FROM wrong_join
UNION ALL
SELECT '고객과 카드 연결', COUNT(*), SUM(amount_usd)
FROM correct_join;
