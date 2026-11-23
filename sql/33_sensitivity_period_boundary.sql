/*
[목적]
- 기간 경계를 좁혀도(시즌 11/27~12/18, 비시즌 1/11~1/31) 결론이 같은지 확인 (민감도)

[결과 요약]
- 조회 → 구매 의도가 여전히 하락 기여 1위 (최대 도달 기준 93.6%, 엄격 기준 95.5%)
- 결제 정보 → 구매 기여는 10% 미만 유지
- 구매 의도 하락폭 −36% → −40%

[판단]
- 결론 유지: 블프 직전 주(11/23~11/26)와 연휴 직후 주(1/5~1/10)를 빼도 동일

[참고사항]
- 세션 테이블의 기간을 버리고(* EXCEPT (period)) 새 경계로 다시 지정
*/

WITH base AS (
  -- 세션 표의 period를 버리고 새 경계로 기간을 다시 붙임
  SELECT
    * EXCEPT (period),
    CASE
      WHEN session_date BETWEEN '2020-11-27' AND '2020-12-18' THEN 'season'
      WHEN session_date BETWEEN '2021-01-11' AND '2021-01-31' THEN 'off'
    END AS period
  FROM `modulabs-project-465602.p1.sessions`
  WHERE session_date BETWEEN '2020-11-27' AND '2020-12-18'
     OR session_date BETWEEN '2021-01-11' AND '2021-01-31'
),

funnel AS (
  -- 엄격 기준 퍼널
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

  -- 최대 도달 기준
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
  SELECT
    method, period, step_no, step_name, sessions,
    SAFE_DIVIDE(sessions,
                LAG(sessions) OVER (PARTITION BY method, period ORDER BY step_no)) AS step_rate
  FROM long
),

compare AS (
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
