/*
[목적]
- 비교 기준을 비시즌에서 시즌 전(11/1~11/22)으로 바꿔도 결론이 같은지 확인 (민감도)

[결과 요약] 최대 도달 기준 퍼널
| 단계                    | 시즌   | 비시즌    | 시즌 전 | 기여도 vs 비시즌 | 기여도 vs 시즌 전 |
| 방문 → 조회             | 22.92% | 20.07% |  24.06% |           20% |              −12% |
| 조회 → 구매 의도        | 34.74% | 22.40% |  18.29% |           67% |              162% |
| 구매 의도 → 결제 시작   | 52.14% | 42.29% |  91.75% |           32% |             −143% |
| 결제 시작 → 결제 정보   | 62.55% | 72.72% |  49.06% |          −23% |               61% |
| 결제 정보 → 구매        | 73.48% | 71.46% |  64.87% |            4% |               32% |
| 조회 → 결제 시작 (합산) |  18.1% |   9.5% |   16.8% |               |                   |

[판단]
- 단계별로는 판정 불가 (시즌 전 장바구니 기록 누락, 23번)
- 합산 비교로는 비시즌만 크게 낮음 → 구매 의도 감소는 시즌 전에는 없고 연휴가 끝난 비시즌에 나타난 현상

[참고사항]
- 시즌 전 기여도: 구매 의도 +162%, 결제 시작 −143% → 기록 누락으로 두 단계가 서로 상쇄
- 장바구니 기록이 없으면 구매 의도 단계에 결제 시작 세션만 들어와 결제 시작 전환율이 높게 나옴
- 시즌 전의 낮은 세션 전환율(1.28%)은 결제 정보·구매 단계에서 나오나 깊게 보지 않음
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
  -- 기준선 1: 시즌 → 비시즌 (기존 결과)
  ROUND(LN(off_rate / season_rate)
        / SUM(LN(off_rate / season_rate)) OVER () * 100, 1) AS contrib_vs_off,
  -- 기준선 2: 시즌 → 시즌 전 (민감도 확인)
  ROUND(LN(pre_rate / season_rate)
        / SUM(LN(pre_rate / season_rate)) OVER () * 100, 1) AS contrib_vs_pre
FROM compare
ORDER BY step_no;
