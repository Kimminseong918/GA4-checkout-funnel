/*
[목적]
- 시즌 신규의 결제 단계 이탈이 모바일·미국 외 국가에서 더 큰지 확인 (H4)

[결과 요약] 신규, 결제 시작 → 결제 정보 전환율
- 시즌: 모바일 45.7% vs 데스크톱 44.4% (p = 0.50), 미국 외 45.3% vs 미국 44.3% (p = 0.60)
- 기기 × 국가 4개 조합 모두 시즌 43~47%, 비시즌 62~68%

[판단]
- H4 기각: 모바일·미국 외가 더 낮지 않음 (방향도 반대)
- 차이를 만드는 것은 기기·국가가 아니라 시즌 여부 → 개선 대상은 시즌 신규 전체
- 남은 원인 후보는 주·일별 패턴으로 확인 (35, 39번)

[참고사항]
- 기기 비교는 태블릿 제외(결제 시작 100세션 미만, 56세션), 국가 비교는 태블릿 포함
  → 국가 검정값(45.3% vs 44.3%)은 아래 표의 데스크톱·모바일 합계와 약간 다름
- 국가 값 없음('(not set)')은 미국 외로 분류됨 (15세션, 27번)
- 검산: 시즌 결제 시작 합계 2,749, 전환율 44.8%로 31번과 일치
*/

WITH base AS (
  SELECT
    *,
    CASE WHEN country = 'United States' THEN 'US' ELSE 'non-US' END AS region
  FROM `modulabs-project-465602.p1.sessions`
  WHERE period IN ('season', 'off')
    AND session_number = 1
)

SELECT
  period,
  device,
  region,
  -- 결제 시작 도달: 결제 시작 또는 그 뒤 단계 중 하나라도 있음
  COUNTIF(begin_checkout = 1 OR add_payment_info = 1 OR purchase = 1) AS c1_checkout,
  -- 결제 정보 도달: 결제 정보 또는 구매
  COUNTIF(add_payment_info = 1 OR purchase = 1) AS c2_payment,
  ROUND(SAFE_DIVIDE(
    COUNTIF(add_payment_info = 1 OR purchase = 1),
    COUNTIF(begin_checkout = 1 OR add_payment_info = 1 OR purchase = 1)
  ) * 100, 1) AS payment_rate,
  ROUND((1 - SAFE_DIVIDE(
    COUNTIF(add_payment_info = 1 OR purchase = 1),
    COUNTIF(begin_checkout = 1 OR add_payment_info = 1 OR purchase = 1)
  )) * 100, 1) AS dropout_rate
FROM base
GROUP BY period, device, region
ORDER BY period, c1_checkout DESC;
