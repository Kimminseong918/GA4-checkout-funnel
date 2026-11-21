/*
[목적]
- 원본(이벤트 1개 = 1행, 약 430만 행)을 세션 1개 = 1행 분석용 테이블 p1.sessions로 저장

[결과 요약]
| 컬럼                 | 내용                                 |
| session_key          | user_pseudo_id + '-' + ga_session_id |
| session_date         | 세션 시작일                          |
| view_item ~ purchase | 단계 이벤트 유무 (1 / 0)             |
| has_first_visit      | first_visit 이벤트 유무              |
| session_number       | 1 = 첫 방문                          |
| device, country      | 세그먼트                             |
| period               | pre / season / holiday / off         |
- 세션 약 36만 개

[판단]
- 테이블로 저장: 이후 쿼리에서 반복 사용(원본 재조회 시 쿼리당 약 1GB), 정의를 한 곳에 모음
- 기간은 세션 시작일 기준 (자정을 넘긴 세션도 한 기간에 배정)

[참고사항]
- v1(11/23부터) → v2(11/1부터, pre·holiday·has_first_visit 추가)
- v2에서 시즌 직전에 시작된 세션 8개가 pre로 올바르게 이동
*/

CREATE OR REPLACE TABLE `__프로젝트ID__` AS   -- ① 테이블 경로

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
    geo.country AS country,                          -- ② 마침표 → 쉼표
    ecommerce.purchase_revenue_in_usd AS revenue,
    ecommerce.transaction_id AS tx_id                -- ③ 별칭
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

sessions AS (
  -- 세션 1개 = 1행: 각 단계 이벤트가 있었는지 0/1로 표시
  SELECT
    session_key,
    MIN(dt) AS session_date,
    MAX(IF(event_name = 'view_item', 1, 0))         AS view_item,
    MAX(IF(event_name = 'add_to_cart', 1, 0))       AS add_to_cart,
    MAX(IF(event_name = 'begin_checkout', 1, 0))    AS begin_checkout,
    MAX(IF(event_name = 'add_shipping_info', 1, 0)) AS add_shipping_info,   -- ④ 배송 정보
    MAX(IF(event_name = 'add_payment_info', 1, 0))  AS add_payment_info,
    MAX(IF(event_name = 'purchase', 1, 0))          AS purchase,
    MAX(IF(event_name = 'purchase', revenue, NULL)) AS revenue,             -- ④ 매출 (중복 방지로 MAX)
    COUNT(DISTINCT IF(event_name = 'purchase', tx_id, NULL)) AS tx_count,  -- ④ 고유 주문 수
    MAX(IF(event_name = 'first_visit', 1, 0))       AS has_first_visit,
    MIN(session_number) AS session_number,
    ANY_VALUE(device)   AS device,
    ANY_VALUE(country)  AS country
  FROM events
  WHERE session_key IS NOT NULL
  GROUP BY session_key
)

-- 세션마다 기간 붙이기
SELECT
  *,
  CASE
    WHEN session_date BETWEEN '2020-11-01' AND '2020-11-22' THEN 'pre'
    WHEN session_date BETWEEN '2020-11-23' AND '2020-12-18' THEN 'season'
    WHEN session_date BETWEEN '2020-12-19' AND '2021-01-04' THEN 'holiday'
    WHEN session_date BETWEEN '2021-01-05' AND '2021-01-31' THEN 'off'
  END AS period
FROM sessions;
