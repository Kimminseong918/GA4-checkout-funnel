/*
[목적]
- 기간별 add_to_cart 기록 상태 확인 (32번에서 시즌 전 결제 시작 전환율 91.75%가 비정상)

[결과 요약]
| period | 결제 시작 | 그중 장바구니 없음 | 장바구니 세션 |
| pre    |     3,067 |      2,811 (91.7%) |           532 |
| season |     5,152 |      1,523 (29.6%) |         8,360 |
| off    |     2,038 |        575 (28.2%) |         4,244 |

[판단]
- 11월 초에는 add_to_cart가 대부분 기록되지 않음 → 시즌 전은 단계별 기준선에서 제외

[참고사항]
- 시즌 전 장바구니 세션(532)이 결제 시작(3,067)보다 훨씬 적음 → 실제 행동으로 볼 수 없음
- 시즌·비시즌은 비율이 비슷해(29.6% vs 28.2%) 메인 비교에는 영향 작음
- 01번의 add_to_cart 사용자 수도 이 영향으로 과소 집계
*/

SELECT
  period,
  COUNTIF(begin_checkout = 1) AS checkout_sessions,
  COUNTIF(begin_checkout = 1 AND add_to_cart = 0) AS checkout_no_cart,
  ROUND(SAFE_DIVIDE(COUNTIF(begin_checkout = 1 AND add_to_cart = 0),
                    COUNTIF(begin_checkout = 1)) * 100, 1) AS no_cart_pct,
  COUNTIF(add_to_cart = 1) AS cart_sessions
FROM `modulabs-project-465602.p1.sessions`
WHERE period IN ('pre', 'season', 'off')
GROUP BY period
ORDER BY period;
