/*
[목적]
- 엄격 기준 퍼널에서 빠진 구매 세션이 어떤 단계를 건너뛰었는지 확인

[결과 요약]
- 구매 세션 중 장바구니 기록 없음: 시즌 728 / 2,369 (30.7%), 비시즌 264 / 1,059 (24.9%)
- 결제 시작·결제 정보 기록 없음: 시즌 각 1건, 비시즌 0건
- 조회 기록 없는 구매(시즌 80, 비시즌 40)도 모두 장바구니 기록 없음

[판단]
- 건너뛴 단계는 사실상 장바구니뿐 → 결제 단계 기록은 신뢰 가능
- 사전 기준(건너뛴 구매 10% 이상) 초과
  → 엄격 기준 퍼널은 메인에서 제외, 민감도 확인용으로만 사용

[참고사항]
- 10% 기준: 구매의 10분의 1 이상이 이탈로 잘못 분류되면 단계 전환율 해석이 흔들림
- 시즌 30.7%에는 장바구니 기록이 꺼진 11/23~25가 포함됨 (29번).
  비시즌 24.9%도 기준을 넘으므로 결정은 같음
- 결제 기록 없는 1건(0.04%)은 결론에 영향 없어 처리하지 않음
*/

SELECT
  period,
  COUNT(*) AS purchase_sessions,               -- 구매가 있었던 세션 수
  COUNTIF(view_item = 0)        AS no_view,     -- 같은 세션에 상품 조회 기록 없음
  COUNTIF(add_to_cart = 0)      AS no_cart,     -- 장바구니 기록 없음
  COUNTIF(begin_checkout = 0)   AS no_checkout, -- 결제 시작 기록 없음
  COUNTIF(add_payment_info = 0) AS no_payment   -- 결제 정보 기록 없음
FROM `modulabs-project-465602.p1.sessions`
WHERE period IN ('season', 'off')
  AND purchase = 1
GROUP BY period
ORDER BY period;
