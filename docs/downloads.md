# 실습 파일 다운로드

- [Streamlit 기본 앱 ZIP](downloads/streamlit-starter.zip): 화면 코드, BigQuery, DuckDB 연결, 패키지 목록, 설정 예시. 실제 인증정보나 거래 데이터는 포함하지 않습니다.
- [Colab에서 BigQuery→DuckDB 노트북 열기](https://colab.research.google.com/github/Eunjung-Cho/bdai13-bigquery/blob/main/docs/downloads/bigquery-duckdb.ipynb): 브라우저에서 바로 열어 셀을 차례대로 실행합니다. 5주차에 만든 자신의 집계 마트가 있어야 하며, 로그인한 Google 계정으로 그 표를 읽을 수 있어야 합니다.
- [BigQuery→DuckDB 노트북 파일 ZIP 다운로드](downloads/bigquery-duckdb-notebook.zip): 노트북 파일 자체가 필요한 경우 다운로드합니다.
- [수업 SQL 예제 ZIP](downloads/course-sql.zip): 웹 원고의 SQL 블록을 모았습니다. 정답, 오류 설명용 코드, 마지막 SELECT 교체 조각을 포함하므로 **전체 파일을 한 번에 실행하지 마세요.** 각 예제는 해당 강의, 실습 설명과 함께 사용합니다.

먼저 [환경 준비](setup.md), 이후 [Streamlit과 데이터 연결](reference/dashboard-connection.md)을 읽으세요. 예제 주소의 `YOUR_PROJECT`를 본인의 프로젝트 ID로 바꾸면 됩니다. 파일을 수정한 뒤에는 지표 정의와 검증표도 함께 업데이트합니다.

아직 데이터를 연결하지 않았다면 앱에는 연결 방법 안내가 나옵니다. 숫자나 차트가 보이지 않을 때는 안내에 따라 연결 설정부터 확인하세요. DuckDB 파일은 Colab에서 생성하며 원본 2,400만 거래 대신 검증된 작은 집계만 담습니다.
