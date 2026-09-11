# 실습 파일 다운로드

- [Streamlit 기본 앱 ZIP](downloads/streamlit-starter.zip): 화면 코드, BigQuery·DuckDB 연결, 패키지 목록, 설정 예시. 실제 인증정보나 거래 데이터는 포함하지 않습니다.
- [Colab용 BigQuery→DuckDB 노트북](downloads/bigquery-duckdb.ipynb): Colab에서 파일을 업로드해 실행합니다. 자신의 집계 마트와 사용자 로그인 권한이 필요합니다.
- [수업 SQL 예제 ZIP](downloads/course-sql.zip): 웹 원고의 SQL 블록을 모았습니다. 정답·오류 설명용 코드·마지막 SELECT 교체 조각을 포함하므로 **전체 파일을 한 번에 실행하지 마세요.** 각 예제는 해당 강의·실습 설명과 함께 사용합니다.

먼저 [환경 준비](setup.md), 이후 [Streamlit과 데이터 연결](reference/dashboard-connection.md)을 읽으세요. 실제 마트 주소는 `YOUR_PROJECT`를 본인 프로젝트로 치환합니다. 파일을 수정한 뒤에는 지표 정의와 검증표도 함께 업데이트합니다.

앱 템플릿은 데이터가 없을 때 가상 결과로 채우지 않습니다. 실제 연결 준비 안내를 표시합니다. DuckDB 파일은 Colab에서 생성하며 원본 2,400만 거래 대신 검증된 작은 집계만 담습니다.
