/*
[목적]
- 기기·국가 비교(34번, H4)에 쓴 값이 비어 있는 세션이 얼마나 되는지 확인

[결과 요약]
- 기기: 누락 0건
- 국가: 값 없음('(not set)') 시즌 0.8%, 비시즌 0.8%
- 34번 분석 대상(시즌 신규 중 결제 시작) 기준으로는 2,748세션 중 15세션(0.5%)

[판단]
- 누락 비율 1% 미만으로 34번 결론에 영향 없음 → 별도 처리 안 함

[참고사항]
- 34번에서 국가 값 없음은 '미국 외'로 분류됨 (미국 외 1,464세션 중 15세션, 약 1%)
- 34번 대상 2,748세션 중 55세션은 태블릿이라 비교에서 제외 (표본 100세션 미만)
*/

WITH events AS (
  SELECT
    event_name,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params)
     WHERE key = 'ga_session_id') AS session_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
)

SELECT
  COUNT(*)                                               AS events,
  COUNTIF(session_id IS NULL)                            AS no_session_events,
  ROUND(COUNTIF(session_id IS NULL) / COUNT(*) * 100, 2) AS no_session_pct,
  COUNTIF(event_name = 'purchase')                       AS purchase_events,
  COUNTIF(event_name = 'purchase' AND session_id IS NULL) AS purchase_no_session
FROM events;