/*
[목적]
- 세션 테이블 v3에 추가한 컬럼(배송 정보, 매출, 주문 수)을 분석에 쓸 수 있는지 확인

[결과 요약]
- 배송 정보: 결제 시작 세션의 99.98%에 함께 기록 (시즌 5,151 / 5,152)
- 금액 없는 구매: 0건
- 주문 2건 이상 세션: 시즌 160 (6.8%), 비시즌 29 (2.7%)
- 매출: 시즌 185,072, 비시즌 53,507 (25번 주문 단위 계산과 일치)

[판단]
- 배송 정보는 결제 시작과 사실상 같은 시점 기록 → 결제 구간 세분화에 사용 안 함
- 금액 필드 사용 가능, 세션 테이블 매출 확정

[참고사항]
- 배송 정보는 실제 주소 입력이 아니라 결제 화면 진입 시 기록되는 것으로 보임
  → "배송비를 보고 떠났다"는 로그로 확인 불가, A/B로 검증할 가설로 둠
- 한 방문에 여러 번 주문하는 경우가 적지 않아 매출은 주문 단위 합산 사용 (25번)
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
