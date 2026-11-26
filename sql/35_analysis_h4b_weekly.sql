/*
[목적]
- 시즌 신규의 결제 단계 이탈이 시즌 안에서 언제 집중되는지 주별로 확인 (H4-b)

[결과 요약] 결제 시작 → 결제 정보 전환율
- 신규: 11/23 주 40.6% → 11/30 주 40.8% → 12/7 주 44.2% → 12/14 주 64.3%
- 재방문: 78.8% → 82.1% → 84.9% → 84.8% (거의 일정)

[판단]
- 결제 단계 이탈은 시즌 신규에 집중, 재방문은 시즌 내내 낮은 이탈
- 12/14 주 신규의 상승은 개선이 아니라 결제 시작 감소로 인한 분모 변화 (39번)
  → 이 결과만으로 이탈 이유(최종 금액 / 도착일)를 구분할 수 없음

[참고사항]
- 주는 월요일 시작: 블프(금)와 사이버먼데이(월)가 서로 다른 주에 들어감
- 12/14 주(12/14~18) 안에서도 12/14는 48.0%, 변화는 12/15부터 (39번)
- 신규 블프 주 vs 12/14 주 차이 p < 0.0001, 재방문 p = 0.013 (크기 기준 10% 미달)
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
