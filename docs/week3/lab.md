# 3주차 실습. 조인 결과를 믿어도 되는가?

[강의](lecture.md) / [과제](assignment.md) / [데이터 사전](../data-guide.md)

읽기 원본은 `finda-13-2026.tabformer`이며 실제 공유 준비 상태는 [환경 준비](../setup.md)를 확인합니다. 각 SQL은 독립 실행용입니다. 실제 결과와 처리 바이트는 본인이 기록합니다. 키 검증을 먼저 끝내고 분석으로 이동합니다.

처음에는 **참고 SQL을 펼쳐 그대로 실행 → 결과 열 확인 → 조건 한 곳 수정 → 결과 비교** 순서로 진행합니다. 긴 쿼리를 외울 필요는 없습니다. `WITH` 다음 이름들은 “정제한 표”, “기간을 고른 표”, “속성을 붙인 표”라고 읽으면 됩니다. 도전 문제는 기본 실행과 검증을 마친 뒤 선택합니다.

## 실습 1. 연결하기 전에 검사하기 — 20분

**질문:** 고객과 카드 속성을 붙여도 2018년 거래 건수와 순거래액은 그대로인가?

- (1) 스키마에서 키의 이름과 타입을 확인합니다.
- (2) 아래 중복/NULL 검사에서 0이 아닌 결과가 있으면 분석을 멈추고 원본을 확인합니다.
- (3) 조인 전후 숫자 비교를 실행해 결과 한 행과 처리 바이트를 저장합니다.

<details markdown="1">
<summary>키 검사 참고 SQL</summary>

```sql
WITH user_duplicates AS (
    SELECT user_id
    FROM `finda-13-2026.tabformer.users`
    GROUP BY user_id
    HAVING COUNT(*) > 1
), card_duplicates AS (
    SELECT user, card_index
    FROM `finda-13-2026.tabformer.cards`
    GROUP BY user, card_index
    HAVING COUNT(*) > 1
)
SELECT
    (SELECT COUNT(*) FROM user_duplicates) AS duplicate_user_keys,
    (SELECT COUNT(*) FROM card_duplicates) AS duplicate_card_keys,
    (SELECT COUNTIF(user_id IS NULL)
        FROM `finda-13-2026.tabformer.users`) AS null_user_keys,
    (SELECT COUNTIF(user IS NULL OR card_index IS NULL)
        FROM `finda-13-2026.tabformer.cards`) AS null_card_keys;
```

</details>

<details markdown="1">
<summary>조인 전후 숫자 비교 참고 SQL</summary>

```sql
WITH clean AS (
    SELECT user_id, card_id, errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d',
            FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date
    FROM `finda-13-2026.tabformer.transactions`
), base AS (
    SELECT * FROM clean
    WHERE tx_date >= DATE '2018-01-01' AND tx_date < DATE '2019-01-01'
        AND amount_usd IS NOT NULL
        AND (errors IS NULL OR TRIM(errors) = '')
), joined AS (
    SELECT t.amount_usd, u.user_id AS matched_user, c.user AS matched_card
    FROM base AS t
    LEFT JOIN `finda-13-2026.tabformer.users` AS u ON t.user_id = u.user_id
    LEFT JOIN `finda-13-2026.tabformer.cards` AS c
        ON t.user_id = c.user AND t.card_id = c.card_index
), before_join AS (
    SELECT COUNT(*) AS rows_before, SUM(amount_usd) AS amount_before FROM base
), after_join AS (
    SELECT COUNT(*) AS rows_after, SUM(amount_usd) AS amount_after,
        COUNTIF(matched_user IS NULL) AS missing_user_rows,
        COUNTIF(matched_card IS NULL) AS missing_card_rows
    FROM joined
)
SELECT b.*, a.*,
    a.rows_after - b.rows_before AS row_difference,
    a.amount_after - b.amount_before AS amount_difference
FROM before_join AS b CROSS JOIN after_join AS a;
```

</details>

정상적인 거래 기준 LEFT JOIN에서는 차이 두 개가 0이어야 합니다. `rows_before=0`이면 통과 판정을 하지 말고 데이터 기간, 권한, 정제 조건을 확인합니다. `missing_*`는 고객이나 카드 정보를 붙이지 못한 거래 수입니다. 이 값이 0이 아니어도 거래 행은 남아 있을 수 있습니다. 정보가 비어 있는 문제와 거래가 여러 줄로 늘어나는 문제를 따로 확인하세요. 이 수업에서 errors가 비어 있음을 승인으로 간주하는 것은 교육용 정의입니다.

## 실습 2. 어느 연령대와 성별에서 소비가 관측되는가? — 15분

**조건:** 2018년, 유효 금액, 교육용 승인 조건, 환불 포함. 한 행은 고객 표에 저장된 나이 구간과 성별의 조합입니다. 예를 들어 ‘30대 여성’이 한 줄로 나옵니다. 고객 수는 해당 그룹에서 거래한 고유 고객 수입니다.

- (1) 예상 출력 열을 먼저 적습니다.
- (2) 연령 미상과 성별 미상을 제외할지 토론하고, 첫 실행에서는 유지합니다.
- (3) 집계의 거래 건수와 금액 총합이 실습 1의 `rows_before`, `amount_before`와 같은지 확인합니다.

<details markdown="1">
<summary>연령대와 성별 분석 참고 SQL</summary>

```sql
WITH clean AS (
    SELECT user_id, errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d',
            FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date
    FROM `finda-13-2026.tabformer.transactions`
), base AS (
    SELECT * FROM clean
    WHERE tx_date >= DATE '2018-01-01' AND tx_date < DATE '2019-01-01'
        AND amount_usd IS NOT NULL AND (errors IS NULL OR TRIM(errors) = '')
), enriched AS (
    SELECT t.user_id, t.amount_usd,
        CASE WHEN u.current_age IS NULL OR u.current_age < 0 THEN '연령 미상'
            ELSE CONCAT(CAST(DIV(u.current_age, 10) * 10 AS STRING), '대')
        END AS age_band,
        COALESCE(NULLIF(TRIM(u.gender), ''), '성별 미상') AS gender
    FROM base AS t
    LEFT JOIN `finda-13-2026.tabformer.users` AS u ON t.user_id = u.user_id
)
SELECT age_band, gender, SUM(amount_usd) AS net_amount_usd,
    COUNT(*) AS txn_count, COUNT(DISTINCT user_id) AS active_user_count,
    SAFE_DIVIDE(SUM(amount_usd), COUNT(*)) AS net_amount_per_txn
FROM enriched
GROUP BY age_band, gender
ORDER BY net_amount_usd DESC, age_band, gender;
```

</details>

해석은 “고객 표에 저장된 나이로 나눴을 때 A 연령대의 순거래액이 크다”처럼 씁니다. 그룹의 고객 수가 크기 때문인지, 거래 빈도 때문인지, 거래당 금액 때문인지 다음 질문을 덧붙입니다. “A 연령대는 원래 소비 성향이 강하다”는 결론은 이 표로 입증되지 않습니다.

## 실습 3. 한 번도 쓰이지 않은 카드는 몇 장인가? — 10분

“한 번도”의 범위를 먼저 정합니다. 여기서는 **제공된 전체 관측 기간에서 날짜와 금액이 유효하고 교육용 승인 조건을 만족한 거래가 0건인 카드**입니다. 실제로 발급 이후 평생 사용하지 않은 카드라는 뜻이 아닙니다. 현재 카드 표에는 각 카드를 언제부터 가지고 있었는지도 나와 있지 않습니다.

<details markdown="1">
<summary>관측 기간 미사용 카드 참고 SQL</summary>

```sql
WITH clean AS (
    SELECT user_id, card_id, errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d',
            FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date
    FROM `finda-13-2026.tabformer.transactions`
), used_cards AS (
    SELECT DISTINCT user_id, card_id
    FROM clean
    WHERE tx_date IS NOT NULL AND amount_usd IS NOT NULL
        AND (errors IS NULL OR TRIM(errors) = '')
), card_status AS (
    SELECT c.user, c.card_index, c.card_brand,
        t.user_id IS NULL AS is_unused
    FROM `finda-13-2026.tabformer.cards` AS c
    LEFT JOIN used_cards AS t
        ON c.user = t.user_id AND c.card_index = t.card_id
)
SELECT card_brand, COUNT(*) AS all_cards,
    COUNTIF(is_unused) AS unused_cards,
    COUNTIF(NOT is_unused) AS used_cards,
    SAFE_DIVIDE(COUNTIF(is_unused), COUNT(*)) AS unused_share
FROM card_status
GROUP BY card_brand
ORDER BY unused_cards DESC;
```

</details>

`used_cards`에서는 카드 한 장을 여러 번 썼어도 ‘쓴 적 있음’ 한 번만 표시하면 됩니다. 그래서 DISTINCT로 고객 번호와 카드 번호가 같은 줄을 하나로 모읍니다. 잘못된 조인 때문에 늘어난 거래를 지우는 것과는 목적이 다릅니다. 브랜드별 `used_cards + unused_cards = all_cards`여야 합니다. 전체 `all_cards` 합은 카드 원본 행 수와 같아야 합니다.

특정 연도에 사용되지 않은 카드가 궁금하면 `used_cards`의 날짜 조건을 그 연도로 바꿉니다. 제목도 “2018년 미사용”으로 바꿔야 합니다. 전체 관측 기간 조회는 범위가 넓으므로 처리 바이트를 확인한 뒤 실행합니다.

## 실습 4. 소득 구간별 객단가는 어떻게 다른가? — 20분

**조건:** 소득은 고객 정보를 저장할 때의 연간 소득이고, 단위는 달러(USD)입니다. 30,000달러, 60,000달러, 100,000달러를 기준으로 구간을 나눕니다. 음수 및 변환 실패는 미상으로 분리합니다. 객단가는 고객별 평균의 평균이 아니라 거래 전체의 순거래액/건수입니다.

먼저 참고 SQL을 실행하고 가장 낮은 소득 구간의 경계 한 곳만 바꿔 결과를 비교합니다. 원래 경계로 되돌린 뒤 같은 조건을 AI에게 전달해 SQL을 받습니다. (1) 고객 연결 키 (2) 소득 정제 (3) 미상 처리 (4) 객단가 분모 네 곳만 나란히 비교합니다. 전체 SQL을 처음부터 작성하는 것은 선택 도전입니다.

<details markdown="1">
<summary>소득 구간 분석 참고 SQL</summary>

```sql
WITH clean AS (
    SELECT user_id, errors,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC) AS amount_usd,
        SAFE.PARSE_DATE('%Y-%m-%d',
            FORMAT('%04d-%02d-%02d', year, month, day)) AS tx_date
    FROM `finda-13-2026.tabformer.transactions`
), base AS (
    SELECT * FROM clean
    WHERE tx_date >= DATE '2018-01-01' AND tx_date < DATE '2019-01-01'
        AND amount_usd IS NOT NULL AND (errors IS NULL OR TRIM(errors) = '')
), customer AS (
    SELECT user_id,
        SAFE_CAST(REPLACE(REPLACE(yearly_income, '$', ''), ',', '') AS NUMERIC) AS income_usd
    FROM `finda-13-2026.tabformer.users`
), enriched AS (
    SELECT t.user_id, t.amount_usd,
        CASE WHEN u.income_usd IS NULL OR u.income_usd < 0 THEN '0. 소득 미상'
            WHEN u.income_usd < 30000 THEN '1. 3만 미만'
            WHEN u.income_usd < 60000 THEN '2. 3만 이상 6만 미만'
            WHEN u.income_usd < 100000 THEN '3. 6만 이상 10만 미만'
            ELSE '4. 10만 이상' END AS income_band
    FROM base AS t LEFT JOIN customer AS u ON t.user_id = u.user_id
)
SELECT income_band, SUM(amount_usd) AS net_amount_usd,
    COUNT(*) AS txn_count, COUNT(DISTINCT user_id) AS active_user_count,
    SAFE_DIVIDE(SUM(amount_usd), COUNT(*)) AS net_amount_per_txn
FROM enriched
GROUP BY income_band
ORDER BY income_band;
```

</details>

**검증:** 모든 구간의 건수와 금액 합이 실습 1의 기준값과 같은지 확인합니다. 구간마다 금액/건수를 계산해 객단가와 대조합니다. 소득 미상 비율을 함께 기록합니다. 0원 거래도 유효 금액에 포함되므로 마음대로 제외하지 않습니다.

## 짝 리뷰와 프로젝트 메모 — 15분

상대의 결과표와 SQL을 받고 다음을 확인합니다. 키 조건 한 줄을 말로 설명하고, 조인 전후 증거 한 개를 짚습니다. 이어서 “이 결과로 말할 수 없는 것”을 한 문장 씁니다.

| 증상 | 먼저 볼 곳 | 대응 |
| --- | --- | --- |
| 거래 건수가 증가 | cards 복합 키, 오른쪽 키 중복 | 키 검사부터 재실행 |
| LEFT인데 거래가 감소 | WHERE의 오른쪽 테이블 조건 | 전체 보존 검사와 집단 필터 분리 |
| 객단가가 예상과 다름 | 금액 정제, 환불 포함, 분모 | 지표 정의와 동일 조건인지 확인 |
| 소득 미상이 많음 | yearly_income 원문 형식 | 미상→0 대체 없이 원본 프로파일 |
| 미사용 카드가 0장 | 기간, 승인 조건, 복합 키 | 0도 가능한 관측 결과; 억지로 만들지 않음 |

제출할 수업 기록은 SQL 3개 이상, 조인 검증 결과 1개, AI 수정 전후 1쌍, 프로젝트 질문 후보 1개입니다. [분석 리포트 틀](../templates/analysis-report.md)에 관찰과 한계를 분리해 적습니다.

## 출처

- 제공 강의계획서, 3주차 실습과 AI 검증.
- [GoogleSQL 조인 문법](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/query-syntax#join_types).
