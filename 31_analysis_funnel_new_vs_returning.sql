/*
[목적]
- 비시즌 하락이 신규와 재방문 중 어디서 더 컸는지 확인 (Q2-a, H3)

[결과 요약] 최대 도달 기준 퍼널
| 단계                  | 신규 시즌 → 비시즌    | 재방문 시즌 → 비시즌  |
| 조회 → 구매 의도      | 30.75 → 17.15 (−44%) | 42.15 → 34.99 (−17%) |
| 구매 의도 → 결제 시작 | 48.32 → 36.18 (−25%) | 57.32 → 49.48 (−14%) |
| 결제 시작 → 결제 정보 | 44.82 → 63.38 (+41%) | 82.83 → 80.75 (−3%)  |
| 방문 100번당 구매     | 0.99 → 0.49          | 4.12 → 2.52          |

[판단]
- H3 잠정 지지 (통계 검정 예정)
- 시즌 신규의 결제 정보 단계 이탈(55%)을 개선 대상으로 선정 → 방향 C, H4

[참고사항]
- 하락 원인: 그룹 내 변화 약 86%, 재방문 비중 감소 약 14%
- 30번의 "결제 정보 단계는 비시즌이 더 높음"은 시즌 신규만 유독 낮았기 때문
- 시즌 신규 결제 시작 2,749세션 중 1,517세션 이탈
*/

WITH base AS (
  SELECT
    *,
    IF(session_number = 1, 'new', 'returning') AS segment
  FROM `modulabs-project-465602.p1.sessions`
  WHERE period IN ('season', 'off')
),

funnel AS (
  -- 최대 도달 기준 퍼널을 기간 × 신규/재방문별로
  SELECT
    segment,
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
  GROUP BY segment, period
),

long AS (
  SELECT segment, period, step.step_no, step.step_name, step.sessions
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
    segment, period, step_no, step_name, sessions,
    SAFE_DIVIDE(sessions,
                LAG(sessions) OVER (PARTITION BY segment, period ORDER BY step_no)) AS step_rate
  FROM long
),

compare AS (
  SELECT
    segment, step_no, step_name,
    MAX(IF(period = 'season', sessions,  NULL)) AS season_n,
    MAX(IF(period = 'off',    sessions,  NULL)) AS off_n,
    MAX(IF(period = 'season', step_rate, NULL)) AS season_rate,
    MAX(IF(period = 'off',    step_rate, NULL)) AS off_rate
  FROM rates
  WHERE step_no > 0
  GROUP BY segment, step_no, step_name
)

SELECT
  step_no,
  step_name,
  segment,
  season_n,
  off_n,
  ROUND(season_rate * 100, 2) AS season_pct,
  ROUND(off_rate * 100, 2)    AS off_pct,
  ROUND((off_rate / season_rate - 1) * 100, 1) AS change_pct,
  ROUND(LN(off_rate / season_rate)
        / SUM(LN(off_rate / season_rate)) OVER (PARTITION BY segment) * 100, 1) AS contrib_pct
FROM compare
ORDER BY step_no, segment;
