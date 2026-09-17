# 데이터와 스키마

이 수업은 기존 FinDA 과정과 같은 카드 거래 데이터를 사용합니다. 원본 프로젝트는 **`finda-13-2026`으로 변경 예정**이며 예제는 데이터셋 이름 `tabformer`를 유지합니다. 실제 공유 완료와 접근 권한은 개강 공지로 확인하세요.

## 데이터가 설명할 수 있는 것

IBM TabFormer의 합성 카드 거래 데이터를 수업용 세 테이블로 읽습니다. 약 2,400만 건은 데이터 규모를 설명하는 값이며, 이번 공유 테이블의 정확한 행 수는 1주차 프로파일링으로 직접 확인합니다. 합성 거래에서 발견한 패턴을 실제 금융 소비자 전체의 성향으로 일반화하지 않습니다.

| 테이블 | 한 행의 의미 | 핵심 키 | 질문 예시 |
| --- | --- | --- | --- |
| `transactions` | 거래 기록 1건 | 제공 스키마에 고유 거래 ID 없음 | 어느 업종의 거래액이 큰가? |
| `users` | 고객 1명 | `user_id` | 고객 속성과 소비 패턴은 어떻게 연결되는가? |
| `cards` | 고객이 보유한 카드 1장 | `user`, `card_index`의 조합 | 보유했지만 거래하지 않은 카드는? |

```mermaid
erDiagram
    users ||--o{ cards : "user_id = user"
    users ||--o{ transactions : "user_id"
    cards ||--o{ transactions : "user + card_index"
    users {
        INT64 user_id PK
        INT64 current_age
        STRING gender
        STRING yearly_income
    }
    cards {
        INT64 user PK
        INT64 card_index PK
        STRING card_brand
        STRING card_type
    }
    transactions {
        INT64 user_id FK
        INT64 card_id FK
        INT64 year
        INT64 month
        INT64 day
        STRING amount
        STRING is_fraud
    }
```

위 그림은 표끼리 어떻게 연결되는지 보여 줍니다. 연결에 쓰는 번호를 ‘키’라고 합니다. 고객 표에서는 고객 번호 하나가 고객 한 명만 가리키는지, 카드 표에서는 고객 번호와 카드 번호의 조합이 카드 한 장만 가리키는지 실제 데이터로 확인해야 합니다. 고유 거래 ID가 없으므로 `user_id, card_id, 날짜`만 같다고 중복 거래로 제거하면 안 됩니다. 같은 날 같은 카드로 여러 번 결제할 수 있습니다.

## 이번 강의에서 사용하는 열 이름과 형식

아래는 BigQuery에 올라간 표의 열 이름과 값의 종류입니다. 원본 파일을 BigQuery에 넣을 때 이름을 정리했으므로 원본 CSV의 이름과 다를 수 있습니다. 1주차에 `INFORMATION_SCHEMA`로 실제 열 목록을 확인하고, 아래 목록과 다르면 실제 이름에 맞춰 SQL을 수정하세요.

### 거래 테이블

| 열 | 타입 | 읽을 때 주의할 점 |
| --- | --- | --- |
| `user_id`, `card_id` | INT64 | `cards.user`, `cards.card_index`와 각각 연결 |
| `year`, `month`, `day` | INT64 | 날짜가 세 열으로 분리되어 있음 |
| `time` | STRING | 시각 문자열이며 날짜를 포함하지 않음 |
| `amount` | STRING | 달러 기호, 쉼표가 들어갈 수 있고 음수도 보존 |
| `use_chip` | STRING | 온라인, 칩, 스와이프 거래 구분 |
| `merchant_name` | STRING | 상점 표시명 대신 식별값이 들어 있음 |
| `merchant_city`, `merchant_state`, `zip` | STRING | 지역 정보, 결측, 특수값 확인 |
| `mcc` | INT64 | 가맹점 업종 코드, 임의로 업종 이름 추측 금지 |
| `errors` | STRING | 에러 표기, NULL, 공백, 실제 값부터 프로파일 |
| `is_fraud` | STRING | 보통 Yes/No, 다른 값은 별도 확인 |

### 고객과 카드 테이블

`users`는 `user_id`, `current_age`, `gender`, `yearly_income`을 주로 씁니다. 소득은 금액 문자열일 수 있습니다. **`current_age`는 고객 정보를 저장할 때의 나이입니다. 과거에 결제했을 때의 나이와는 다를 수 있습니다.** 나이 구간 분석에는 이 한계를 표시합니다.

`cards`는 `user`, `card_index`, `card_brand`, `card_type`, `credit_limit`을 사용합니다. 고객 A의 카드 0과 고객 B의 카드 0은 다른 카드입니다. `card_index`만으로 조인하면 서로 다른 고객의 카드가 연결될 수 있습니다.

## 공통 정제 표현

1–4주차에는 `WITH`로 중간 결과에 이름을 붙여 씁니다. 이것을 CTE라고 하며, 현재 쿼리 안에서만 사용하는 작업용 표로 생각하면 됩니다. 5주차에는 같은 SQL을 ‘뷰’라는 이름으로 저장해 다시 씁니다. 아래 코드는 금액과 날짜를 계산하기 좋은 형태로 정리합니다. 이를 **정제**라고 합니다. 숫자나 날짜로 바꿀 수 없는 값은 **‘값을 알 수 없음’을 뜻하는 NULL**로 남깁니다.

```sql
WITH clean AS (
    SELECT
        user_id,
        card_id,
        SAFE.PARSE_DATE(
            '%Y-%m-%d', FORMAT('%04d-%02d-%02d', year, month, day)
        ) AS tx_date,
        SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS NUMERIC)
            AS amount_usd,
        mcc,
        CASE
            WHEN use_chip = 'Online Transaction' THEN '온라인'
            WHEN use_chip IN ('Swipe Transaction', 'Chip Transaction')
                THEN '오프라인'
            ELSE '미분류'
        END AS channel,
        CASE
            WHEN LOWER(TRIM(is_fraud)) = 'yes' THEN TRUE
            WHEN LOWER(TRIM(is_fraud)) = 'no' THEN FALSE
            ELSE NULL
        END AS fraud_flag,
        errors
    FROM `finda-13-2026.tabformer.transactions`
)
SELECT *
FROM clean
LIMIT 20;
```

이 `LIMIT`는 결과를 살펴보는 용도입니다. 스캔 비용 절감을 보장하지 않습니다. 1주차에는 열을 나눠 읽고, 정제 실패 건수와 원본 예시를 함께 기록합니다.

## 지표에 적용할 교육용 기본값

| 항목 | 기본 정의 | 바꾸는 경우 반드시 기록할 것 |
| --- | --- | --- |
| 분석 기간 | 2018-01-01 이상, 2019-01-01 미만 | 시작일, 끝일, 완결된 월 여부 |
| 승인 간주 | `errors IS NULL OR TRIM(errors) = ''` | 오류가 비어 있으면 승인으로 보는 수업용 기준 |
| 순거래액 | 변환 가능한 금액의 합, 음수 포함 | 양수 거래만 포함하면 다른 지표 |
| 거래 건수 | 같은 기간, 승인 조건, 유효 금액 행 수 | 금액 오류 행 제외 여부 |
| 객단가 | 순거래액 ÷ 위 거래 건수 | 평균의 평균으로 재집계하지 않음 |
| 활성 고객 수 | 같은 범위에서 `COUNT(DISTINCT user_id)` | 집단 간 합산 시 중복 고객 가능 |
| 사기율 | 라벨 TRUE 건수 ÷ TRUE/FALSE 확인 가능 건수 | NULL 라벨을 정상으로 간주하지 않음 |

위 표는 수업에서 함께 사용할 계산 규칙입니다. 지표는 거래액이나 거래 건수처럼 확인하려는 내용을 숫자로 나타낸 것이며, 실제 카드사의 공식 기준과는 다를 수 있습니다. 2주차에서 다른 정의도 비교하되, 정의가 바뀌면 지표 이름과 분모도 함께 수정하세요.

!!! warning "누락과 0은 다릅니다"
    금액 변환 실패는 0원 거래가 아닙니다. 사기 라벨 누락은 정상 거래가 아닙니다. 한 달의 행이 없다는 사실만으로 실제 거래가 0건이었다고 확정할 수도 없습니다. 데이터 수집 범위를 먼저 확인한 뒤 분석용 달력의 빈 월을 0으로 채웁니다.

## 한 행의 의미가 바뀌는 지점

```text
원본 거래         한 행 = 거래 기록 1건
정제 뷰          한 행 = 거래 기록 1건, 타입과 표준 열 추가
월간 업종 마트   한 행 = 월 × MCC × 채널
대시보드 카드    여러 마트 행을 다시 합산한 지표
```

월간 마트에는 `tx_month`, `mcc`, `channel`, `amount_usd`, `txn_count`, `fraud_count`, `fraud_labeled_count`를 저장합니다. 객단가는 **총금액 ÷ 총거래 건수**, 사기율은 **사기 건수 합계 ÷ 사기 여부를 아는 건수 합계**로 계산합니다. 나누어지는 수가 분자이고, 나누는 기준이 되는 수가 분모입니다. 마트에는 기본적으로 활성 고객 수를 넣지 않습니다. 업종별 고유 고객 수를 더하면 여러 업종에 방문한 고객이 중복되기 때문입니다.

## 해석할 때 지켜야 할 경계

- 해시처럼 보이는 식별값만으로 실제 상점 이름을 알아낼 수 없습니다.
- 성별, 연령대 간 차이는 표본 규모와 사용 빈도 차이도 함께 봅니다.
- 특정 집단의 사기율이 높다는 관찰을 그 집단 전체에 대한 차별적인 심사 근거로 사용하지 않습니다.
- 합성 자료로 배운 패턴을 실제 고객 데이터에 적용할 때는 데이터 권한, 최소 수집, 재식별 위험을 다시 검토해야 합니다.

출처: 제공된 강의계획서 1–5주차, 기존 FinDA Advanced Lesson2의 TabFormer 적재 스키마. [IBM TabFormer](https://github.com/IBM/TabFormer), [SAFE_CAST](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/conversion_functions), [날짜 함수](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/date_functions).

