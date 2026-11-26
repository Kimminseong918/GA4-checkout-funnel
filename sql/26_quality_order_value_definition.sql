/*
[목적]
- 매출을 나누는 기준(구매 세션 / 주문 / 구매 고객)에 따라 값이 어떻게 다른지 확인하고 용어 확정

[결과 요약]
- 시즌: 구매 세션당 78.12 / 주문당 69.50 / 고객당 84.01
- 비시즌: 구매 세션당 50.53 / 주문당 48.07 / 고객당 52.66
- 비시즌 하락폭: −31% ~ −37% (어느 기준이든 비슷)

[판단]
- 매출 ÷ 구매 세션 = "구매 세션당 매출" → KPI 트리에 사용
  (일 매출 = 일 세션 × 세션 전환율 × 구매 세션당 매출)
- 매출 ÷ 주문 = "주문당 객단가" → A/B 가드레일에 사용 (한 번 주문할 때의 금액을 봐야 하므로)

[참고사항]
- 주문 수는 번호 없는 주문도 1건으로 셈
- 구매 고객은 쿠키 기준이라 기기를 바꾼 사람은 다른 고객으로 집계
- A/B 대상(성수기 신규)의 주문당 객단가는 40번 (65.76)
*/

SELECT
  period,
  SUM(purchase)  AS purchase_sessions,
  SUM(tx_count)  AS orders,
  COUNT(DISTINCT IF(purchase = 1, SPLIT(session_key, '-')[OFFSET(0)], NULL)) AS buyers,
  ROUND(SUM(revenue), 0) AS revenue,
  ROUND(SAFE_DIVIDE(SUM(revenue), SUM(purchase)), 2) AS rev_per_purchase_session,
  ROUND(SAFE_DIVIDE(SUM(revenue), SUM(tx_count)), 2) AS aov_per_order,
  ROUND(SAFE_DIVIDE(
    SUM(revenue),
    COUNT(DISTINCT IF(purchase = 1, SPLIT(session_key, '-')[OFFSET(0)], NULL))
  ), 2) AS rev_per_buyer
FROM `modulabs-project-465602.p1.sessions`
WHERE period IN ('season', 'off')
GROUP BY period
ORDER BY period;
