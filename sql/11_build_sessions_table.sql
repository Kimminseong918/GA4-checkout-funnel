/*
[목적]
- 원본(이벤트 1건 = 1행, 약 430만 행)을 세션(방문 1회) = 1행 분석용 테이블로 저장

[결과 요약]
- 약 36만 세션 생성
- 컬럼: 단계별 도달 여부(1/0), 매출, 주문 수, 신규 여부, 기기, 국가, 기간
- 컬럼 상세는 docs/project_overview.md (데이터 구조화)

[판단]
- 테이블로 저장: 모든 분석이 같은 정의를 쓰도록 하고, 원본 반복 조회 비용 절감 (쿼리당 약 1GB)
- 기간은 세션 시작일 기준: 자정을 넘긴 방문도 한 기간에만 배정
- 매출은 주문 단위로 중복 제거 후 합산 (25번)
  · 같은 주문이 여러 번 기록되면 1번만 반영
  · 한 방문에서 주문을 여러 번 하면 모두 반영

[참고사항]
- 주문 번호가 없는 구매(빈 값, '(not set)')도 삭제하지 않고 매출에 포함
  단, 번호가 없으면 같은 주문인지 구분할 수 없어 약간 적게 또는 많게 잡힐 수 있음
  → 실제 매출은 MAX(하한)와 SUM(상한) 사이, 주문 단위는 그 사이의 추정값 (25번)
- 기기·국가는 세션 안에서 바뀌지 않는다고 보고 임의의 1개 값 사용 (ANY_VALUE)
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
