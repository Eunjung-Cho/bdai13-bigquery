# 4주차. 어디서 변했는지 찾고, 증거로 설명하기

> 2026년 10월 23일 금요일 20:00–22:00. 이번 주에는 전체 숫자를 기간과 세그먼트로 나눕니다. 변화가 나타난 위치를 찾고, AI의 요약이 표를 정확히 읽었는지 검증합니다.

[실습](lab.md) · [과제](assignment.md) · [프로젝트 안내](../project.md)

## 오늘의 목표와 시간표

- (1) 전체 변화와 세그먼트 변화를 구분합니다.
- (2) ROW_NUMBER로 연령대별 업종 Top 5를 구합니다.
- (3) 월 누락을 보완한 뒤 LAG로 전월과 비교합니다.
- (4) 기준일과 경계를 명시하여 휴면 후보를 분류합니다.
- (5) 요약 문장의 수치, 방향, 비교 대상, 근거를 확인합니다.

| 시간 | 활동 | 직접 실습 |
| --- | --- | --- |
| 20:00–20:10 | 전체→기간→세그먼트 사고법 | |
| 20:10–20:25 | 집계와 윈도우, Top N 및 LAG | |
| 20:25–20:45 | 연령대별 MCC Top 5 | 20분 |
| 20:45–20:50 | 휴식 | |
| 20:50–21:15 | 월별 변화와 채널별 분해 | 25분 |
| 21:15–21:35 | 기준일 휴면 분류 | 20분 |
| 21:35–21:50 | AI 요약 검증, 개인 프로젝트 초안 | 15분 |
| 21:50–22:00 | 공유와 데이터 마트 예고 | |

실습과 리뷰는 80분입니다. 3주차 조인 검사 결과와 [지표 정의서](../templates/metric-spec.md)를 준비합니다. 읽기 원천은 `finda-13-2026.tabformer`이며, 실제 공유 준비 상태는 [환경 준비](../setup.md)에서 확인합니다.

## 1. “왜”를 묻기 전에 “어디서”를 찾는다

전체 순거래액이 줄었다면 어떤 월, 채널, MCC에서 감소했는지 먼저 찾습니다. 이를 통해 조사 범위를 좁힐 수 있습니다. 하지만 변화가 같은 시기에 발생했다는 이유만으로 특정 캠페인이나 고객 특성이 원인이라고 결론 낼 수는 없습니다.

```mermaid
flowchart LR
    A["전체 변화<br/>얼마나 변했나"] --> B["기간 분해<br/>언제 변했나"]
    B --> C["세그먼트 분해<br/>어디서 변했나"]
    C --> D["가설과 추가 확인<br/>왜 그런가"]
```

다음은 **교육용 가상 데이터**입니다.

| 채널 | 1월 순거래액 | 2월 순거래액 | 증감액 |
| --- | ---: | ---: | ---: |
| 온라인 | 100 | 140 | +40 |
| 오프라인 | 200 | 130 | -70 |
| 전체 | 300 | 270 | -30 |

전체 -30은 +40과 -70의 합입니다. 온라인은 증가했지만 오프라인 감소가 더 큽니다. “모든 채널이 감소했다”는 요약은 틀립니다. “오프라인 이탈 때문에 줄었다”도 아직 근거가 없습니다. 이탈을 측정한 표가 아니기 때문입니다.

세그먼트 증감률의 평균은 전체 증감률이 아닙니다. 위 표의 전체 변화율은 `(270-300)/300 = -10%`입니다. +40%와 -35%의 단순 평균 2.5%를 쓰면 방향까지 반대로 나옵니다. 전체 비율은 전체 분자와 전체 분모로 다시 계산합니다.

## 2. GROUP BY는 행을 접고, 윈도우 함수는 옆에 값을 붙인다

먼저 거래를 연령대 × MCC로 집계합니다. 그 결과의 각 연령대 안에서 순거래액 순서를 매깁니다. 거래 원본에 바로 순위를 붙이면 “가장 큰 거래”를 찾게 되므로 질문이 달라집니다.

```mermaid
flowchart LR
    A["거래 행"] --> B["GROUP BY<br/>연령대 × MCC 합계"]
    B --> C["ROW_NUMBER<br/>연령대 안에서 순위"]
    C --> D["순위 1–5 선택"]
```

```sql
ROW_NUMBER() OVER (
    PARTITION BY age_band
    ORDER BY net_amount_usd DESC, mcc ASC NULLS LAST
) AS amount_rank
```

`PARTITION BY`는 순위를 새로 시작할 그룹입니다. `ORDER BY`는 그 그룹 안의 순서입니다. 동액이면 MCC 오름차순이라는 두 번째 규칙을 둡니다. ROW_NUMBER는 동률에도 각각 다른 번호를 매기며 동률의 순서는 추가 정렬 기준이 없으면 확정되지 않습니다. [GoogleSQL ROW_NUMBER](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/numbering_functions#row_number)

“정확히 최대 5개”가 목표라면 ROW_NUMBER를 씁니다. “5위와 동률인 업종도 모두”라면 RANK 등으로 정책을 바꿀 수 있지만 결과가 5행을 넘을 수 있습니다. 순위 정의는 질문의 일부입니다.

이번 수업은 순위 CTE를 만든 후 바깥 WHERE에서 필터링합니다. GoogleSQL의 QUALIFY로 윈도우 결과를 거를 수도 있지만, 먼저 집계→순위→선택의 단계를 분명히 익힙니다.

## 3. LAG는 “전월”이 아니라 “앞 행”

LAG는 정렬된 결과에서 이전 행의 값을 가져옵니다. 월별 한 행이고 월이 빠짐없이 있어야 이전 행을 전월이라고 부를 수 있습니다. [GoogleSQL LAG](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/navigation_functions#lag)

**교육용 가상 사례:** 1월 100, 3월 150만 있는 표에서 LAG를 쓰면 3월의 이전 값은 1월 100입니다. 50%는 관측된 이전 월과의 변화이지 2월 대비가 아닙니다. 2월에 거래가 0건이었다는 것이 확인되었다면 달력에 2월 0을 넣어야 합니다.

<details markdown="1">
<summary>달력 보완을 손으로 따라가는 SQL</summary>

```sql
WITH observed AS (
    SELECT DATE '2018-01-01' AS tx_month, NUMERIC '100' AS amount
    UNION ALL
    SELECT DATE '2018-03-01', NUMERIC '150'
), calendar AS (
    SELECT tx_month
    FROM UNNEST(GENERATE_DATE_ARRAY(
        DATE '2018-01-01', DATE '2018-03-01', INTERVAL 1 MONTH
    )) AS tx_month
), filled AS (
    SELECT c.tx_month, COALESCE(o.amount, NUMERIC '0') AS amount
    FROM calendar AS c LEFT JOIN observed AS o USING (tx_month)
), compared AS (
    SELECT *, LAG(amount) OVER (ORDER BY tx_month) AS previous_amount
    FROM filled
)
SELECT *, SAFE_DIVIDE(amount - previous_amount, previous_amount) AS mom_rate
FROM compared ORDER BY tx_month;
```

</details>

1월은 비교할 앞 달이 없어 NULL입니다. 2월은 -100%, 3월은 분모가 0이므로 NULL입니다. “3월 무한 성장”이나 “성장률 0%”라고 바꾸지 않습니다. `SAFE_DIVIDE`는 0으로 나누는 오류를 NULL로 처리합니다. [GoogleSQL SAFE_DIVIDE](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/mathematical_functions#safe_divide)

달력의 0은 **데이터 수집이 완전한 기간에 해당 세그먼트 거래가 없는 경우**에만 사용합니다. 수집 누락이나 정제 실패를 0으로 숨기지 않습니다. 먼저 전체 기간 프로파일과 실패 행 수를 확인하고, 원천 누락이면 변화율 해석을 보류합니다.

## 4. 휴면은 사실이 아니라 규칙으로 만든 분류

오늘의 기준일은 `DATE '2019-01-01'`입니다. 그날 시작 시점에서 알고 있는 거래만 사용하므로 거래일이 기준일보다 작은 행만 봅니다. 마지막 거래로부터 90일 이상이면 **90일 이상 미거래 후보**, 90일 미만이면 **90일 미만 거래 관측**, 이전 유효 거래가 없으면 **관측 이력 없음**입니다.

| 마지막 유효 거래일 | 기준일과의 차이 | 분류 |
| --- | ---: | --- |
| 2018-10-03 | 90일 | 90일 이상 미거래 후보 |
| 2018-10-04 | 89일 | 90일 미만 거래 관측 |
| NULL | 계산하지 않음 | 관측 이력 없음 |
| 2019-01-02 | 미래 거래 | 기준일 분석에서 제외 |

이 날짜 표는 **교육용 경계 예시**입니다. `DATE_DIFF(기준일, 마지막거래일, DAY)` 순서를 거꾸로 쓰면 음수가 됩니다. [GoogleSQL DATE_DIFF](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/date_functions#date_diff)

휴면 분류는 2018년 집계와 달리 기준일 **이전 전체 관측 이력**이 필요합니다. 2017년에 마지막으로 거래한 고객을 “거래 없음”으로 바꾸지 않기 위해서입니다. 고객 스냅샷이 2019년 당시 명단과 같다는 보장은 없으므로 결과를 역사적 실제 휴면 고객 명단이라고 부르지 않습니다.

## 5. AI 요약에서 확인할 네 가지

| 검증 대상 | 질문 |
| --- | --- |
| 수치 | 금액과 비율을 실제 표에서 찾을 수 있는가? |
| 방향 | 증가와 감소, 순위 방향이 일치하는가? |
| 비교 대상 | 전월, 전년, 이전 관측 행을 혼동하지 않았는가? |
| 근거의 범위 | 관측을 원인으로, 미거래 후보를 실제 이탈로 단정하지 않았는가? |

프롬프트에 “표에 없는 원인은 제안할 수 있으나 추정이라고 표시하고 필요한 추가 자료를 적으라”고 요청합니다. AI의 자신감 있는 문장도 실제 결과의 셀과 연결되지 않으면 채택하지 않습니다. 개인정보가 없는 집계표와 지표 정의만 전달합니다.

## 6. 개인 프로젝트를 시작한다

오늘부터 개인별로 질문 한 개를 고정하고 SQL과 검증 기록을 쌓습니다. 공동 발표를 준비하더라도 각자의 기여와 검증 과정을 추적할 수 있어야 합니다. 개인 작업과 팀 리뷰를 연결하는 세부 운영은 강사 안내를 확인합니다.

[프로젝트 문서](../project.md)에 질문, 분석 기간, 세그먼트, 지표 정의, 필요한 검증 두 개를 적습니다. “고객 행동 분석”보다는 “2018년 온라인 순거래액의 월별 변화가 어느 MCC에 집중되는가?”처럼 쿼리로 답할 수 있게 좁힙니다.

## 오늘의 핵심

순위를 매기기 전에 집계하고, 전월을 비교하기 전에 월을 채우고, 휴면을 분류하기 전에 기준일을 정합니다. 결과를 설명할 때는 숫자와 방향을 확인한 뒤 관찰과 가설을 구분합니다. 다음 주에는 반복해서 쓰는 정제와 집계를 뷰와 데이터 마트로 정리합니다.

## 출처

- 제공 강의계획서, 4주차 “분해 분석과 인사이트”.
- [ROW_NUMBER](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/numbering_functions#row_number), [LAG](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/navigation_functions#lag).
- [GENERATE_DATE_ARRAY](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/array_functions#generate_date_array), [DATE_DIFF](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/date_functions#date_diff).
