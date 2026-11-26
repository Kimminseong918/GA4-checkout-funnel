/*
[목적]
- A/B 테스트 대상(성수기 신규)의 기준값 산출: 핵심 지표, 진단 지표, 가드레일, 하루 유입

[결과 요약]
- 핵심 지표(구매 ÷ 장바구니 도달): 654 / 4,554 = 14.4%, 하루 약 240명 유입
- 진단 지표(결제 정보 ÷ 결제 시작): 906 / 2,143 = 42.3% (결제 시작의 58%가 이탈)
- 가드레일(주문당 객단가): 44,784 / 681 = 65.76

[판단]
- 핵심 지표는 "결제 정보 ÷ 결제 시작"이 아닌 "구매 ÷ 장바구니 도달"
  → 개선안은 장바구니에서 정보를 보여줌. 결제를 시작하는 사람 자체가 바뀌어
    결제 시작을 분모로 쓰면 구매가 늘지 않아도 지표가 오르는 착시가 생김 (39번에서 실제로 확인)
- 가드레일 기준은 시즌 전체(69.50)가 아닌 대상 집단 값(65.76)
- 가드레일 허용 범위는 41번에서 결정

[참고사항]
- 성수기 = 11/26~12/14 (19일)
  · 시작: 장바구니 기록이 하루 전체 정상인 첫날 (11/25는 부분 기록, 29번)
  · 끝: 결제를 시작하는 신규가 줄기 시작한 12/15의 전날 (39번)
- 신규 = 방문 순서 1 → 사람당 1세션이라 세션 수 = 사용자 수 (사용자 단위 배정과 맞음)
- 표본 수는 notebooks/p1_stat_tests.ipynb 으로 계산함
*/

SELECT
  -- 핵심 지표: 장바구니(구매 의도) 도달 → 구매
  COUNTIF(add_to_cart = 1 OR begin_checkout = 1
          OR add_payment_info = 1 OR purchase = 1) AS intent_sessions,
  COUNTIF(purchase = 1) AS purchase_sessions,
  ROUND(SAFE_DIVIDE(
    COUNTIF(purchase = 1),
    COUNTIF(add_to_cart = 1 OR begin_checkout = 1 OR add_payment_info = 1 OR purchase = 1)
  ) * 100, 1) AS intent_to_purchase_pct,
  ROUND(COUNTIF(add_to_cart = 1 OR begin_checkout = 1
                OR add_payment_info = 1 OR purchase = 1) / 19, 0) AS daily_intent,

  -- 진단 지표: 결제 시작 → 결제 정보
  COUNTIF(begin_checkout = 1 OR add_payment_info = 1 OR purchase = 1) AS checkout_sessions,
  COUNTIF(add_payment_info = 1 OR purchase = 1) AS payment_sessions,
  ROUND(SAFE_DIVIDE(
    COUNTIF(add_payment_info = 1 OR purchase = 1),
    COUNTIF(begin_checkout = 1 OR add_payment_info = 1 OR purchase = 1)
  ) * 100, 1) AS checkout_to_payment_pct,

  -- 가드레일: 주문당 객단가
  SUM(tx_count) AS orders,
  ROUND(SUM(revenue), 0) AS revenue,
  ROUND(SAFE_DIVIDE(SUM(revenue), SUM(tx_count)), 2) AS aov_per_order
FROM `modulabs-project-465602.p1.sessions`
WHERE session_date BETWEEN '2020-11-26' AND '2020-12-14'
  AND session_number = 1;
