/*
[목적]
- 신규 방문 정의(session_number = 1)를 first_visit 이벤트와 교차 확인

[결과 요약]
| period | 신규           | 재방문         | 두 정의 일치 | 모순 |
| off    | 81,054 (75.6%) | 26,135 (24.4%) |        98.4% |    0 |
| season | 87,822 (70.7%) | 36,311 (29.3%) |        98.4% |    0 |

[판단]
- 신규 방문 = session_number = 1 로 확정

[참고사항]
- session_number 누락 0건
- 재방문 비중이 시즌 29.3% → 비시즌 24.4%로 감소 (구성 변화, 31번)
- 쿠키 기준이라 기기 변경·쿠키 삭제 고객은 신규로 집계 → 신규 과대, 신규·재방문 차이 과소 추정 가능
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
