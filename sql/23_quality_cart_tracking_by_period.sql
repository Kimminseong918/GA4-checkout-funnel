/*
[목적]
- 기간별 장바구니 기록 상태 확인 (32번에서 시즌 전 장바구니 → 결제 시작 전환율이 91.75%로 비정상)

[결과 요약]
- 결제 시작 세션 중 장바구니 기록 없음: 시즌 전 91.7% / 시즌 29.6% / 비시즌 28.2%
- 시즌 전 장바구니 세션 532개 < 결제 시작 3,067개 (장바구니가 결제 시작보다 적음)

[판단]
- 11월 초에는 장바구니가 대부분 기록되지 않음
  → 시즌 전은 단계별 비교 기준에서 제외 (조회 → 결제 시작 합산 비교만 사용)
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
