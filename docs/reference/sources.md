# 출처와 읽을거리

교과목 범위와 일정은 제공된 「BDAI 13기 강의계획서 프로젝트분반 Final」을 따릅니다. 6주차 도구는 사용자의 추가 지시에 따라 Streamlit으로 변경했습니다. 설명·작은 데이터 표·연습 문제는 수업을 위한 확장 자료이며, 실제 데이터에서 실행한 결과와 구분합니다.

## 데이터

- [IBM TabFormer](https://github.com/IBM/TabFormer): 합성 신용카드 거래 데이터의 원저자 저장소.
- 원천의 수업용 컬럼명은 기존 FinDA Advanced Lesson2 강의 자료를 참고했습니다. 13기 공유 테이블의 스키마·행 수·권한은 개강 전 확인합니다.

## BigQuery

- [샌드박스](https://docs.cloud.google.com/bigquery/docs/sandbox): 무료 환경과 기능·만료 제약.
- [요금과 무료 사용량](https://cloud.google.com/bigquery/pricing): 저장·쿼리 사용량 기준.
- [비용 추정과 제어](https://docs.cloud.google.com/bigquery/docs/best-practices-costs): dry run, 최대 청구 바이트, 스캔 최적화.
- [GoogleSQL 쿼리 구문](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/query-syntax): SELECT·JOIN·GROUP BY·QUALIFY.
- [변환 함수](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/conversion_functions): CAST와 SAFE_CAST.
- [집계 함수](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/aggregate_functions): COUNT·COUNTIF·SUM.
- [날짜 함수](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/date_functions): DATE_TRUNC·PARSE_DATE.
- [수학 함수](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/mathematical_functions): SAFE_DIVIDE.
- [윈도우 함수](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/window-function-calls): 그룹과 순서, 윈도우 계산.
- [파티션 테이블](https://docs.cloud.google.com/bigquery/docs/partitioned-tables): 기간별 데이터 분할.
- [클러스터 테이블](https://docs.cloud.google.com/bigquery/docs/clustered-tables): 필터에 따른 블록 가지치기.
- [클라이언트 라이브러리 빠른 시작](https://docs.cloud.google.com/bigquery/docs/quickstarts/quickstart-client-libraries): 결제 등록 없는 샌드박스에서 Python으로 조회하는 경로.

## Streamlit과 예비 경로

- [Streamlit의 BigQuery 연결](https://docs.streamlit.io/develop/tutorials/databases/bigquery): Python 클라이언트와 Secrets.
- [Community Cloud](https://docs.streamlit.io/deploy/streamlit-community-cloud): GitHub 기반 무료 앱 배포.
- [캐싱](https://docs.streamlit.io/develop/concepts/architecture/caching): 데이터 조회 재실행과 TTL.
- [Secrets 관리](https://docs.streamlit.io/deploy/streamlit-community-cloud/deploy-your-app/secrets-management): 인증값을 코드 밖에서 설정.
- [DuckDB Python](https://duckdb.org/docs/stable/clients/python/overview.html): Python에서 SQL과 파일 데이터베이스 사용.
- [Colab FAQ](https://research.google.com/colaboratory/faq.html): 런타임·자원·사용 범위.

운영 조건 확인일은 2026-09-11입니다. 무료 한도, 서비스 화면과 정책은 바뀔 수 있으므로 개강 전에 링크의 최신 안내를 다시 확인합니다.
