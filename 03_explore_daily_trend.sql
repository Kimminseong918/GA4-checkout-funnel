/*
[목적]
- 일별 추이로 시즌·비시즌 경계를 찾고, H1(시즌 전환율이 더 낮다) 검증

[결과 요약]
| 구간   | 기간        | 세션 전환율 |
| 시즌 전 | 11/1~11/22  |       1.28% |
| 시즌   | 11/23~12/18 |       1.91% |
| 휴일   | 12/19~1/4   |       0.84% |
| 비시즌 | 1/5~1/31    |       1.00% |
- 시즌 시작: 11/22 구매 세션 29 → 11/24 97
- 시즌 끝: 12/18 79 → 12/19 40 → 12/20 19 (배송 마감 추정)

[판단]
- 기간 정의: 시즌 11/23~12/18, 비시즌 1/5~1/31, 휴일 제외
- H1 기각 → 질문을 "비시즌 하락은 어디서, 누구에게서"로 재정의

[참고사항]
- 세션 = user_pseudo_id + ga_session_id (ga_session_id는 시작 시각이라 사용자 간 중복 가능)
- 방문 급증일(12/8, 1/6)은 전환율이 오히려 낮음 → H5
- 11/18~11/23은 purchase 이벤트가 구매 세션의 약 2배 (중복 기록 집중)
- 위 전환율은 일별 합계 기준. 세션 표 기준 값은 12번
*/

WITH events AS (
  -- 이벤트마다 날짜와 세션 키 붙이기
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS dt,
    event_name,
    CONCAT(
      user_pseudo_id, '-',
      CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)
    ) AS session_key
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
)

-- 날짜별 집계
SELECT
  dt,
  COUNT(DISTINCT session_key) AS sessions,
  COUNTIF(event_name = 'purchase') AS purchase_events,
  COUNT(DISTINCT IF(event_name = 'purchase', session_key, NULL)) AS purchase_sessions,
  SAFE_DIVIDE(
    COUNT(DISTINCT IF(event_name = 'purchase', session_key, NULL)),
    COUNT(DISTINCT session_key)
  ) AS session_cvr
FROM events
GROUP BY dt
ORDER BY dt;
