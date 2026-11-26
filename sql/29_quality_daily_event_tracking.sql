/*
[목적]
- 단계 이벤트가 매일 기록됐는지 확인 (기록이 꺼진 날 찾기)
- 쿼리 ①: 장바구니 기록 상태, 쿼리 ②: 나머지 단계(조회·결제 시작·결제 정보·구매)

[결과 요약]
- 장바구니: 11/1~15 꺼짐 → 11/16~19 일시 기록(11/17~18 약 62%) → 11/20~24 꺼짐
  → 11/25 부분(15.6%) → 11/26~1/31 매일 정상(결제 시작 중 장바구니 기록 60~90%)
- 시즌 전(11/1~11/22) 합계: 결제 시작 3,067세션 중 91.7%에 장바구니 기록 없음, 장바구니 세션 532개
- 꺼진 날에는 조회 세션이 1,000개 넘어도 장바구니 세션 0개
- 조회·결제 시작·결제 정보·구매: 3개월 매일 기록, 결제 정보 없는 구매 하루 0~1건

[판단]
- 장바구니 기록 공백은 행동이 아니라 추적 누락 (하룻밤 사이 변화, 다른 단계는 정상)
- 장바구니가 들어가는 분석은 11/26 이후 기준으로 확인
  · A/B 대상 성수기 시작일을 11/26으로 정함 (40번)
  · 시즌 전은 단계별 비교 기준에서 제외 (32번은 조회 → 결제 시작 합산만 사용)
  · 시즌 비교는 11/23~25 포함분을 33번 민감도로 확인
- 기록 공백은 장바구니뿐 → 결제 단계 분석(34, 35, 39번)은 영향 없음

[참고사항]
- 정상 기간에도 결제 시작의 21~28%는 장바구니 기록 없음 = 바로 결제(실제 행동)
  시즌(11/26~12/18) 20.9% vs 비시즌 28.2%로 차이가 있어 장바구니가 들어가는 두 단계의 배분은 다소 불확실 (30번)
- 01번의 장바구니 사용자 수도 이 공백 때문에 실제보다 적게 집계됨
- 조회 비율이 연휴·1월 초 13~17%, 1/20 이후 24~30%로 변동 (기록 문제 아님, 방문자 구성 변화로 추정)
- 쿼리 ①과 ②는 따로 실행
*/

-- ① 일별 장바구니 기록 상태
SELECT
  session_date,
  period,
  COUNT(*)                                         AS sessions,
  COUNTIF(add_to_cart = 1)                         AS cart_sessions,
  COUNTIF(begin_checkout = 1)                      AS checkout_sessions,
  COUNTIF(begin_checkout = 1 AND add_to_cart = 1)  AS checkout_with_cart,
  ROUND(SAFE_DIVIDE(COUNTIF(begin_checkout = 1 AND add_to_cart = 1),
                    COUNTIF(begin_checkout = 1)) * 100, 1) AS checkout_with_cart_pct
FROM `modulabs-project-465602.p1.sessions`
GROUP BY session_date, period
ORDER BY session_date;


-- ② 일별 나머지 단계 기록 상태
SELECT
  session_date,
  period,
  COUNT(*)                        AS sessions,
  COUNTIF(view_item = 1)          AS view_sessions,
  COUNTIF(begin_checkout = 1)     AS checkout_sessions,
  COUNTIF(add_payment_info = 1)   AS payment_sessions,
  COUNTIF(purchase = 1)           AS purchase_sessions,
  ROUND(SAFE_DIVIDE(COUNTIF(view_item = 1), COUNT(*)) * 100, 1)                           AS view_pct,
  ROUND(SAFE_DIVIDE(COUNTIF(add_payment_info = 1), COUNTIF(begin_checkout = 1)) * 100, 1) AS payment_per_checkout_pct,
  ROUND(SAFE_DIVIDE(COUNTIF(purchase = 1), COUNTIF(add_payment_info = 1)) * 100, 1)       AS purchase_per_payment_pct,
  COUNTIF(purchase = 1 AND add_payment_info = 0)  AS purchase_without_payment,   -- 앞 단계 누락 신호
  COUNTIF(purchase = 1 AND begin_checkout = 0)    AS purchase_without_checkout
FROM `modulabs-project-465602.p1.sessions`
GROUP BY session_date, period
ORDER BY session_date;
