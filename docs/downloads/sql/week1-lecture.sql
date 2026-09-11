-- Source: week1/lecture.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
-- 교육용 가상 데이터: 원본 테이블 접속 없이 실행할 수 있습니다.
WITH sample AS (
  SELECT '$100.00' AS amount UNION ALL
  SELECT '' UNION ALL
  SELECT CAST(NULL AS STRING)
)
SELECT
  COUNT(*) AS all_rows,
  COUNT(amount) AS non_null_rows,
  COUNTIF(amount IS NULL OR TRIM(amount) = '') AS missing_or_blank_rows
FROM sample;
