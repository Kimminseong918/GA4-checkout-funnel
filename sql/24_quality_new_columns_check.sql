/*
[목적]
- 세션 표 v3에 추가한 컬럼(add_shipping_info, revenue, tx_count)이 쓸 수 있는지 확인

[결과 요약]
| period | 결제 시작 | 배송 정보 | 구매 세션 | 금액 없는 구매 | 주문 2건 이상 세션 | 매출    |
| off    |     2,038 |     2,038 |     1,059 |              0 |                 29 |  53,507 |
| season |     5,152 |     5,151 |     2,369 |              0 |                160 | 185,072 |

[판단]
- 배송 정보 이벤트는 결제 시작과 거의 100% 같이 기록 → 결제 구간 세분화에 사용하지 않음
- 금액 없는 구매 0건 → 금액 필드(purchase_revenue_in_usd) 사용 가능
- 매출이 25번의 주문 단위 계산과 일치 → 세션 표 매출 확정

[참고사항]
- 배송 정보 이벤트는 실제 주소 입력이 아니라 결제 화면 진입 시 함께 기록되는 것으로 보임
  → "배송비를 보고 떠났다"는 추정은 로그로 확인 불가, A/B로 검증할 가설로 둠
- 주문 2건 이상 세션이 시즌 6.8%로 적지 않아 세션 내 MAX 방식 대신 주문 단위 합산을 채택 (25번)
*/

SELECT
  period,
  COUNTIF(begin_checkout = 1)    AS checkout_sessions,
  COUNTIF(add_shipping_info = 1) AS shipping_sessions,
  SUM(purchase)                  AS purchase_sessions,
  COUNTIF(purchase = 1 AND revenue IS NULL) AS purchase_no_revenue,
  COUNTIF(tx_count > 1)          AS multi_order_sessions,
  ROUND(SUM(revenue), 0)         AS revenue
FROM `modulabs-project-465602.p1.sessions`
WHERE period IN ('season', 'off')
GROUP BY period
ORDER BY period;
