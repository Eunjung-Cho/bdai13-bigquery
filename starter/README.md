# 카드 소비 Streamlit 기본 앱

초급 실습용으로 데이터 연결 코드와 화면을 나누었습니다. 먼저 연결된 앱을 실행하고 `app.py`에서 제목·필터·차트를 한 곳씩 수정하세요.

## 직접 연결

1. 이 폴더의 내용을 새 GitHub 저장소 루트에 넣습니다. `.streamlit/config.toml`도 포함합니다.
2. 5주차의 `YOUR_PROJECT.bdai13.mart_monthly_mcc`를 준비합니다.
3. 실행 프로젝트에 BigQuery API를 활성화하고, 앱 서비스 계정에 실행 프로젝트의 BigQuery Job User와 해당 집계 마트의 BigQuery Data Viewer를 부여합니다.
4. `.streamlit/secrets.toml.example`을 참고해 Streamlit Community Cloud의 Secrets에 값을 넣습니다. 실제 인증키 파일은 저장소에 올리지 않습니다. 키 생성이 조직 정책으로 차단되어 있으면 Colab 사용자 로그인 예비 경로를 사용합니다.
5. Community Cloud에서 저장소와 `app.py`, Python 3.12 이상을 선택해 배포합니다.

`query_project`는 쿼리 실행·무료 한도 차감 프로젝트입니다. `table`은 조회할 집계 마트입니다. 원천 프로젝트 `bdai13-bigquery.tabformer`는 SQL 정제에 사용하며 앱은 그 원본을 직접 모두 읽지 않습니다. `location`은 마트와 같은 위치로 지정합니다.

BigQuery Python API는 결제 등록 없는 샌드박스 사용을 지원합니다. 무료 한도·테이블 만료·권한은 실제 프로젝트에서 확인해야 합니다. 앱은 2018년 마트를 최대 10분 캐시하고 1회 쿼리 상한을 설정합니다. 상한은 전체 사용자/월간 사용량을 제한하는 장치는 아닙니다.

## Colab과 DuckDB 예비 경로

제공 노트북으로 사용자 로그인→BigQuery 집계 마트 조회→`mart.duckdb` 생성 후 이 폴더에 넣습니다. CSV 변환은 하지 않습니다. 파일에는 공개 가능한 집계만 담고 크기를 확인하세요.

Secrets는 다음 두 줄이면 됩니다. 이 경로에는 서비스 계정이 필요하지 않습니다.

```toml
[data]
backend = "duckdb"
snapshot = "mart.duckdb"
```

스냅샷은 생성 시점의 자료이며 실시간 연결이 아닙니다. 갱신하려면 Colab에서 다시 만들고 파일을 교체해야 합니다. Colab은 데이터 준비에 쓰며 공개 앱 서버는 Community Cloud를 사용합니다.

## 로컬 실행

```text
python -m pip install -r requirements.txt
python -m streamlit run app.py
```

로컬은 `.streamlit/secrets.toml`을 사용합니다. `secrets.toml.example` 자체는 설정으로 읽히지 않습니다. 같은 조건의 SQL 결과와 앱의 금액·건수·비율을 확인한 뒤 공개합니다. 실제 데이터가 없으면 앱은 연결 안내를 보여주며, 가상 거래 결과를 대신 표시하지 않습니다.
