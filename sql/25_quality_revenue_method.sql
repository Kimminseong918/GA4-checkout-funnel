/*
[목적]
- 세션 매출을 어떤 방식으로 계산할지 결정 (SUM / MAX / 주문 단위 비교)

[결과 요약]
| period | SUM (모두 더함) | MAX (세션 최대 1건) | 주문 단위 | 주문 단위 vs MAX |
| off    |          53,963 |              51,526 |    53,507 |           +3.8% |
| season |         194,154 |             171,411 |   185,072 |           +8.0% |

[판단]
- MAX는 한 세션의 여러 주문을 빠뜨려 과소 계산 (시즌 −8.0%), 기준(2% 미만) 초과
- SUM은 같은 주문의 중복 기록까지 더해 과대 계산 (시즌 +4.9%)
- 주문 단위(세션 × 주문 번호별 금액 하나 → 합계)를 채택해 세션 표에 반영 (11번)

[참고사항]
- 주문 번호 '(not set)' 중복이 정상 주문 번호와 같은 세션에 있으면 주문 단위도 약간 과대 가능
  → 실제 매출은 MAX(하한)와 주문 단위(상한) 사이
- 객단가 변화는 어느 방식이든 −33% ~ −35%로 같아 결론에 영향 없음
- MAX가 시즌을 더 많이 깎으므로 MAX를 쓰면 시즌·비시즌 비교가 왜곡됨
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
