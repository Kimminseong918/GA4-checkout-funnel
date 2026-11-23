/*
[목적]
- p1.sessions가 제대로 만들어졌는지 검증 (03번 일별 합계와 대조)

[결과 요약]
| period  | sessions | purchase_sessions | 전환율 |
| pre     |   76,038 |               977 |  1.28% |
| season  |  124,133 |             2,369 |  1.91% |
| holiday |   52,769 |               443 |  0.84% |
| off     |  107,189 |             1,059 |  0.99% |

[판단]
- 시즌 구매 세션 2,369가 일별 합계와 정확히 일치 → 세션 표 사용
- 시즌 전환율이 비시즌의 약 1.93배 (하루 세션 +20%, 하루 구매 세션 2.3배)

[참고사항]
- 비시즌 1,059 vs 일별 합계 1,072 (−13): 이벤트일 vs 세션 시작일 기준 차이
- 휴일(0.84%)은 비시즌보다도 낮아 비교에서 제외한 판단을 뒷받침
*/

SELECT
  period,
  COUNT(*)      AS sessions,
  SUM(purchase) AS purchase_sessions
FROM `modulabs-project-465602.p1.sessions`
GROUP BY period
ORDER BY period;
