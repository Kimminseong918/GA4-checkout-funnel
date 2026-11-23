/*
[목적]
- 신규 방문 정의(방문 순서 = 1)가 첫 방문 이벤트(first_visit)와 맞는지 교차 확인

[결과 요약]
- 두 정의 일치율 98.4%, 서로 모순되는 경우 0건, 방문 순서 누락 0건
- 신규 비중: 시즌 70.7% → 비시즌 75.6%

[판단]
- 신규 방문 = 방문 순서(session_number) = 1 로 확정

[참고사항]
- 재방문 비중 감소(29.3% → 24.4%)는 31번에서 구성 변화로 분석
- 쿠키 기준이라 기기 변경·쿠키 삭제 고객도 신규로 집계
  → 신규는 실제보다 많게, 신규·재방문 차이는 실제보다 작게 나올 수 있음
*/

SELECT
  period,
  COUNT(*) AS sessions,
  COUNTIF(session_number = 1)     AS new_sessions,
  COUNTIF(session_number > 1)     AS returning_sessions,
  COUNTIF(session_number IS NULL) AS unknown,
  COUNTIF(session_number = 1 AND has_first_visit = 1) AS both_new,  -- 두 정의 모두 신규
  COUNTIF(session_number = 1 AND has_first_visit = 0) AS num_only,  -- 세션 번호만 신규
  COUNTIF(session_number > 1 AND has_first_visit = 1) AS fv_only    -- 모순 사례
FROM `modulabs-project-465602.p1.sessions`
WHERE period IN ('season', 'off')
GROUP BY period
ORDER BY period;
