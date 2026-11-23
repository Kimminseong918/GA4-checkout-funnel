/*
[목적]
- A/B 테스트 대상 집단(할인 기간 신규)의 기준값 산출: 핵심 지표, 진단 지표, 가드레일, 하루 표본

[결과 요약]
| 지표                                   | 값     |
| 장바구니(구매 의도) 도달                | 4,682 (하루 약 223) |
| 구매 세션                              | 709    |
| 핵심: 구매 ÷ 장바구니 도달              | 15.1%  |
| 진단: 결제 정보 ÷ 결제 시작             | 41.9% (1,000 / 2,388) |
| 가드레일: 주문당 객단가                 | 66.44 (49,563 / 746) |

[판단]
- 핵심 지표를 "결제 정보 ÷ 결제 시작"이 아닌 "구매 ÷ 장바구니 도달"로 정함
  → 개선안(최종 금액 사전 표시)이 장바구니에서 개입해 결제 시작하는 사람 자체를 바꾸므로,
    결제 시작을 분모로 쓰면 구매가 늘지 않아도 지표가 오르는 착시가 생김
- 가드레일은 시즌 전체(69.50)가 아니라 대상 집단 값(66.44)을 기준으로 씀

[참고사항]
- 할인 기간 = 11/23 ~ 12/13 (21일), 신규 = session_number = 1 (사람당 한 세션이라 세션 수 = 사용자 수)
- 표본 수 계산은 notebooks/p1_stat_tests.ipynb
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
                OR add_payment_info = 1 OR purchase = 1) / 21, 0) AS daily_intent,

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
WHERE period = 'season'
  AND session_date <= '2020-12-13'
  AND session_number = 1;
