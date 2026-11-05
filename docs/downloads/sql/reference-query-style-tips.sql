-- Source: reference/query-style-tips.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
select
  user_id,
  sum(amount)
from transactions
where year = 2018


-- Example 2
SELECT
  user_id,
  SUM(amount) AS total_amount
FROM transactions
WHERE year = 2018


-- Example 3
SELECT user_id, card_id, amount, merchant_city, merchant_state
FROM transactions


-- Example 4
SELECT
  user_id,
  card_id,
  amount,
  merchant_city,
  merchant_state
FROM transactions


-- Example 5
SELECT
  user_id,
  COUNT(*) AS transaction_count
FROM transactions
WHERE
  amount > 100
  AND merchant_state = 'CA'
GROUP BY
  user_id


-- Example 6
SELECT
  a.user_id,
  b.card_index
FROM users AS a
LEFT JOIN cards AS b
  ON a.user_id = b.user


-- Example 7
SELECT
  customer.user_id,
  card.card_index
FROM users AS customer
LEFT JOIN cards AS card
  ON customer.user_id = card.user   -- cards 테이블의 고객 번호 컬럼 이름은 user


-- Example 8
SELECT
  SUM(amount) total_amount
FROM transactions


-- Example 9
SELECT
  SUM(amount) AS total_amount
FROM transactions


-- Example 10
WITH user_transaction AS (
  SELECT
    user_id,
    COUNT(*) AS transaction_count,
    SUM(amount) AS total_amount
  FROM transactions
  GROUP BY
    user_id
)
SELECT
  user_id,
  transaction_count,
  total_amount
FROM user_transaction
WHERE total_amount >= 1000


-- Example 11
-- 2018년 거래 데이터만 조회
SELECT
  user_id,
  amount
FROM transactions
WHERE year = 2018


-- Example 12
SELECT
  merchant_state,
  COUNT(*) AS transaction_count
FROM transactions
-- 온라인 거래는 merchant_city가 'ONLINE'이라 지역 분석에서 제외
WHERE merchant_city != 'ONLINE'
GROUP BY
  merchant_state


-- Example 13
SELECT
  merchant_state,
  merchant_city,
  COUNT(*) AS transaction_count
FROM transactions
GROUP BY 1, 2


-- Example 14
SELECT
  merchant_state,
  merchant_city,
  COUNT(*) AS transaction_count
FROM transactions
GROUP BY
  merchant_state,
  merchant_city


-- Example 15
SELECT *
FROM transactions
LIMIT 100


-- Example 16
SELECT
  user_id,
  amount,
  merchant_city
FROM transactions
