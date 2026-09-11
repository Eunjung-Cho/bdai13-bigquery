-- Source: reference/sql-patterns.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
SELECT
    amount,
    REPLACE(amount, '$', '') AS without_dollar,
    REPLACE(REPLACE(amount, '$', ''), ',', '') AS numeric_text,
    SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC)
        AS amount_usd
FROM `finda-13-2026.tabformer.transactions`
LIMIT 20;


-- Example 2
SELECT user, card_index, COUNT(*) AS rows_per_key
FROM `finda-13-2026.tabformer.cards`
GROUP BY user, card_index
HAVING COUNT(*) > 1;


-- Example 3
-- 질문: 고객별 카드 보유 수는?
-- 원천 한 행: 카드 1장. 결과 한 행: 고객 1명.
SELECT user AS user_id, COUNT(*) AS card_count
FROM `finda-13-2026.tabformer.cards`
GROUP BY user;
