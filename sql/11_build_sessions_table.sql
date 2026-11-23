/*
[목적]
- 원본(이벤트 1개 = 1행, 약 430만 행)을 세션 1개 = 1행 분석용 테이블 p1.sessions로 저장

[결과 요약]
- 세션(방문 1회) 1행, 약 36만 세션. 단계별 도달 여부·매출·주문 수·기간 컬럼 생성
- 컬럼 설명은 docs/project_overview.md (데이터 정의)

[판단]
- 테이블로 저장: 이후 쿼리에서 반복 사용(원본 재조회 시 쿼리당 약 1GB), 정의를 한 곳에 모음
- 기간은 세션 시작일 기준 (자정을 넘긴 세션도 한 기간에 배정)
- 매출은 주문 단위 중복 제거: 같은 주문의 중복 기록은 한 번만, 한 세션의 여러 주문은 모두 합산 (25번)

[참고사항]
- v1(11/23부터) → v2(11/1부터, pre·holiday·has_first_visit) → v3(add_shipping_info, revenue, tx_count)
- v2에서 시즌 직전에 시작된 세션 8개가 pre로 올바르게 이동. v3에서 세션·구매 세션 수 변동 없음 (12번)
- 주문 번호가 NULL인 구매도 GROUP BY에서 하나의 묶음으로 처리되어 매출에 포함됨
- 실행 전 프로젝트 ID를 본인 GCP 프로젝트로 변경
*/

CREATE OR REPLACE TABLE `modulabs-project-465602.p1.sessions` AS

WITH events AS (
  -- 이벤트 1개 = 1행: 필요한 컬럼만 꺼내고 세션 키 붙이기
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS dt,
    event_name,
    CONCAT(
      user_pseudo_id, '-',
      CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)
    ) AS session_key,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
    device.category AS device,
    geo.country AS country,
    ecommerce.purchase_revenue_in_usd AS revenue,
    ecommerce.transaction_id AS tx_id
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

orders AS (
  -- 주문 단위로 중복 제거: 같은 세션의 같은 주문 번호는 금액 하나만
  SELECT
    session_key,
    tx_id,
    MAX(revenue) AS order_revenue
  FROM events
  WHERE event_name = 'purchase'
    AND session_key IS NOT NULL
  GROUP BY session_key, tx_id
),

session_revenue AS (
  -- 세션별 매출 합계와 주문 수
  SELECT
    session_key,
    SUM(order_revenue) AS revenue,
    COUNT(*) AS tx_count
  FROM orders
  GROUP BY session_key
),

sessions AS (
  -- 세션 1개 = 1행: 단계 이벤트 유무와 세그먼트 정보
  SELECT
    session_key,
    MIN(dt) AS session_date,
    MAX(IF(event_name = 'view_item', 1, 0))         AS view_item,
    MAX(IF(event_name = 'add_to_cart', 1, 0))       AS add_to_cart,
    MAX(IF(event_name = 'begin_checkout', 1, 0))    AS begin_checkout,
    MAX(IF(event_name = 'add_shipping_info', 1, 0)) AS add_shipping_info,
    MAX(IF(event_name = 'add_payment_info', 1, 0))  AS add_payment_info,
    MAX(IF(event_name = 'purchase', 1, 0))          AS purchase,
    MAX(IF(event_name = 'first_visit', 1, 0))       AS has_first_visit,
    MIN(session_number) AS session_number,
    ANY_VALUE(device)   AS device,
    ANY_VALUE(country)  AS country
  FROM events
  WHERE session_key IS NOT NULL
  GROUP BY session_key
)

-- 세션마다 매출과 기간 붙이기 (구매 없는 세션은 revenue NULL)
SELECT
  s.*,
  r.revenue,
  r.tx_count,
  CASE
    WHEN s.session_date BETWEEN '2020-11-01' AND '2020-11-22' THEN 'pre'
    WHEN s.session_date BETWEEN '2020-11-23' AND '2020-12-18' THEN 'season'
    WHEN s.session_date BETWEEN '2020-12-19' AND '2021-01-04' THEN 'holiday'
    WHEN s.session_date BETWEEN '2021-01-05' AND '2021-01-31' THEN 'off'
  END AS period
FROM sessions AS s
LEFT JOIN session_revenue AS r USING (session_key);
