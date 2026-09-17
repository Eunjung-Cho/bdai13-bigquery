# 5주차 실습 / 월간 리포트의 기반 만들기

[강의](lecture.md) / [과제](assignment.md) / [시작 안내](../setup.md)

## 실습 질문과 완료 조건

> 2018년의 월별 순거래액, 객단가, 사기율을 반복 조회하려면 어떤 마트를 만들고, 그 마트의 정확성과 비용을 어떻게 확인해야 할까요?

80분 동안 자주 쓰는 SQL을 뷰로 저장하고, 합계 표인 마트를 만듭니다. 결과가 맞는지 확인한 뒤 AI와 함께 코드를 읽기 쉽게 정리합니다. 참고 SQL을 펼쳐 읽으며 ‘한 줄에 무엇을 담는지’, ‘WHERE에서 어떤 거래를 고르는지’를 말해 보세요.

준비할 항목은 자신의 쓰기 프로젝트, 강사 공유 원본 주소, 원본과 같은 데이터 위치입니다. 원본 프로젝트는 `finda-13-2026`으로 변경 예정이며, 프로젝트 생성과 데이터 업로드, 읽기 권한 설정이 끝났는지는 강사 공지로 확인합니다. 강사 공지 후 접속을 확인하고, `YOUR_PROJECT`는 자신의 실제 프로젝트 ID로 바꿉니다. 실제 스키마는 [데이터 안내](../data-guide.md)의 사전 프로파일 결과와 대조합니다.

완료하면 다음 네 가지가 남아 있어야 합니다.

- `v_transactions_clean`과 정제 실패 건수 기록.
- `mart_monthly_mcc`와 한 행의 기준, 합계 검증 기록.
- 원본, 뷰, 마트의 동일 질문 처리 바이트 비교표.
- AI 변경 제안 한 건 이상과 채택 또는 거절 근거.

## A. 공통 정제 뷰 만들기 / 20분

### A1. 이름과 타입 예측하기

원본의 `amount`는 문자열이고 날짜는 세 열에 나뉘어 있습니다. 뷰에서 원본 표기도 남기고 분석용 타입도 만듭니다. 원본이 잘못되었을 때 어느 값이 실패했는지 추적하기 위해서입니다.

승인 교육용 조건은 `approved_for_analysis`라는 이름으로 분명히 드러냅니다. 실제 승인 결과를 새로 발견한 열처럼 이름 붙이지 않습니다.

<details markdown="1">
<summary>A1 참고 SQL / 전체 정제 뷰</summary>

```sql
CREATE OR REPLACE VIEW `YOUR_PROJECT.bdai13.v_transactions_clean` AS
SELECT
  user_id,
  card_id,
  year,
  month,
  day,
  time,
  amount AS amount_raw,
  SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC)
    AS amount_usd,
  SAFE.PARSE_DATE(
    '%Y-%m-%d',
    FORMAT('%04d-%02d-%02d', year, month, day)
  ) AS tx_date,
  use_chip,
  CASE
    WHEN use_chip = 'Online Transaction' THEN '온라인'
    WHEN use_chip IN ('Swipe Transaction', 'Chip Transaction') THEN '오프라인'
    ELSE '미분류'
  END AS channel,
  merchant_name,
  merchant_city,
  merchant_state,
  zip,
  mcc,
  errors,
  (errors IS NULL OR TRIM(errors) = '') AS approved_for_analysis,
  is_fraud AS is_fraud_raw,
  CASE
    WHEN LOWER(TRIM(is_fraud)) = 'yes' THEN TRUE
    WHEN LOWER(TRIM(is_fraud)) = 'no' THEN FALSE
    ELSE NULL
  END AS fraud_flag
FROM `finda-13-2026.tabformer.transactions`;
```

생성 대상은 자신의 데이터셋입니다. 이 뷰를 만들 수 있어도 다른 사람이 원본에 접근할 권한까지 자동으로 생기는 것은 아닙니다. 원본 읽기 권한이 없는 사람에게 뷰 결과를 보여 주려면 authorized view라는 별도 설정이 필요합니다. 뷰를 만들었다고 이 설정까지 자동으로 되는 것은 아닙니다.

</details>

### A2. 실패를 숨기지 않는 품질 검사

SQL이 실행되었다는 사실만으로 정제가 성공한 것은 아닙니다. 날짜와 금액 변환 실패와 사기 라벨 미확인 건수를 각각 확인합니다. 아래 검사는 전체 원본 범위이며 마트의 2018년 필터보다 먼저 실행합니다.

```sql
SELECT
  COUNT(*) AS source_row_count,
  COUNTIF(amount_usd IS NULL) AS invalid_or_missing_amount_count,
  COUNTIF(tx_date IS NULL) AS invalid_or_missing_date_count,
  COUNTIF(fraud_flag IS NULL) AS unknown_fraud_label_count,
  COUNTIF(channel = '미분류') AS unclassified_channel_count,
  COUNTIF(approved_for_analysis) AS analysis_approved_count,
  MIN(tx_date) AS min_tx_date,
  MAX(tx_date) AS max_tx_date
FROM `YOUR_PROJECT.bdai13.v_transactions_clean`;
```

원본 행 수와 뷰 행 수를 대조합니다. 이 뷰에는 WHERE와 JOIN이 없으므로 두 값이 같아야 합니다. 변환 실패는 행을 지우는 대신 NULL로 나타납니다. 실제 값은 자신의 실행 결과를 기록합니다.

날짜가 NULL인 행은 2018년 범위 조건에서 제외됩니다. 사기 라벨이 NULL인 행은 유효 금액과 날짜 조건을 만족하면 순거래액과 거래 건수에는 들어가고, 사기율 분모에서는 빠집니다. 서로 다른 목적의 결측을 한꺼번에 제거하지 않습니다.

## B. 월간 소비 마트 만들기 / 25분

### B1. 먼저 결과 표의 헤더 그리기

종이에 `tx_month, mcc, channel, amount_usd, txn_count, fraud_count, fraud_labeled_count`를 씁니다. 한 행이 특정 고객이 아니라 특정 월, 업종, 채널이라는 것을 확인합니다.

분석 범위는 2018-01-01 이상, 2019-01-01 미만입니다. 금액을 모르는 행은 제외하고 음수는 유지합니다. 원본에 없는 월, 업종, 채널 조합은 오늘 마트에 자동으로 생성하지 않습니다. 전월비를 계산할 때는 4주차의 달력 채우기 로직을 다시 적용해야 합니다.

<details markdown="1">
<summary>B1 참고 SQL / 월간 마트 생성</summary>

```sql
CREATE OR REPLACE TABLE `YOUR_PROJECT.bdai13.mart_monthly_mcc`
PARTITION BY DATE_TRUNC(tx_month, MONTH)
CLUSTER BY mcc, channel
OPTIONS (
  description = '2018년 월 x MCC x 채널. 유효 금액, 승인 교육용 조건, 환불 포함 순거래액.'
)
AS
SELECT
  DATE_TRUNC(tx_date, MONTH) AS tx_month,
  mcc,
  channel,
  SUM(amount_usd) AS amount_usd,
  COUNT(*) AS txn_count,
  COUNTIF(fraud_flag) AS fraud_count,
  COUNTIF(fraud_flag IS NOT NULL) AS fraud_labeled_count
FROM `YOUR_PROJECT.bdai13.v_transactions_clean`
WHERE tx_date >= DATE '2018-01-01'
  AND tx_date < DATE '2019-01-01'
  AND amount_usd IS NOT NULL
  AND approved_for_analysis
GROUP BY tx_month, mcc, channel;
```

각 월의 1일이 들어 있는 날짜 열을 기준으로, 같은 달의 데이터를 한 구간에 저장하도록 했습니다. 마트 크기가 작으면 저장 구조 변경에 따른 절감 효과가 작을 수 있습니다. `description`은 지표 정의서 전체를 대신하지 않으므로 [지표 정의서](../templates/metric-spec.md)도 작성합니다.

</details>

### B2. 같은 월, 업종, 채널이 두 줄로 나오지 않는지 검사

```sql
-- 결과가 0행이면 월 × MCC × 채널 중복이 없습니다.
SELECT tx_month, mcc, channel, COUNT(*) AS row_count
FROM `YOUR_PROJECT.bdai13.mart_monthly_mcc`
GROUP BY tx_month, mcc, channel
HAVING COUNT(*) > 1;
```

```sql
-- 아래 위반 건수들은 모두 0이어야 합니다.
SELECT
  COUNTIF(tx_month != DATE_TRUNC(tx_month, MONTH)) AS not_month_start,
  COUNTIF(tx_month < DATE '2018-01-01'
    OR tx_month >= DATE '2019-01-01') AS out_of_range,
  COUNTIF(txn_count <= 0) AS invalid_txn_count,
  COUNTIF(fraud_count > fraud_labeled_count) AS fraud_exceeds_labeled,
  COUNTIF(fraud_labeled_count > txn_count) AS labeled_exceeds_txn
FROM `YOUR_PROJECT.bdai13.mart_monthly_mcc`;
```

순거래액이 음수라는 이유로 검증 실패로 처리하지 않습니다. 환불이 포함된 정의에서는 가능한 값입니다. NULL MCC도 원본에 있으면 하나의 미상 업종 집계로 남길 수 있으며, 실제 발생 여부와 공개 표시 방법을 기록합니다.

### B3. 원본 범위와 마트의 합계 보존

<details markdown="1">
<summary>B3 참고 SQL / 차이는 0이어야 합니다</summary>

```sql
WITH detail_total AS (
  SELECT
    SUM(amount_usd) AS amount_usd,
    COUNT(*) AS txn_count,
    COUNTIF(fraud_flag) AS fraud_count,
    COUNTIF(fraud_flag IS NOT NULL) AS fraud_labeled_count
  FROM `YOUR_PROJECT.bdai13.v_transactions_clean`
  WHERE tx_date >= DATE '2018-01-01'
    AND tx_date < DATE '2019-01-01'
    AND amount_usd IS NOT NULL
    AND approved_for_analysis
), mart_total AS (
  SELECT
    SUM(amount_usd) AS amount_usd,
    SUM(txn_count) AS txn_count,
    SUM(fraud_count) AS fraud_count,
    SUM(fraud_labeled_count) AS fraud_labeled_count
  FROM `YOUR_PROJECT.bdai13.mart_monthly_mcc`
  WHERE tx_month >= DATE '2018-01-01'
    AND tx_month < DATE '2019-01-01'
)
SELECT
  d.amount_usd - m.amount_usd AS amount_difference,
  d.txn_count - m.txn_count AS txn_difference,
  d.fraud_count - m.fraud_count AS fraud_difference,
  d.fraud_labeled_count - m.fraud_labeled_count AS labeled_difference
FROM detail_total AS d
CROSS JOIN mart_total AS m;
```

분석 대상이 비어 있으면 SUM이 NULL일 수 있습니다. 이때 “0 차이라 성공”으로 바꾸지 말고 데이터 범위와 원본 연결부터 확인합니다. 유효 대상이 있는 정상 수업 데이터에서는 네 차이가 0인지 확인합니다.

</details>

## C. 같은 질문을 세 방식으로 답하기 / 20분

질문은 “2018년 각 월의 순거래액과 유효 금액 거래 건수는 얼마인가?”입니다. 세 쿼리 모두 금액 합계와 거래 건수라는 같은 두 숫자를 구합니다. 두 숫자는 여러 그룹의 값을 더해 전체 합계를 구할 수 있습니다.

<details markdown="1">
<summary>C1 참고 SQL / 원본 직접 집계</summary>

```sql
WITH clean AS (
  SELECT
    SAFE.PARSE_DATE('%Y-%m-%d',
      FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date,
    SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC)
      AS amount_usd,
    (errors IS NULL OR TRIM(errors) = '') AS approved_for_analysis
  FROM `finda-13-2026.tabformer.transactions`
)
SELECT
  DATE_TRUNC(tx_date, MONTH) AS tx_month,
  SUM(amount_usd) AS amount_usd,
  COUNT(*) AS txn_count
FROM clean
WHERE tx_date >= DATE '2018-01-01'
  AND tx_date < DATE '2019-01-01'
  AND amount_usd IS NOT NULL
  AND approved_for_analysis
GROUP BY tx_month
ORDER BY tx_month;
```

</details>

<details markdown="1">
<summary>C2 참고 SQL / 뷰에서 집계</summary>

```sql
SELECT
  DATE_TRUNC(tx_date, MONTH) AS tx_month,
  SUM(amount_usd) AS amount_usd,
  COUNT(*) AS txn_count
FROM `YOUR_PROJECT.bdai13.v_transactions_clean`
WHERE tx_date >= DATE '2018-01-01'
  AND tx_date < DATE '2019-01-01'
  AND amount_usd IS NOT NULL
  AND approved_for_analysis
GROUP BY tx_month
ORDER BY tx_month;
```

</details>

<details markdown="1">
<summary>C3 참고 SQL / 마트에서 다시 집계</summary>

```sql
SELECT
  tx_month,
  SUM(amount_usd) AS amount_usd,
  SUM(txn_count) AS txn_count
FROM `YOUR_PROJECT.bdai13.mart_monthly_mcc`
WHERE tx_month >= DATE '2018-01-01'
  AND tx_month < DATE '2019-01-01'
GROUP BY tx_month
ORDER BY tx_month;
```

</details>

### C4. 측정 기록과 해석

각 결과의 월 목록과 금액, 건수를 먼저 맞춥니다. 전체 합계가 같아도 월끼리 값이 바뀌어 있을 수 있으므로 월별 비교까지 합니다. 결과 비교가 끝나기 전에는 비용 절감 결론을 쓰지 않습니다.

| 방식 | 실행 전 예상 바이트 | 실행 후 처리 바이트 | 캐시 사용 | 월별 결과 일치 | 실행 시각 |
| --- | ---: | ---: | --- | --- | --- |
| 원본 | 직접 측정 | 직접 측정 | 직접 확인 | 직접 확인 | 직접 기록 |
| 뷰 | 직접 측정 | 직접 측정 | 직접 확인 | 직접 확인 | 직접 기록 |
| 마트 | 직접 측정 | 직접 측정 | 직접 확인 | 직접 확인 | 직접 기록 |

뷰와 원본의 바이트가 같아도 뷰가 실패한 것은 아닙니다. 공통 정제 정의를 관리하는 역할은 여전히 남습니다. 마트의 반복 조회가 줄어도 처음 만드는 비용, 보관 공간, 다시 만드는 비용을 제외한 수치라는 점을 적습니다.

여유가 있으면 “한 번만 조회할 때”와 “같은 마트를 여러 번 조회할 때”를 분리해 생각해 봅니다. 단순 비교 모델은 `직접 조회 N회 비용` 대 `마트 생성 1회 + 마트 조회 N회 + 저장`입니다. 달러 환산은 과금 모델과 실제 요율을 확인한 경우에만 수행합니다.

## D. AI 코드 정리 검증 / 15분

### D1. 읽기 쉬운 SQL 만들기

[강의의 프롬프트](lecture.md)를 이용해 C1의 정제 CTE와 이름, 주석을 개선하도록 요청합니다. 결과를 바로 원본 파일에 덮어쓰지 않고 `before.sql`, `after.sql`로 나눕니다.

검증할 항목은 다음과 같습니다.

1. 출력의 월, 순거래액, 거래 건수가 같은가?
2. 2018년 시작, 종료 경계가 같은가?
3. 금액 NULL과 음수 환불 처리 방식이 같은가?
4. `approved_for_analysis` 조건이 남아 있는가?
5. `DISTINCT`나 알 수 없는 거래 키가 추가되지 않았는가?
6. 읽은 데이터 크기가 실제로 줄었는가? AI가 설명한 이유와 맞는가?

### D2. 아래 제안을 분류하기

| AI 제안 | 직접 내릴 판단 |
| --- | --- |
| `SELECT *` 대신 필요한 열만 지정 | 결과에 필요한 열이 모두 있는지 확인하고 측정 |
| 뷰로 바꾸면 비용이 무조건 절반 | 보장할 수 없는 주장, 측정 필요 |
| `amount_usd > 0`으로 바꾸기 | 환불 포함 순거래액 정의 변경 |
| `COUNT(DISTINCT user_id)`를 거래 건수로 쓰기 | 거래 건수와 활성 고객 수 혼동 |
| `LIMIT 100`으로 집계 비용 절감 | 출력 제한과 읽기 비용을 혼동했는지 검토 |

단순 반박에 그치지 말고 수정된 프롬프트 한 문장을 적습니다. 예: “거래 건수는 고객 수가 아니라 분석 조건을 만족하는 원본 행 수이며, 음수 금액을 유지해 주세요.”

## 선택 실습 / 거래 단위 Silver 테이블

프로젝트에 월보다 세밀한 날짜 필터가 필요할 때 진행합니다. 저장 용량과 생성 예상 바이트를 먼저 확인합니다. 이 테이블 생성 없이도 기본 마트 실습을 완료할 수 있습니다.

<details markdown="1">
<summary>참고 SQL / 2018년 정제 거래를 월 파티션으로 저장</summary>

```sql
CREATE OR REPLACE TABLE `YOUR_PROJECT.bdai13.silver_transactions`
PARTITION BY DATE_TRUNC(tx_date, MONTH)
CLUSTER BY mcc, channel
OPTIONS (
  require_partition_filter = TRUE,
  description = '2018년 유효 금액 거래. 승인 교육용 조건. 환불 포함.'
)
AS
SELECT
  tx_date, user_id, card_id, mcc, channel, amount_usd, fraud_flag
FROM `YOUR_PROJECT.bdai13.v_transactions_clean`
WHERE tx_date >= DATE '2018-01-01'
  AND tx_date < DATE '2019-01-01'
  AND amount_usd IS NOT NULL
  AND approved_for_analysis;

-- 조회에도 파티션 조건을 명시합니다.
SELECT
  mcc,
  SUM(amount_usd) AS amount_usd,
  COUNT(*) AS txn_count
FROM `YOUR_PROJECT.bdai13.silver_transactions`
WHERE tx_date >= DATE '2018-10-01'
  AND tx_date < DATE '2018-11-01'
GROUP BY mcc
ORDER BY amount_usd DESC;
```

위 테이블은 날짜와 금액, 승인 조건이 적용된 거래만 저장합니다. 원본 전체를 보존하는 정제 저장소와는 범위가 다릅니다. 다른 분석에 재사용할 때 이 조건을 먼저 확인합니다.

</details>

## 오류가 났을 때

| 증상 | 확인 순서 |
| --- | --- |
| Dataset not found | 프로젝트 ID, 데이터셋 이름, 쿼리 위치를 확인 |
| Permission denied | 읽기는 공유 원본, 쓰기는 본인 데이터셋인지 확인 |
| 날짜가 모두 NULL | year/month/day 타입과 실제 값, FORMAT 조합을 확인 |
| 원본과 마트의 거래 건수가 다름 | 기간, 금액 NULL, 승인 조건이 모두 같은지 확인 |
| 합계는 같은데 사기율이 다름 | 라벨 미확인 행을 분모에서 어떻게 처리했는지 확인 |
| 파티션 필터가 필요하다는 오류 | Silver 조회에 `tx_date` 범위 조건 추가 |
| 예상 바이트가 너무 큼 | 실행하지 않고 범위, 필요 열, 대상 테이블부터 확인 |
| 뷰 또는 테이블이 사라짐 | sandbox 만료 여부와 저장해 둔 재생성 SQL 확인 |

Sandbox에서는 테이블 등의 만료와 기능 제한이 있으므로 생성 SQL을 결과 테이블과 별도로 보관합니다. 예산 경보는 쿼리를 자동으로 막는 장치가 아닙니다. [비용과 환경 안내](../setup.md)를 다시 확인합니다.

## 제출 전 셀프 체크

- [ ] 실제 데이터 측정값과 교육용 예시를 구분했다.
- [ ] 마트의 월, MCC, 채널 중복 검사 결과가 0행이다.
- [ ] 순거래액, 거래 건수, 사기 분자와 분모의 합계를 검증했다.
- [ ] 원본, 뷰, 마트의 월별 결과와 캐시 조건을 확인했다.
- [ ] AI 생성 부분, 직접 수정한 부분, 검증 증거를 남겼다.

## 출처

- 제공 강의계획서, 5주차 실습과 AI 코드 정리 항목.
- [뷰 만들기](https://docs.cloud.google.com/bigquery/docs/views), [GoogleSQL DDL](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/data-definition-language).
- [비용 추정과 통제](https://docs.cloud.google.com/bigquery/docs/best-practices-costs), [캐시 결과 사용](https://docs.cloud.google.com/bigquery/docs/cached-results), [BigQuery sandbox](https://docs.cloud.google.com/bigquery/docs/sandbox).
