/*
[목적]
- 장바구니 없는 구매가 "이전 세션에서 장바구니에 담았기 때문"인지 검증

[결과 요약]
| period | 장바구니 없는 구매 | 이전 세션 장바구니 있음 | 비율  |
| off    |                264 |                      42 | 15.9% |
| season |                728 |                     115 | 15.8% |

[판단]
- 사전 기준(70%)에 크게 못 미쳐 기각 → 원인 특정 불가
- 장바구니 단계를 "구매 의도(장바구니 또는 바로 결제)"로 재정의, 최대 도달 기준 퍼널 채택

[참고사항]
- 나머지 약 85%: 바로 구매, 기기 변경, 기록 누락으로 추정 (구분 불가)
- 조회 기간을 11/23 → 11/1로 넓혀도 시즌 4건만 증가 (111 → 115)
- 세션 선후는 session_key 뒷부분(ga_session_id = 시작 시각)으로 판단
- 다른 기기에서 담은 경우는 찾을 수 없어 결과는 하한값
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
