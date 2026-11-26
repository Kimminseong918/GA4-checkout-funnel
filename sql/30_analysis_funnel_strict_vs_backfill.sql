/*
[목적]
- 비시즌 전환율 하락이 퍼널의 어느 단계에서 생겼는지 확인 (H2)

[결과 요약] 최대 도달 기준, 시즌 → 비시즌 하락 기여도
- 방문 → 조회 20% / 조회 → 구매 의도 67% / 구매 의도 → 결제 시작 32%
  / 결제 시작 → 결제 정보 −23% / 결제 정보 → 구매 4%
- 조회 → 결제 시작(가운데 두 단계 합) 99%: 조회 대비 결제 시작 18.1% → 9.5%
- 결제 시작 이후 단계는 하락을 오히려 상쇄 (결제 정보 단계가 비시즌에 더 높음)
- 엄격 기준 퍼널도 기여도 순위 동일

[판단]
- H2(하락이 장바구니 이후에 집중) 기각 → 하락은 결제를 시작하기 전에 생김
- 메인은 최대 도달 기준, 엄격 기준은 민감도 확인용

[참고사항]
- 엄격 기준: 앞 단계를 모두 거쳐야 도달 (AND)
- 최대 도달 기준: 그 단계 또는 이후 단계 기록이 하나라도 있으면 도달 (OR)
- 하락 기여도 = ln(비시즌율 ÷ 시즌율) ÷ 전체 단계 합계. 곱셈 구조라 로그로 나눔(순서와 무관, 합계 100%)
  +는 하락에 기여, −는 하락을 상쇄
- 조회 → 구매 의도 / 구매 의도 → 결제 시작의 배분(67% / 32%)은 장바구니 기록 차이로 다소 불확실 (29번: 정상 기간 장바구니 없는 결제 시작 시즌 20.9% vs 비시즌 28.2%).
  장바구니를 쓰지 않는 조회 → 결제 시작(99%)으로 결론을 씀
- 결제 정보 단계가 비시즌에 더 높은 이유는 31번 (시즌 신규만 유독 낮음)
- 검산: 최대 도달 기준 구매 세션 2,369 / 1,059 (전체 구매 세션과 일치)
*/

WITH base AS (
  SELECT *
  FROM `modulabs-project-465602.p1.sessions`
  WHERE period IN ('season', 'off')
),

funnel AS (
  -- ① 엄격 기준 퍼널: 앞 단계를 모두 거쳐야 도달 (AND)
  SELECT
    'strict' AS method,
    period,
    COUNT(*) AS s0,
    COUNTIF(view_item = 1) AS s1,
    COUNTIF(view_item = 1 AND add_to_cart = 1) AS s2,
    COUNTIF(view_item = 1 AND add_to_cart = 1 AND begin_checkout = 1) AS s3,
    COUNTIF(view_item = 1 AND add_to_cart = 1 AND begin_checkout = 1
            AND add_payment_info = 1) AS s4,
    COUNTIF(view_item = 1 AND add_to_cart = 1 AND begin_checkout = 1
            AND add_payment_info = 1 AND purchase = 1) AS s5
  FROM base
  GROUP BY period

  UNION ALL

  -- ② 최대 도달 기준: 그 단계 또는 이후 단계 중 하나라도 있으면 도달 (OR)
  SELECT
    'backfill' AS method,
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
  -- ③ 가로 표를 세로 표로 (단계 1개 = 1행)
  SELECT method, period, step.step_no, step.step_name, step.sessions
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
  -- ④ 단계 전환율 = 이번 단계 ÷ 바로 앞 단계 (방식별, 기간별로 따로)
  SELECT
    method, period, step_no, step_name, sessions,
    SAFE_DIVIDE(sessions,
                LAG(sessions) OVER (PARTITION BY method, period ORDER BY step_no)) AS step_rate
  FROM long
),

compare AS (
  -- ⑤ 시즌, 비시즌을 한 행에 나란히
  SELECT
    method, step_no, step_name,
    MAX(IF(period = 'season', sessions,  NULL)) AS season_n,
    MAX(IF(period = 'off',    sessions,  NULL)) AS off_n,
    MAX(IF(period = 'season', step_rate, NULL)) AS season_rate,
    MAX(IF(period = 'off',    step_rate, NULL)) AS off_rate
  FROM rates
  WHERE step_no > 0
  GROUP BY method, step_no, step_name
)

-- ⑥ 변화율과 하락 기여도 (방식별로 각각 합계 100%)
SELECT
  step_no,
  step_name,
  method,
  season_n,
  off_n,
  ROUND(season_rate * 100, 2) AS season_pct,
  ROUND(off_rate * 100, 2)    AS off_pct,
  ROUND((off_rate / season_rate - 1) * 100, 1) AS change_pct,
  ROUND(LN(off_rate / season_rate)
        / SUM(LN(off_rate / season_rate)) OVER (PARTITION BY method) * 100, 1) AS contrib_pct
FROM compare
ORDER BY step_no, method;
