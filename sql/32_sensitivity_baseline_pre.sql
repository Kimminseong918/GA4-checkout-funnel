/*
[목적]
- 비교 기준을 비시즌 대신 시즌 전(11/1~11/22)으로 바꿔도 결론이 같은지 확인 (민감도)

[결과 요약] 최대 도달 기준
- 시즌 전 구매 의도 → 결제 시작 전환율 91.75% (시즌 52.14%, 비시즌 42.29%) → 비정상
- 조회 → 결제 시작 합산 전환율: 시즌 18.1% / 시즌 전 16.8% / 비시즌 9.5%

[판단]
- 단계별 비교 불가: 시즌 전은 장바구니 기록이 대부분 빠짐 (29번)
- 합산으로는 비시즌만 크게 낮음 → 구매 의도 감소는 연휴가 끝난 비시즌에만 나타난 현상

[참고사항]
- 장바구니 기록이 없으면 구매 의도 단계에 결제 시작 세션만 남아 다음 단계 전환율이 높게 나옴
  → 시즌 전 기여도가 구매 의도 +162%, 결제 시작 −143%로 서로 상쇄
- 시즌 전 세션 전환율(1.28%)이 낮은 이유는 범위 밖이라 분석하지 않음
*/

WITH base AS (
  SELECT *
  FROM `modulabs-project-465602.p1.sessions`
  WHERE period IN ('pre', 'season', 'off')
),

funnel AS (
  SELECT
    period,
    COUNT(*) AS s0,
    COUNTIF(view_item = 1 OR add_to_cart = 1 OR begin_checkout = 1
            OR add_payment_info = 1 OR purchase = 1) AS s1,
    COUNTIF(add_to_cart = 1 OR begin_checkout = 1
            OR add_payment_info = 1 OR purchase = 1) AS s2,
    COUNTIF(begin_checkout = 1 OR add_payment_info = 1 OR purchase = 1) AS s3,
    COUNTIF(add_payment_info = 1 OR purchase = 1) AS s4,
    COUNTIF(purchase = 1) AS s5
  FROM base
  GROUP BY period
),

long AS (
  SELECT period, step.step_no, step.step_name, step.sessions
  FROM funnel,
  UNNEST([
    STRUCT(0 AS step_no, 'all'      AS step_name, s0 AS sessions),
    STRUCT(1 AS step_no, 'view'     AS step_name, s1 AS sessions),
    STRUCT(2 AS step_no, 'intent'   AS step_name, s2 AS sessions),
    STRUCT(3 AS step_no, 'checkout' AS step_name, s3 AS sessions),
    STRUCT(4 AS step_no, 'payment'  AS step_name, s4 AS sessions),
    STRUCT(5 AS step_no, 'purchase' AS step_name, s5 AS sessions)
  ]) AS step
),

rates AS (
  SELECT
    period, step_no, step_name,
    SAFE_DIVIDE(sessions,
                LAG(sessions) OVER (PARTITION BY period ORDER BY step_no)) AS step_rate
  FROM long
),

compare AS (
  -- 세 기간을 한 행에 나란히
  SELECT
    step_no, step_name,
    MAX(IF(period = 'season', step_rate, NULL)) AS season_rate,
    MAX(IF(period = 'off',    step_rate, NULL)) AS off_rate,
    MAX(IF(period = 'pre',    step_rate, NULL)) AS pre_rate
  FROM rates
  WHERE step_no > 0
  GROUP BY step_no, step_name
)

SELECT
  step_no,
  step_name,
  ROUND(season_rate * 100, 2) AS season_pct,
  ROUND(off_rate * 100, 2)    AS off_pct,
  ROUND(pre_rate * 100, 2)    AS pre_pct,
  -- 기준선 1: 시즌 → 비시즌 (메인 결과)
  ROUND(LN(off_rate / season_rate)
        / SUM(LN(off_rate / season_rate)) OVER () * 100, 1) AS contrib_vs_off,
  -- 기준선 2: 시즌 → 시즌 전 (민감도 확인)
  ROUND(LN(pre_rate / season_rate)
        / SUM(LN(pre_rate / season_rate)) OVER () * 100, 1) AS contrib_vs_pre
FROM compare
ORDER BY step_no;
