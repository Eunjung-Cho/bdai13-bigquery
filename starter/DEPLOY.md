# 완성 대시보드 배포하기

완성 앱: https://bdai13-card-dashboard.streamlit.app/

이 저장소의 `starter/mart.duckdb`는 수업용 합성 카드 거래를 월, 업종, 채널별로 합친 파일입니다. 원본 거래와 개인별 자료는 들어 있지 않습니다. 저장된 시점의 집계이므로 BigQuery 변경 내용이 자동 반영되지는 않습니다.

1. Streamlit Community Cloud에서 GitHub 계정으로 로그인합니다.
2. Create app을 누르고 아래 값을 선택합니다.

| 항목 | 입력값 |
| --- | --- |
| Repository | `Eunjung-Cho/bdai13-bigquery` |
| Branch | `main` |
| Main file path | `starter/app.py` |
| Python | `3.14` (로컬 점검과 같은 버전) |

3. Advanced settings의 Secrets에 다음 내용을 넣습니다.

```toml
[data]
backend = "duckdb"
snapshot = "mart.duckdb"
```

4. Deploy를 누릅니다. 이 방식에는 Google 인증키가 필요 없습니다.
5. 모든 필터가 전체일 때 순거래액 `$72,187,810.03`, 거래 건수 `1,694,535`가 보이는지 확인합니다.
6. 월을 `2018-03`, 채널을 `온라인`으로 선택하면 순거래액은 `$997,883.96`, 거래 건수는 `17,630`입니다.

앱의 패키지는 `starter/requirements.txt`에서 설치합니다. 테마는 저장소 루트의 `.streamlit/config.toml`에서 읽습니다. 실제 `secrets.toml`은 GitHub에 올리지 않고 Cloud의 Secrets 입력란에만 넣습니다.

데이터를 갱신할 때는 Colab에서 `mart.duckdb`를 다시 만들고 이 폴더의 파일을 교체한 뒤 커밋하고 푸시합니다.
