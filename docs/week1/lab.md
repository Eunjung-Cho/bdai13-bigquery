# 1주차 실습 / 분석을 시작해도 되는 데이터인가?

[강의](lecture.md) / [과제](assignment.md) / [접속 준비](../setup.md)

**총 70분.** 필수 활동은 완성된 SQL을 실행하고 한 부분씩 바꾸는 방식입니다. 먼저 결과의 뜻을 말하고, 문법을 모르는 부분은 주석과 해설로 확인합니다. 도전 활동은 필수 활동을 마친 뒤 진행합니다.

실습에서는 `bdai13-bigquery.tabformer`에 있는 표를 읽습니다. 먼저 Schema 탭에서 열 이름과 값의 종류를 확인하세요. 아래 코드와 다르다면 [데이터 사전](../data-guide.md)을 함께 보며 실제 열 이름을 찾습니다. 실행 프로젝트는 본인 프로젝트이며 원본과 같은 데이터 위치를 사용합니다.

## A. 팀원이 분석에 접속할 수 있는가? / 20분

### 필수 A1 / 스키마를 읽고 첫 실행하기

1. BigQuery에서 강사 공유 프로젝트를 찾아 `users`, `cards`, `transactions`를 엽니다.
2. 각 테이블의 스키마와 미리보기를 살펴봅니다. 미리보기에 안 보인다고 테이블이 비었다고 결론 내리지 않습니다.
3. 아래 SQL의 예상 처리 바이트를 기록하고 쿼리별 상한을 확인한 뒤 실행합니다.
4. 실행 후 처리 바이트, 청구 바이트, 캐시 사용 여부를 작업 정보에서 기록합니다.

```sql
SELECT
  user_id,
  card_id,
  amount,
  use_chip
FROM `bdai13-bigquery.tabformer.transactions`
LIMIT 10;
```

`SELECT`는 보고 싶은 열, `FROM`은 읽을 테이블입니다. 테이블 전체 주소를 감싼 문자는 작은따옴표가 아니라 백틱입니다. `LIMIT 10`은 출력 행 수를 제한합니다. 정렬 조건이 없으므로 “처음 발생한 거래 10개”나 “무작위 표본 10개”라는 뜻은 아닙니다.

**한 부분 수정:** `SELECT` 목록의 `use_chip`을 `merchant_name`으로 바꿔 봅니다. 값이 익숙한 상점 이름인지, 식별값인지 설명합니다. 원본을 수정하는 쿼리가 아니므로 데이터가 바뀌지 않습니다.

| 기록 항목 | 내 기록 |
|---|---|
| 실행 프로젝트 / 데이터 위치 | 직접 기록 |
| 예상 / 실제 처리 바이트 | 직접 기록 |
| 청구 바이트 / 캐시 여부 | 직접 기록 |
| 결과 행 수 | 직접 기록 |
| `amount`의 데이터형과 보이는 형식 | 직접 기록 |

### 필수 A2 / 세 테이블을 한 문장으로 설명하기

| 테이블 | 한 행의 의미 | 키 후보 | 확인할 점 |
|---|---|---|---|
| users | 사용자 속성 | user_id | 중복, NULL 여부 |
| cards | 사용자별 카드 | user + card_index | 두 열을 함께 봐야 하는 이유 |
| transactions | 거래 기록 | 고유 거래 ID 없음 | user_id가 반복되는 이유 |

### 도전 / 필요한 열을 줄이면 예상 바이트가 달라질까?

첫 쿼리와 아래 쿼리의 예상 바이트를 실행 전에 비교합니다. 이미 예상치 비교로 답할 수 있다면 비용 비교를 위해 둘 다 반복 실행하지 않습니다. 데이터를 저장한 방식이나 이전 결과를 다시 쓰는 기능(캐시)에 따라 수치가 달라질 수 있습니다. 화면에서 확인한 값만 적으세요.

```sql
SELECT user_id
FROM `bdai13-bigquery.tabformer.transactions`
LIMIT 10;
```

## B. 2018년 분석에 필요한 데이터가 준비되어 있는가? / 25분

### 필수 B1 / 행 수와 결측을 한 번에 확인하기

```sql
SELECT
  COUNT(*) AS row_count,
  COUNT(DISTINCT user_id) AS observed_user_count,
  COUNTIF(user_id IS NULL) AS missing_user_rows,
  COUNTIF(amount IS NULL) AS null_amount_rows,
  COUNTIF(TRIM(amount) = '') AS blank_amount_rows,
  COUNTIF(mcc IS NULL) AS missing_mcc_rows,
  COUNTIF(year = 2018) AS year_2018_raw_rows
FROM `bdai13-bigquery.tabformer.transactions`;
```

`COUNT(DISTINCT user_id)`는 거래 테이블에 등장한 서로 다른 사용자 수입니다. `users` 전체 사용자 수와 같다고 가정하지 않습니다. `year = 2018`은 원본 연도 열을 기준으로 센 행이며, 존재하지 않는 날짜, 잘못된 금액도 포함할 수 있습니다.

**한 부분 수정:** `COUNTIF(mcc IS NULL)`의 `mcc`만 `card_id`로 바꾸고 결과 열 이름도 `missing_card_rows`로 바꿉니다. 어느 열에 값이 없는지 확인한 것인지 문장으로 적습니다.

### 필수 B2 / 금액과 날짜를 해석할 수 있는가?

```sql
WITH profiled AS (
  SELECT
    amount,
    SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC)
      AS amount_usd,
    SAFE.PARSE_DATE(
      '%Y-%m-%d', FORMAT('%04d-%02d-%02d', year, month, day)
    ) AS tx_date
  FROM `bdai13-bigquery.tabformer.transactions`
)
SELECT
  COUNT(*) AS row_count,
  COUNTIF(amount_usd IS NULL) AS unusable_amount_rows,
  COUNTIF(amount_usd < 0) AS negative_amount_rows,
  COUNTIF(tx_date IS NULL) AS invalid_or_missing_date_rows,
  MIN(tx_date) AS first_valid_date,
  MAX(tx_date) AS last_valid_date,
  COUNTIF(tx_date >= DATE '2018-01-01'
    AND tx_date < DATE '2019-01-01') AS valid_2018_date_rows
FROM profiled;
```

`REPLACE`는 `$`와 쉼표를 제거하고, `SAFE_CAST`는 숫자로 읽을 수 없는 값을 NULL로 둡니다. `FORMAT`은 연도, 월, 일을 고정된 자리수로 조합하며, `SAFE.PARSE_DATE`는 유효하지 않은 날짜를 NULL로 둡니다. NULL을 0달러나 임의의 날짜로 대체하지 않습니다.

`unusable_amount_rows`는 금액을 숫자로 읽을 수 없는 행의 수입니다. 원래 값이 없는 경우(NULL), 빈 글자인 경우, 숫자로 바꿀 수 없는 글자인 경우가 모두 들어갑니다. 처음부터 값이 없던 행까지 모두 ‘변환 오류’라고 부르지는 않습니다. 금액 정제의 상세 설명은 다음 주에 다시 다룹니다.

### 필수 B3 / 결과를 의사결정 문장으로 바꾸기

다음 문장을 본인 결과로 완성합니다.

> 2018년 날짜로 확인된 행은 ___개였다. 금액을 해석할 수 없는 행은 전체에서 ___개였다. 따라서 다음 주 거래액 분석에서는 ___ 조건을 명시하고, 제외된 행 수를 함께 기록하겠다.

여기서 “전체의 불가 금액 행 수”를 “2018년의 불가 금액 행 수”로 바꾸어 쓰지 않습니다. 두 집계의 범위가 다르기 때문입니다.

### 도전 / 카드 키는 한 열이면 충분한가?

```sql
SELECT
  card_index,
  COUNT(*) AS card_rows,
  COUNT(DISTINCT `user`) AS user_count
FROM `bdai13-bigquery.tabformer.cards`
GROUP BY card_index
ORDER BY card_rows DESC
LIMIT 10;
```

같은 `card_index`를 가진 사용자가 여럿 있다면 `card_index`만으로 카드를 식별할 수 없습니다. 그렇다고 해당 카드들을 지워서는 안 됩니다. 고객 번호와 카드 번호를 묶은 `(user, card_index)`가 겹치는지 확인해야 합니다. 이 두 번호로 표를 연결하는 방법은 3주차에 배웁니다.

## C. AI가 제안한 데이터 점검을 믿어도 되는가? / 25분

### 필수 C1 / 같은 질문에 문맥을 더하기

첫 요청에는 “2018년 카드 거래가 몇 건인지 확인하는 BigQuery SQL을 만들어 줘”라고 입력합니다. 실행 전 생성된 열 이름을 실제 스키마와 대조합니다. 오류가 나오지 않아도 잘못된 사례를 억지로 만들 필요는 없습니다.

두 번째 요청에는 아래 정보를 추가합니다. 실제 사용자 개인정보, 인증정보, 서비스 계정 키는 넣지 않습니다.

```text
BigQuery GoogleSQL을 사용한다.
원본: bdai13-bigquery.tabformer.transactions.
year, month, day는 INT64이며 transaction_date라는 열은 없다.
질문: 유효한 날짜가 2018-01-01 이상 2019-01-01 미만인 원본 거래 행 수는?
승인, 금액, 사기 여부로는 아직 필터링하지 않는다.
날짜 변환 실패는 NULL로 두고, 유효한 2018년 행 수와
전체 날짜 변환 실패/결측 행 수를 별도 열로 반환하라.
읽기 SELECT와 CTE만 사용하라. 실행 결과를 추측하지 말라.
먼저 사용할 열과 제외 조건을 설명한 뒤 SQL을 작성하라.
```

### 필수 C2 / 생성→검증→수정 기록하기

| 항목 | 기록할 내용 |
|---|---|
| AI 생성 | 첫 쿼리와 두 번째 쿼리의 차이 |
| 스키마 검증 | 실제로 존재하는 열만 사용했는가 |
| 실행 검증 | 예상 바이트 확인, 오류 또는 성공 기록 |
| 의미 검증 | 날짜 유효성, 기간, 제외 조건이 질문과 같은가 |
| 수정 | 오류 원인, 수정한 부분, 재확인 결과 |

<details markdown="1">
<summary>참고 SQL과 검증 포인트</summary>

```sql
WITH dated AS (
  SELECT
    SAFE.PARSE_DATE(
      '%Y-%m-%d', FORMAT('%04d-%02d-%02d', year, month, day)
    ) AS tx_date
  FROM `bdai13-bigquery.tabformer.transactions`
)
SELECT
  COUNTIF(tx_date >= DATE '2018-01-01'
    AND tx_date < DATE '2019-01-01') AS valid_2018_rows,
  COUNTIF(tx_date IS NULL) AS all_invalid_or_missing_date_rows
FROM dated;
```

B2의 유효한 2018년 행 수 및 전체 날짜 불가 행 수와 각각 일치해야 합니다. `WHERE year = 2018`을 먼저 넣으면 전체 날짜 불가 행 수의 범위가 좁아져 질문이 달라집니다. `transaction_date`를 실제 열 이름처럼 사용하거나 승인 조건을 임의로 추가하지 않았는지 확인합니다.

</details>

### 도전 / 실행에 성공하는 잘못된 SQL 찾기

아래는 교육용 오류 사례입니다. “유효한 2018년 거래 행 수”라는 질문에 왜 부족한지 먼저 설명합니다.

```sql
SELECT COUNT(amount) AS transaction_count
FROM `bdai13-bigquery.tabformer.transactions`
WHERE year = 2018;
```

<details markdown="1">
<summary>힌트와 해설</summary>

`COUNT(amount)`는 금액이 NULL인 행을 제외합니다. 또한 연도만 확인하므로 날짜 유효성을 확인하지 않습니다. 질문이 원본 연도 열 기준이며 금액이 있는 행 수라면 다른 지표로서 의미가 있지만, 현재 질문과는 다릅니다. C2의 참고 SQL처럼 날짜를 안전하게 만든 뒤 조건을 셉니다.

</details>

## 오류가 나면 여기부터 확인

| 증상 | 먼저 확인할 것 | 다음 행동 |
|---|---|---|
| Access Denied | 로그인 계정, 공유 권한, 실행 프로젝트 | [접속 준비](../setup.md)에 따라 강사에게 오류 문구 전달 |
| Not found … location | 원본 주소와 데이터 위치 | 원본과 같은 리전인지 확인 |
| Unrecognized name | 실제 열 이름, 별칭 범위 | 스키마 대조, CTE 전체 실행 |
| SUM에 STRING 오류 | `amount` 자료형 | 정제 후 NUMERIC 열 사용 |
| bytes billed 상한 초과 | 예상 처리량, 선택 열, 실습 한도 | 불필요한 열 제거 후 재확인, 무조건 상향하지 않기 |
| 결과가 0행 또는 0건 | 기간, WHERE, 권한, 원본 범위 | 필터를 하나씩 확인하고 프로파일 결과와 대조 |

## 오늘 저장할 것

- 실행한 SQL 세트와 처리 바이트 기록
- 세 테이블의 한 행, 키 설명
- 금액과 날짜, 상점 식별값 등 발견한 함정 세 가지
- AI가 만든 부분과 직접 확인하고 수정한 기록

출처: 제공된 강의계획서 1주차; [BigQuery 비용 통제](https://docs.cloud.google.com/bigquery/docs/best-practices-costs), [변환 함수](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/conversion_functions), [날짜 함수](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/date_functions), [집계 함수](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/aggregate_functions), [Google 언어 모델 기초](https://developers.google.com/machine-learning/crash-course/llm).
