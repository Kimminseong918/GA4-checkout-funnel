/*
[목적]
- 세션 매출 계산 방식 결정 (모두 더하기 / 세션 최대 1건 / 주문 단위)

[결과 요약]
- 시즌 매출: 모두 더하기 194,154 / 세션 최대 1건 171,411 / 주문 단위 185,072
- 주문 단위 대비: 최대 1건은 −7.4%, 모두 더하기는 +4.9%

[판단]
- 세션 최대 1건(MAX): 한 방문의 여러 주문을 빠뜨려 과소 계산
- 모두 더하기(SUM): 같은 주문의 중복 기록까지 더해 과대 계산
- 주문 단위(세션 × 주문 번호별 금액 1개 → 합계) 채택, 세션 테이블에 반영 (11번)

[참고사항]
- 실제 매출은 MAX(하한)와 SUM(상한) 사이, 주문 단위는 그 사이의 추정값
  (번호 없는 주문 때문에 주문 단위도 약간 적게 또는 많게 잡힐 수 있음)
- MAX는 주문이 많은 시즌을 더 많이 깎아(시즌 −7.4%, 비시즌 −3.7%) 기간 비교를 왜곡
- 어느 방식이든 구매 세션당 매출 하락은 −33% ~ −35%로 결론 같음
*/

WITH purchases AS (
  -- purchase 이벤트만: 세션 키, 주문 번호, 금액
  SELECT
    CONCAT(
      user_pseudo_id, '-',
      CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)
    ) AS session_key,
    ecommerce.transaction_id AS tx_id,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),

orders AS (
  -- 주문 단위로 중복 제거
  SELECT session_key, tx_id, MAX(revenue) AS order_revenue
  FROM purchases
  GROUP BY session_key, tx_id
),

per_session AS (
  SELECT session_key, SUM(revenue) AS rev_sum, MAX(revenue) AS rev_max
  FROM purchases
  GROUP BY session_key
),

per_session_order AS (
  SELECT session_key, SUM(order_revenue) AS rev_order
  FROM orders
  GROUP BY session_key
)

SELECT
  s.period,
  ROUND(SUM(a.rev_sum), 0)   AS revenue_sum,
  ROUND(SUM(a.rev_max), 0)   AS revenue_max,
  ROUND(SUM(b.rev_order), 0) AS revenue_order
FROM per_session AS a
JOIN per_session_order AS b USING (session_key)
JOIN `modulabs-project-465602.p1.sessions` AS s USING (session_key)
WHERE s.period IN ('season', 'off')
GROUP BY s.period
ORDER BY s.period;
