/*
[목적]
- H4: 시즌 신규의 결제 시작 → 결제 정보 이탈이 모바일·미국 외 국가에서 더 큰지 확인

[결과 요약] 시즌 신규, 결제 시작 → 결제 정보 전환율
- 시즌 합걔: 모바일 45.7% vs 데스크톱 44.4% (p=0.50), 미국 외 45.3% vs 미국 44.3% (p=0.60)
- 기기·국가 8개 조합 모두 43~47%, 비시즌은 62~68% → 기기·국가 무관
- 태블릿은 결제 시작 100세션 미만이라 판정에서 제외

[판단]
- H4 기각: 모바일·미국 외가 더 낮지 않음 (z-검정 p = 0.50, 0.60, 방향도 반대)
- 시즌 신규는 모든 기기·지역에서 42.8~47.0%, 비시즌 신규는 61.5~67.8%
  → 차이를 만드는 것은 기기·국가가 아니라 시즌 여부 → 개선 대상은 시즌 신규 전체

[참고사항]
- 시즌 결제 시작 합계 2,749, 전환율 44.8%로 31번과 일치
- 남은 원인 후보(크리스마스 도착일, 가격 비교)는 35번 주별 분석으로 확인
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
