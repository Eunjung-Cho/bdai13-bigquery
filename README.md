# BDAI 13기 BigQuery 프로젝트 수업

강의계획서 기반 6회 과정의 강의, 실습, 과제, 초급용 리프레셔, SQL 검증 양식, Streamlit 앱 템플릿입니다.

공개 주소: https://eunjung-cho.github.io/bdai13-bigquery/

## 편집과 미리보기

`docs/`의 Markdown이 강의 원본입니다. Obsidian에서도 직접 열 수 있습니다. 기존 Advanced Lesson2의 MkDocs Material 구조를 유지하며 별도 경로 변환 없이 같은 파일로 웹을 만듭니다.

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe tools/export_sql.py
.\.venv\Scripts\python.exe -m mkdocs build --strict
.\.venv\Scripts\python.exe -m mkdocs serve
```

GitHub Actions는 main 변경 시 `site/`를 만들어 GitHub Pages에 배포합니다. Pages source는 GitHub Actions로 설정합니다. 강사용 메모(`instructor-notes/`), PPT 작업물, 원본 DOCX와 인증정보는 공개 배포에서 제외합니다.

## 수업 설정

- 원본 데이터: `bdai13-bigquery.tabformer` (asia-northeast3, 2026-09-17 공유 완료).
- 학생 저장 위치: `YOUR_PROJECT.bdai13`를 본인 프로젝트로 치환.
- 6주차: Streamlit + BigQuery Python 직접 연결. 예비 경로 Colab + DuckDB 스냅샷.
- 기본 언어: 한국어. 완성 SQL 실행→한 조건 수정→결과 검증.
- 공개 자료에는 실제 실행 결과를 가정해 채운 수치가 없습니다.

## 다음 PPT 단계

`slides/`의 스토리보드와 개인 스킬 `$minimal-source-ppt`를 사용합니다. 흰 배경, 흑백, 16:9, 기본 영어 제목/핵심 문장과 한국어 상세 대본이며 사용자의 언어 지시가 우선입니다. 웹 원고가 기준이고, PPT에는 핵심 도식, 예시를 남기고 긴 SQL은 실습 웹으로 연결합니다.

현재 산출물의 검수 한계: 실제 GCP 계정, 테이블에 대한 쿼리 실행과 공개 Streamlit 앱의 인증은 새 데이터 공유가 완료된 후 개강 전 확인해야 합니다.
