# SQL 패턴과 오류 해결

필요한 문법을 찾아 쓰는 참고표입니다. 외워서 처음부터 작성하기보다, 수업 예제에서 조건 하나를 바꿔 결과가 어떻게 달라지는지 확인하세요.

## 주차별로 필요한 문법

| 주차 | 패턴 | 쉬운 설명 | 주의점 |
| --- | --- | --- | --- |
| 1 | SELECT, WHERE, COUNT | 열·행 선택과 크기 확인 | LIMIT가 스캔을 제한하지 않을 수 있음 |
| 2 | SAFE_CAST, REPLACE | 문자열 금액을 숫자로 변환 | 실패는 NULL |
| 2 | COUNTIF | 조건을 만족하는 행 수 | NULL의 의미 확인 |
| 2 | SAFE_DIVIDE | 0으로 나누기 오류 처리 | NULL을 임의의 0%로 표시하지 않음 |
| 3 | LEFT JOIN | 기준 행을 남기며 속성 붙이기 | 오른쪽 키가 중복이면 행 증가 |
| 3 | NOT EXISTS | 관련 행이 없는 대상 찾기 | 관측 기간 명시 |
| 4 | ROW_NUMBER | 그룹 내 순서 부여 | 동점 정렬 기준 추가 |
| 4 | LAG | 이전 행의 값 보기 | 이전 행이 이전 달인지 확인 |
| 5 | CREATE VIEW | 재사용할 쿼리 저장 | 원천 조회 비용은 계속 발생 가능 |
| 5 | CREATE TABLE AS | 계산 결과를 테이블로 저장 | 그레인·갱신·만료 관리 |

## 금액을 정제하는 순서

```sql
SELECT
    amount,
    REPLACE(amount, '$', '') AS without_dollar,
    REPLACE(REPLACE(amount, '$', ''), ',', '') AS numeric_text,
    SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC)
        AS amount_usd
FROM `finda-13-2026.tabformer.transactions`
LIMIT 20;
```

달러 기호를 제거하고, 천 단위 쉼표를 제거한 다음 숫자로 변환합니다. 소수·음수는 유지합니다. `SAFE_CAST`는 입력값 변환 실패를 NULL로 처리하지만, 존재하지 않는 컬럼이나 불가능한 타입 조합 같은 모든 오류를 해결하지는 않습니다.

## 복합 키를 눈으로 확인하기

```sql
SELECT user, card_index, COUNT(*) AS rows_per_key
FROM `finda-13-2026.tabformer.cards`
GROUP BY user, card_index
HAVING COUNT(*) > 1;
```

유일한 키라면 중복 결과가 없어야 합니다. 중복이 있다고 `DISTINCT`로 무조건 제거하지 않습니다. 행의 다른 컬럼이 서로 충돌하는지 보고 적재 문제나 적절한 기준을 확인합니다.

## 그레인 주석 쓰기

```sql
-- 질문: 고객별 카드 보유 수는?
-- 원천 한 행: 카드 1장. 결과 한 행: 고객 1명.
SELECT user AS user_id, COUNT(*) AS card_count
FROM `finda-13-2026.tabformer.cards`
GROUP BY user;
```

SELECT 목록을 읽기 전에 원천과 결과의 한 행을 설명하면 JOIN과 집계 오류를 발견하기 쉽습니다.

## 오류 메시지별 첫 확인

| 메시지 또는 증상 | 첫 확인 | 수정 방향 |
| --- | --- | --- |
| Unrecognized name | Schema에 실제 컬럼이 있는가? | 컬럼명·별칭 범위 확인 |
| No matching signature | 문자열을 숫자처럼 계산했는가? | 타입 확인 후 명시적 변환 |
| SELECT expression references column ... neither grouped nor aggregated | 결과 한 행에 값이 하나인가? | GROUP BY 또는 적합한 집계 |
| Division by zero | 분모 0의 의미는? | SAFE_DIVIDE와 계산 불가 표시 |
| Access Denied | 읽기와 실행 권한 중 어느 것이 없는가? | 강사에게 정확한 리소스 전달 |
| Not found ... location | 데이터와 실행 위치가 같은가? | 같은 리전으로 설정 |
| 조인 후 금액 증가 | 오른쪽 키가 유일한가? | 키 검사와 복합 키 수정 |
| LAG 비교 기간이 건너뜀 | 월이 빠졌는가? | 달력 보완 후 LAG |
| 대시보드 평균이 SQL과 다름 | 평균을 다시 평균냈는가? | 분자·분모 합으로 재계산 |

## BigQuery와 DuckDB를 구분하기

BigQuery는 GoogleSQL을, DuckDB는 자체 SQL 방언을 사용합니다. 예를 들어 BigQuery의 `SAFE_CAST`는 DuckDB에서 `TRY_CAST`로 대응할 수 있고, `SAFE_DIVIDE` 대신 분모를 `NULLIF(분모, 0)`로 보호할 수 있습니다. 완성된 BigQuery SQL을 DuckDB에 그대로 붙여 넣어 항상 실행된다고 가정하지 마세요. 예비 경로에서는 이미 정제된 마트를 가져와 간단한 SELECT·GROUP BY만 연습합니다.

출처: [GoogleSQL](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/query-syntax), [변환 함수](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/conversion_functions), [DuckDB TRY_CAST](https://duckdb.org/docs/stable/sql/expressions/cast.html).

