/*
[목적]
- H4-b: 시즌 신규의 결제 정보 이탈이 크리스마스 도착일 걱정인지, 할인 기간 가격 비교인지 주별 패턴으로 구분

[결과 요약] 결제 시작 → 결제 정보 전환율, 최대 도달 기준
| 주 (월요일 시작) | 기간           | 신규 (결제 시작) | 재방문 |
| 11/23 주         | 블프           | 40.6% (754)      | 78.8%  |
| 11/30 주         | 사이버먼데이   | 40.8% (817)      | 82.1%  |
| 12/7 주          | 방문 최다      | 44.2% (817)      | 84.9%  |
| 12/14 주         | 배송 마감 직전 | 64.3% (361)      | 84.8%  |

[판단]
- 크리스마스 도착일 후보 기각: 마감에 가까워질수록 오히려 전환율이 높아짐
- 가격 비교(최종 금액 확인 후 이탈) 후보 지지: 할인 주에 가장 낮고 할인 후 비시즌 신규 수준(63.4%)으로 회복
- 신규 블프 주 vs 마감 직전 주 −37% (p < 0.0001), 재방문 −7% (p = 0.013, 크기 기준 미달) → H4-b 지지
- 개선 대상을 "할인 기간(11/23~12/13) 신규의 결제 정보 단계"로 좁힘 (3주 합계 1,000 / 2,388 = 41.9%)

[참고사항]
- WEEK(MONDAY)로 블프(금)와 사이버먼데이(월)가 각각 다른 주에 온전히 들어가게 함
- 쿠폰 적용 실패, 예상보다 높은 총액도 같은 패턴을 만들 수 있음 → 공통점은 "결제 화면에서야 최종 금액을 안다"
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
