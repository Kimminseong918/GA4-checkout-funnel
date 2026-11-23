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
- 31·34번의 2,749세션과 1건 차이: 이 쿼리는 결제 시작 기록만 셌고,
  31·34번은 최대 도달 기준이라 결제 시작 기록 없이 구매한 1건이 포함됨
*/

SELECT
  period,
  COUNT(*) AS sessions,
  COUNTIF(country IS NULL OR country = '(not set)') AS country_missing,
  COUNTIF(device  IS NULL OR device  = '(not set)') AS device_missing,

  -- H4 대상: 신규 + 결제 시작
  COUNTIF(session_number = 1 AND begin_checkout = 1) AS h4_sessions,
  COUNTIF(session_number = 1 AND begin_checkout = 1
          AND (country IS NULL OR country = '(not set)')) AS h4_country_missing,
  COUNTIF(session_number = 1 AND begin_checkout = 1
          AND (device IS NULL OR device = '(not set)'))   AS h4_device_missing
FROM `modulabs-project-465602.p1.sessions`
WHERE period IN ('season', 'off')
GROUP BY period
ORDER BY period;