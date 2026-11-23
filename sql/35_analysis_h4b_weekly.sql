/*
[목적]
- 시즌 신규의 결제 단계 이탈이 크리스마스 도착일 걱정인지, 할인 기간 최종 금액 확인 때문인지 주별 패턴으로 구분 (H4-b)

[결과 요약] 결제 시작 → 결제 정보 전환율
- 신규: 11/23 주 40.6% → 11/30 주 40.8% → 12/7 주 44.2% → 12/14 주 64.3%
- 재방문: 78.8% → 82.1% → 84.9% → 84.8% (거의 일정)

[판단]
- 도착일 걱정 기각: 배송 마감에 가까워질수록 오히려 전환율이 높아짐
- 최종 금액 확인 후 이탈 지지: 할인 주에 가장 낮고, 할인이 끝나자 비시즌 신규 수준(63.4%)으로 회복
  · 신규 블프 주 vs 마감 직전 주 −37% (p < 0.0001)
  · 재방문 −7% (p = 0.013, 크기 기준 10% 미달)
- 개선 대상을 "할인 기간(11/23~12/13) 신규의 결제 정보 단계"로 좁힘 (1,000 / 2,388 = 41.9%)

[참고사항]
- 주는 월요일 시작: 블프(금)와 사이버먼데이(월)가 서로 다른 주에 들어감
- 쿠폰 적용 실패, 예상보다 높은 총액도 같은 패턴을 만들 수 있음
  → 공통점은 "결제 화면에서야 최종 금액을 안다" → 개선안 근거로 사용
*/

SELECT
  DATE_TRUNC(session_date, WEEK(MONDAY)) AS week,
  IF(session_number = 1, 'new', 'returning') AS segment,
  COUNTIF(begin_checkout = 1 OR add_payment_info = 1 OR purchase = 1) AS c1_checkout,
  COUNTIF(add_payment_info = 1 OR purchase = 1) AS c2_payment,
  ROUND(SAFE_DIVIDE(
    COUNTIF(add_payment_info = 1 OR purchase = 1),
    COUNTIF(begin_checkout = 1 OR add_payment_info = 1 OR purchase = 1)
  ) * 100, 1) AS payment_rate
FROM `modulabs-project-465602.p1.sessions`
WHERE period = 'season'
GROUP BY week, segment
ORDER BY week, segment;
