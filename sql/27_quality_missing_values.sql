/*
[목적]
- 분석에 쓰는 값이 비어 있는 경우가 얼마나 되는지 확인
- 쿼리 ①: 세션 ID (11번에서 세션 ID 없는 이벤트를 제외하는 조건을 넣었기 때문)
- 쿼리 ②: 기기·국가 (34번 H4 비교에 사용)

[결과 요약]
- 세션 ID 누락 0건 (전체 이벤트 약 430만 건, 구매 이벤트 5,692건 모두 세션 ID 있음)
- 기기 누락 0건
- 국가 값 없음('(not set)') 시즌 0.8%, 비시즌 0.8%
- 34번 분석 대상(시즌 신규 중 결제 시작)에서는 2,748세션 중 15세션(0.5%)

[판단]
- 세션 ID: 제외된 데이터 없음, 11번의 제외 조건은 안전장치로 유지
- 국가 값 없음: 유지. 15세션이 모두 이탈했다고 가정해도(45.8%), 모두 전환했다고 가정해도(44.7%)
  미국(44.5%)보다 낮지 않아 34번 결론 같음
- 국가를 쓰지 않는 다른 분석에서는 정상 행동 기록이라 제외하면 유효한 데이터를 버리게 됨

[참고사항]
- 세션 ID: event_params 안의 ga_session_id
- 34번에서 국가 값 없음은 '미국 외'로 분류됨
- 31·34번의 2,749세션과 1건 차이: 쿼리 ②는 결제 시작 기록만 셌고,
  31·34번은 최대 도달 기준이라 결제 시작 기록 없이 구매한 1건이 포함됨
- 쿼리 ①과 ②는 따로 실행
*/

-- ① 세션 ID 누락
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
  COUNT(*)                                                AS events,
  COUNTIF(session_id IS NULL)                             AS no_session_events,
  ROUND(COUNTIF(session_id IS NULL) / COUNT(*) * 100, 2)  AS no_session_pct,
  COUNTIF(event_name = 'purchase')                        AS purchase_events,
  COUNTIF(event_name = 'purchase' AND session_id IS NULL) AS purchase_no_session
FROM events;


-- ② 기기·국가 값 없음
SELECT
  period,
  COUNT(*) AS sessions,
  COUNTIF(country IS NULL OR country = '(not set)') AS country_missing,
  COUNTIF(device  IS NULL OR device  = '(not set)') AS device_missing,

  -- 34번 대상: 신규 + 결제 시작
  COUNTIF(session_number = 1 AND begin_checkout = 1) AS h4_sessions,
  COUNTIF(session_number = 1 AND begin_checkout = 1
          AND (country IS NULL OR country = '(not set)')) AS h4_country_missing,
  COUNTIF(session_number = 1 AND begin_checkout = 1
          AND (device IS NULL OR device = '(not set)'))   AS h4_device_missing
FROM `modulabs-project-465602.p1.sessions`
WHERE period IN ('season', 'off')
GROUP BY period
ORDER BY period;
