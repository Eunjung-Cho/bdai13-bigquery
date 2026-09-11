-- Source: week2/lecture.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
SELECT
  raw_amount,
  SAFE_CAST(REPLACE(REPLACE(raw_amount, '$', ''), ',', '') AS NUMERIC)
    AS amount_usd
FROM UNNEST(['$1,234.56', '$-20.00', 'unknown', '']) AS raw_amount;


-- Example 2
SELECT SAFE.PARSE_DATE(
  '%Y-%m-%d', FORMAT('%04d-%02d-%02d', 2018, 2, 30)
) AS example_date;
