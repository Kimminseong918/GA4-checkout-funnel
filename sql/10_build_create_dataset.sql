/*
[목적]
- 분석용 테이블을 저장할 데이터셋(p1) 생성. 최초 1회만 실행

[참고사항]
- 원본 공개 데이터가 US 리전에 있어 데이터셋도 US로 생성 (리전이 다르면 조회 불가)
- 실행 전 프로젝트 ID를 본인 GCP 프로젝트로 변경
*/

CREATE SCHEMA IF NOT EXISTS `modulabs-project-465602.p1`
OPTIONS (location = 'US');
