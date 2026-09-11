-- Source: setup.md
-- 예제 모음: 전체를 한꺼번에 실행하지 마세요.
-- 각 블록 앞뒤 설명을 웹 강의에서 확인하세요.
-- 고의적인 오류 예시와 마지막 SELECT 교체 조각이 포함될 수 있습니다.


-- Example 1
SELECT
    'BDAI 13기' AS course,
    2 + 3 AS first_result;


-- Example 2
-- finda-13-2026를 강사가 공지한 프로젝트 ID로 바꿉니다.
SELECT table_name, column_name, data_type, is_nullable
FROM `finda-13-2026.tabformer.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name IN ('transactions', 'users', 'cards')
ORDER BY table_name, ordinal_position;
