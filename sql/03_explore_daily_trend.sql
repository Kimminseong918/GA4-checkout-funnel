/*
[목적]
- 일별 추이로 시즌·비시즌 경계를 정하고, H1(시즌 전환율이 더 낮다) 검증

[결과 요약]
- 세션 전환율: 시즌 전 1.28% / 시즌 1.91% / 휴일 0.84% / 비시즌 1.00%
- 시즌 시작: 구매 세션 11/22 29건 → 11/24 97건으로 급증
- 시즌 종료: 12/18 79건 → 12/19 40건 → 12/20 19건으로 급감 (배송 마감 영향 추정)

[판단]
- 기간 확정: 시즌 11/23~12/18, 비시즌 1/5~1/31, 휴일(12/19~1/4)은 비교에서 제외
- H1 기각: 시즌 전환율이 비시즌의 약 2배
  → 질문을 "비시즌 하락은 어디서, 누구에게서 생겼나"로 변경

[참고사항]
- 세션 = 사용자 ID + 세션 ID (세션 ID는 방문 시작 시각이라 다른 사용자와 겹칠 수 있어 함께 사용)
- 방문 급증일(12/8, 1/6)은 오히려 전환율이 낮음 → H5로 기록, 범위 밖이라 보류
- 11/18~11/23은 구매 이벤트가 구매 세션의 약 2배 → 중복 기록이 몰린 구간
- 일별 합계 기준 값이라 세션 표 기준(12번)과 약간 다름 (비시즌 1.00% vs 0.99%)
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
