# 실습 파일 다운로드

6주차 실습에서 내려받을 파일은 **Streamlit 앱 ZIP 하나**입니다.

- [Streamlit 앱 ZIP](downloads/streamlit-app.zip): 6주차 실습용 앱 폴더입니다. 화면 코드, 데이터 읽기 코드, 패키지 목록, 설정이 들어 있고 Colab에서 받은 `mart.duckdb`만 넣으면 실행됩니다. 실제 인증정보나 거래 데이터는 포함하지 않습니다.
- [Colab에서 BigQuery→DuckDB 노트북 열기](https://colab.research.google.com/github/Eunjung-Cho/bdai13-bigquery/blob/main/docs/downloads/bigquery-duckdb.ipynb): 브라우저에서 바로 엽니다. 5주차에 만든 `YOUR_PROJECT.bdai13.mart_monthly_mcc`가 있어야 하며, 로그인한 Google 계정으로 그 표를 읽을 수 있어야 합니다.
- [BigQuery 직접 연결용 앱 ZIP](downloads/streamlit-starter.zip): 수업 실습에는 필요하지 않습니다. 서비스 계정으로 BigQuery를 직접 읽게 바꿀 때만 씁니다.
- [BigQuery→DuckDB 노트북 파일 ZIP 다운로드](downloads/bigquery-duckdb-notebook.zip): 노트북 파일 자체가 필요한 경우 다운로드합니다.
- [수업 SQL 예제 ZIP](downloads/course-sql.zip): 웹 원고의 SQL 블록을 모았습니다. 정답, 오류 설명용 코드, 마지막 SELECT 교체 조각을 포함하므로 **전체 파일을 한 번에 실행하지 마세요.** 각 예제는 해당 강의, 실습 설명과 함께 사용합니다.

먼저 [환경 준비](setup.md), 이후 [Streamlit과 데이터 연결](reference/dashboard-connection.md)을 읽으세요. 노트북의 기본 주소 `bdai13-bigquery`는 강사 프로젝트입니다. **모두 실행 전에** 설정 셀의 실행 프로젝트와 마트 주소를 본인 값으로 바꾸고, 리전이 서울(`asia-northeast3`)인지 확인합니다. 파일을 수정한 뒤에는 지표 정의와 검증표도 함께 업데이트합니다.

앱 화면에 ‘마트를 읽지 못했습니다’가 나오면 `mart.duckdb`가 `app.py` 옆에 있는지 확인하세요. DuckDB 파일은 Colab에서 생성하며 원본 2,400만 거래 대신 검증된 작은 집계만 담습니다.
