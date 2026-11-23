/*
[목적]
- A/B 가드레일(주문당 객단가)을 "몇 % 떨어지면 악화로 볼지" 정하기 위해
  할인 기간 신규 주문 금액의 편차와 주별 변동을 확인

[결과 요약]
- 주문 746건, 객단가 평균 66.44 / 중앙값 46 / 표준편차 74.86
  → 고가 주문 일부가 평균을 끌어올리는 구조 (주문 간 금액 차이 큼)
- 주별 객단가 71.75 → 63.29 → 64.88 (전체 대비 −4.7% ~ +8.0%)
- 실험 시 그룹당 약 373건 → 16.2% 이상 떨어져야 우연과 구분 가능

[판단]
- −5% 같은 고정 기준은 평소 주별 변동 범위 안이고, 검출도 불가 → 사용하지 않음
- 가드레일 규칙: 객단가가 통계적으로 유의하게 하락하면 보류
  (유의한 하락 = 약 16% 이상 하락 ≈ 손익분기 16.7%)
- 장바구니 도달자당 매출을 보조 가드레일로 추가
- 조기 중단: 결제 오류·배정 비율 이상은 즉시, 객단가는 첫 주 이후 −30% 이상일 때

[참고사항]
- 손익분기: 전환율이 +20% 오르면 객단가가 −16.7%(1 ÷ 1.2 − 1)까지 떨어져도 매출 동일
- 첫 주는 그룹당 약 112건이라 30% 이상 떨어져야 구분 가능
- 금액 분포가 치우쳐 있어 결과 분석 시 상위 1% 제외 평균·중앙값도 함께 확인
- 검산: 주문 수 746, 객단가 66.44로 40번과 일치
*/

WITH events AS (
  SELECT
    CONCAT(user_pseudo_id, '-',
      CAST((SELECT value.int_value FROM UNNEST(event_params)
            WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    ecommerce.purchase_revenue_in_usd AS revenue,
    ecommerce.transaction_id AS tx_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201123' AND '20201214'  -- 12/13 시작 세션이 자정을 넘겨 구매한 경우 포함
    AND event_name = 'purchase'
),

orders AS (                                   -- 주문 1건 = 1행
  SELECT session_key, tx_id, MAX(revenue) AS order_revenue
  FROM events
  WHERE session_key IS NOT NULL
  GROUP BY session_key, tx_id
),

target_orders AS (                            -- 할인 기간 신규의 주문만
  SELECT
    o.order_revenue,
    DATE_TRUNC(s.session_date, WEEK(MONDAY)) AS week                       -- 세션 시작일을 월요일 시작 주로 묶기
  FROM orders AS o
  JOIN `modulabs-project-465602.p1.sessions` AS s USING (session_key)
  WHERE period = 'season'
  AND session_date <= '2020-12-13'
  AND session_number = 1)

-- 전체
SELECT
  'total' AS grp,
  COUNT(*) AS orders,
  ROUND(AVG(order_revenue), 2) AS aov,
  ROUND(STDDEV(order_revenue), 2) AS sd,                -- 표준편차
  APPROX_QUANTILES(order_revenue, 2)[OFFSET(1)] AS median,                      -- 중앙값
  ROUND(1.96 * STDDEV(order_revenue) * SQRT(2 / (COUNT(*) / 2))
        / AVG(order_revenue) * 100, 1) AS detectable_drop_pct   -- 그룹당 절반씩 나눴을 때 검출 가능한 변화(%)
FROM target_orders

UNION ALL

-- 주별
SELECT
  CAST(week AS STRING),
  COUNT(*),
  ROUND(AVG(order_revenue), 2),
  ROUND(STDDEV(order_revenue), 2),
  APPROX_QUANTILES(order_revenue, 2)[OFFSET(1)],
  NULL
FROM target_orders
GROUP BY week

ORDER BY grp;