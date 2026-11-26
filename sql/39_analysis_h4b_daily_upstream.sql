/*
[목적]
- 12/14 주 신규의 결제 정보 전환율 상승(35번)이 실제 개선인지, 분모 변화인지 확인

[결과 요약] 신규 방문, 하루 평균
- 11/26~12/13: 결제 시작 114 → 결제 정보 48 (42.0%), 구매 의도 → 결제 시작 47.4%
- 12/15~12/18: 결제 시작 65 → 결제 정보 46 (70.5%), 구매 의도 → 결제 시작 34.2%
- 결제 정보까지 가는 사람 수는 그대로, 결제를 시작하는 사람만 줄어듦
- 구매 의도 → 구매는 약 14% → 17.0%로 큰 변화 없음
- 재방문은 전 기간 결제 정보 전환율 75~92%로 변화 없음
- 11/23~24는 구매 의도 → 결제 시작 100% (장바구니 기록 없음, 29번)

[판단]
- 35번의 상승은 개선이 아니라 분모 감소: "결제 화면을 확인만 하고 떠나던 신규"가 12/15부터 사라짐
- 결제 정보 도달 인원이 그대로라 이 상승으로는 이탈 이유(최종 금액 / 도착일)를 구분할 수 없음
- 성수기 끝 = 12/14 (결제 시작 감소 전날)

[참고사항]
- 12/15는 2020년 미국 우체국 일반 소포 마감일과 겹침 (간접 근거, 상점 자체 마감일은 아님)
- 검산: 11/26~12/14 합계 구매 의도 4,554 / 결제 시작 2,143 / 결제 정보 906 → 40번과 일치
*/

WITH s AS (
  SELECT
    session_date,
    IF(session_number = 1, 'new', 'returning') AS segment,
    (add_to_cart = 1 OR begin_checkout = 1 OR add_payment_info = 1 OR purchase = 1) AS intent,
    (begin_checkout = 1 OR add_payment_info = 1 OR purchase = 1)                     AS checkout,
    (add_payment_info = 1 OR purchase = 1)                                           AS payment,
    purchase = 1                                                                     AS bought
  FROM `modulabs-project-465602.p1.sessions`
  WHERE session_date BETWEEN '2020-11-23' AND '2020-12-18'
)

SELECT
  session_date,
  FORMAT_DATE('%a', session_date) AS weekday,
  segment,
  COUNT(*)          AS sessions,
  COUNTIF(intent)   AS intent_sessions,
  COUNTIF(checkout) AS checkout_sessions,
  COUNTIF(payment)  AS payment_sessions,
  ROUND(SAFE_DIVIDE(COUNTIF(intent),   COUNT(*)) * 100, 1)          AS visit_to_intent_pct,
  ROUND(SAFE_DIVIDE(COUNTIF(checkout), COUNTIF(intent)) * 100, 1)   AS intent_to_checkout_pct,
  ROUND(SAFE_DIVIDE(COUNTIF(payment),  COUNTIF(checkout)) * 100, 1) AS checkout_to_payment_pct,
  ROUND(SAFE_DIVIDE(COUNTIF(bought),   COUNTIF(intent)) * 100, 1)   AS intent_to_purchase_pct
FROM s
GROUP BY session_date, segment
ORDER BY segment, session_date;
