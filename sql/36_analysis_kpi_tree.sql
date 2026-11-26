/*
[목적]
- 시즌 → 비시즌 일 매출 하락을 일 세션 수 · 세션 전환율 · 구매 세션당 매출로 분해 (KPI 트리)

[결과 요약]
- 일 매출: 시즌 7,118 → 비시즌 1,982 (−72.2%)
- 일 세션 4,774 → 3,970 / 세션 전환율 1.91% → 0.99% / 구매 세션당 매출 78.1 → 50.5
- 하락 기여: 세션 전환율 51.5% / 구매 세션당 매출 34.1% / 일 세션 수 14.4%

[판단]
- 1월 매출 하락의 절반은 덜 사서(전환율), 3분의 1은 적게 사서(구매 세션당 매출)
  방문 감소는 작은 부분 → 유입 확대만으로는 하락의 일부만 회복
- 전환율 하락은 30번에서 단계별로 다시 분해

[참고사항]
- 일 매출 = 일 세션 수 × 세션 전환율 × 구매 세션당 매출 (세 값을 곱하면 일 매출)
- 곱셈 구조라 변화율을 더하면 합이 맞지 않고(−17 −48 −35 ≠ −72), 하나씩 바꾸면 순서에 따라 결과가 달라짐
  → 로그로 바꿔 덧셈으로 나눈 뒤 기여 비율 계산 (30번과 같은 방법, 합계 100%)
- 객단가(매출 ÷ 주문) 대신 구매 세션당 매출을 쓰는 이유: 전환율의 분자가 구매 세션이라
  같은 단위로 맞춰야 곱셈이 성립 (26번)
- 하루 평균: 시즌 26일, 비시즌 27일
*/

WITH p AS (
  SELECT
    period,
    COUNT(DISTINCT session_date) AS days,
    COUNT(*)      AS sessions,
    SUM(purchase) AS purchase_sessions,
    SUM(revenue)  AS revenue
  FROM `modulabs-project-465602.p1.sessions`
  WHERE period IN ('season', 'off')
  GROUP BY period
),

k AS (
  SELECT
    period,
    revenue / days                      AS daily_revenue,
    sessions / days                     AS daily_sessions,
    purchase_sessions / sessions        AS session_cvr,
    revenue / purchase_sessions         AS rev_per_purchase_session
  FROM p
),

w AS (
  -- 시즌, 비시즌을 한 행에 나란히
  SELECT
    MAX(IF(period = 'season', daily_revenue, NULL))            AS s_rev,
    MAX(IF(period = 'off',    daily_revenue, NULL))            AS o_rev,
    MAX(IF(period = 'season', daily_sessions, NULL))           AS s_ses,
    MAX(IF(period = 'off',    daily_sessions, NULL))           AS o_ses,
    MAX(IF(period = 'season', session_cvr, NULL))              AS s_cvr,
    MAX(IF(period = 'off',    session_cvr, NULL))              AS o_cvr,
    MAX(IF(period = 'season', rev_per_purchase_session, NULL)) AS s_rps,
    MAX(IF(period = 'off',    rev_per_purchase_session, NULL)) AS o_rps
  FROM k
)

SELECT
  ROUND(s_rev, 0) AS season_daily_revenue,
  ROUND(o_rev, 0) AS off_daily_revenue,
  ROUND((o_rev / s_rev - 1) * 100, 1) AS revenue_change_pct,
  ROUND(LN(o_ses / s_ses) / LN(o_rev / s_rev) * 100, 1) AS contrib_sessions_pct,
  ROUND(LN(o_cvr / s_cvr) / LN(o_rev / s_rev) * 100, 1) AS contrib_cvr_pct,
  ROUND(LN(o_rps / s_rps) / LN(o_rev / s_rev) * 100, 1) AS contrib_rev_per_purchase_pct
FROM w;
