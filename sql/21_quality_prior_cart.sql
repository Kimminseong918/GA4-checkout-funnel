/*
[목적]
- 장바구니 없는 구매가 "이전 방문에서 장바구니에 담았기 때문"인지 확인

[결과 요약]
- 이전 방문에 장바구니 기록이 있는 비율: 시즌 115 / 728 (15.8%), 비시즌 42 / 264 (15.9%)
- 조회 기간을 11/1까지 넓혀도 시즌 4건만 증가 (111 → 115)

[판단]
- 사전 기준(70% 이상 설명) 미달 → 이전 방문으로는 설명 안 됨, 원인 특정 불가
- 장바구니 단계를 "구매 의도(장바구니 또는 바로 결제)"로 재정의
- 최대 도달 기준 퍼널을 메인으로 채택

[참고사항]
- 나머지 약 85%: 바로 결제, 기기 변경, 기록 누락 등으로 추정 (로그로 구분 불가)
- 방문 순서는 세션 ID(방문 시작 시각)로 판단
- 다른 기기에서 담은 경우는 연결할 수 없어 15.8%는 최소값
*/

WITH s AS (
  -- 세션 키를 사용자 ID와 세션 시작 시각으로 나누기
  SELECT
    session_key,
    period,
    add_to_cart,
    purchase,
    SPLIT(session_key, '-')[OFFSET(0)] AS user_id,
    CAST(SPLIT(session_key, '-')[OFFSET(1)] AS INT64) AS session_start
  FROM `modulabs-project-465602.p1.sessions`
),

target AS (
  -- 확인 대상: 시즌·비시즌의 장바구니 없이 구매한 세션
  SELECT *
  FROM s
  WHERE period IN ('season', 'off')
    AND purchase = 1
    AND add_to_cart = 0
)

SELECT
  t.period,
  COUNT(DISTINCT t.session_key) AS no_cart_purchases,
  COUNT(DISTINCT IF(p.session_key IS NOT NULL, t.session_key, NULL)) AS had_prior_cart
FROM target AS t
LEFT JOIN s AS p
  ON  p.user_id = t.user_id               -- 같은 사용자
  AND p.session_start < t.session_start   -- 그보다 먼저 시작한 세션
  AND p.add_to_cart = 1                   -- 그 세션에서 장바구니에 담음
GROUP BY t.period
ORDER BY t.period;
