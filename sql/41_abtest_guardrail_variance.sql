/*
[목적]
- A/B 가드레일(주문당 객단가)을 "몇 % 떨어지면 악화로 볼지" 정하기 위해
  성수기 신규 주문 금액의 편차와 주별 변동을 확인

[결과 요약]
- 주문 681건, 객단가 평균 65.76 / 중앙값 약 45 / 표준편차 72.94
  → 고가 주문 일부가 평균을 끌어올리는 구조 (주문 간 금액 차이 큼)
- 주별 객단가 71.46 / 63.29 / 64.88 (전체 대비 −3.8% ~ +8.7%, 12/14 하루는 33건이라 제외)
- 그룹당 약 340건 → 16.7% 이상 떨어져야 유의하게 나옴
  (실제 하락을 80% 확률로 잡으려면 약 24% 필요)

[판단]
- −5% 같은 고정 기준은 평소 주별 변동 범위 안이고 판정도 불가 → 사용하지 않음
- 가드레일 규칙: 객단가가 통계적으로 유의하게 하락하면 보류
  (유의한 하락 = 약 17% 이상 하락 ≈ 손익분기 17.4%)
- 객단가 단독으로는 손익분기 수준 하락을 잡을 확률이 약 50%
  → 장바구니 도달자당 매출을 보조 가드레일로 함께 판단
- 조기 중단: 결제 오류·배정 비율 이상은 즉시, 객단가는 첫 주 이후 −30% 이상일 때

[참고사항]
- 손익분기: 전환율이 +21% 오르면 객단가가 −17.4%(1 ÷ 1.21 − 1)까지 떨어져도 매출 동일
- 첫 주는 그룹당 약 125건이라 약 28% 이상 떨어져야 유의하게 나옴 → 기준 −30%
- 금액 분포가 치우쳐 있어 결과 분석 시 상위 1% 제외 평균·중앙값도 함께 확인
- 중앙값은 근사 함수(APPROX_QUANTILES)라 실행마다 ±1 정도 달라질 수 있음
- 주별 행의 유의 기준·80% 검출 열은 실험 전체 기간에만 의미가 있어 비워 둠(NULL)
- 검산: 주문 681건, 객단가 65.76으로 40번과 일치
  (끝 날짜를 12/15로 둬야 12/14 시작·12/15 구매 주문이 포함됨)
*/

WITH events AS (
  SELECT
    CONCAT(user_pseudo_id, '-',
      CAST((SELECT value.int_value FROM UNNEST(event_params)
            WHERE key = 'ga_session_id') AS STRING)) AS session_key,
    ecommerce.purchase_revenue_in_usd AS revenue,
    ecommerce.transaction_id AS tx_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201126' AND '20201215'  -- 12/14 시작 세션이 자정을 넘겨 구매한 경우 포함
    AND event_name = 'purchase'
),

orders AS (                                   -- 주문 1건 = 1행
  SELECT session_key, tx_id, MAX(revenue) AS order_revenue
  FROM events
  WHERE session_key IS NOT NULL
  GROUP BY session_key, tx_id
),

target_orders AS (                            -- 성수기 신규의 주문만
  SELECT
    o.order_revenue,
    DATE_TRUNC(s.session_date, WEEK(MONDAY)) AS week
  FROM orders AS o
  JOIN `modulabs-project-465602.p1.sessions` AS s USING (session_key)
  WHERE s.session_date BETWEEN '2020-11-26' AND '2020-12-14'
    AND s.session_number = 1
)

-- 전체
SELECT
  'total' AS grp,
  COUNT(*) AS orders,
  ROUND(AVG(order_revenue), 2) AS aov,
  ROUND(STDDEV(order_revenue), 2) AS sd,
  APPROX_QUANTILES(order_revenue, 2)[OFFSET(1)] AS median,
  ROUND(1.96 * STDDEV(order_revenue) * SQRT(2 / (COUNT(*) / 2))
        / AVG(order_revenue) * 100, 1) AS significant_drop_pct,   -- 유의하게 나오는 최소 하락폭
  ROUND(2.80 * STDDEV(order_revenue) * SQRT(2 / (COUNT(*) / 2))
        / AVG(order_revenue) * 100, 1) AS detectable_drop_80pct    -- 80% 확률로 잡는 하락폭
FROM target_orders

UNION ALL

-- 주별
SELECT
  CAST(week AS STRING),
  COUNT(*),
  ROUND(AVG(order_revenue), 2),
  ROUND(STDDEV(order_revenue), 2),
  APPROX_QUANTILES(order_revenue, 2)[OFFSET(1)],
  NULL,
  NULL
FROM target_orders
GROUP BY week

ORDER BY grp;
