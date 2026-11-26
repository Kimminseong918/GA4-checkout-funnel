/*
[목적]
- 시즌에 할인이 있었는지 데이터로 확인
- 쿼리 ①②: 주별 프로모션·쿠폰·배송비, 쿼리 ③④: 같은 상품의 주별 가격

[결과 요약]
- 프로모션: 3개월 내내 같은 4개(Reach New Heights, Act Responsible,
  Complete Your Collection, Google Mural Collection)만 노출, 할인·시즌 프로모션 없음
- 프로모션 노출 수는 방문 수에 따라 증감 (최다 12/7 주 22,065건)
- 쿠폰이 기록된 구매 0건, 배송비가 기록된 구매 0건
- 가격은 구매 이벤트에만 기록됨 (상품 조회·장바구니 이벤트는 0건), 모든 주에 기록 있음
- 같은 상품의 주별 가격 ÷ 정상가: 전 기간 1.02~1.06으로 일정
- 정상가보다 5% 이상 싼 상품 비율: 시즌 0.3~0.7%, 시즌 전 1.5~1.9%

[판단]
- 시즌 할인 근거 없음 (프로모션·상품 가격 모두 변화 없음)
- A/B 대상 기간은 할인이 아니라 데이터 기록 상태와 행동 변화로 정함: 성수기 11/26~12/14 (29, 39번)
- 쿠폰·배송비는 기록되지 않아 결제 단계 할인·배송비 영향은 확인 불가 (한계)

[참고사항]
- 'Not available in demo dataset'은 난독화 자리 표시 값 (Google 데이터셋 설명)
- 쿠폰·배송비 0건은 "할인이 없었다"가 아니라 "기록이 없어 알 수 없다"는 뜻
- 정상가 = 상품마다 주별 가격의 중앙값 → 비율이 1보다 약간 높게 나오지만 모든 주에 같은 영향
- 6주 이상 구매 기록이 있는 상품만 사용 (상품 구성 변화의 영향 줄임)
- 쿼리 1)-4)는 각각 실행하였음
*/

-- 1) 주별 프로모션·쿠폰·배송비 건수
WITH ev AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week,
    event_name,
    items,
    ecommerce.shipping_value_in_usd AS shipping
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('view_promotion', 'select_promotion', 'purchase')
)

SELECT
  week,
  COUNTIF(event_name = 'view_promotion')   AS view_promo_events,
  COUNTIF(event_name = 'select_promotion') AS select_promo_events,
  COUNTIF(event_name = 'purchase')         AS purchase_events,
  COUNTIF(event_name = 'purchase' AND EXISTS (
    SELECT 1 FROM UNNEST(items) AS i
    WHERE i.coupon IS NOT NULL AND i.coupon NOT IN ('', '(not set)', '<Other>')
  )) AS purchase_with_coupon,
  COUNTIF(event_name = 'purchase' AND shipping IS NOT NULL)  AS purchase_with_shipping_value,
  COUNTIF(event_name = 'purchase' AND shipping = 0)          AS purchase_free_shipping,
  ROUND(AVG(IF(event_name = 'purchase', shipping, NULL)), 2) AS avg_shipping
FROM ev
GROUP BY week
ORDER BY week;


-- 2) 주별 프로모션·쿠폰 이름
SELECT
  DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week,
  event_name,
  IF(event_name = 'purchase', i.coupon, i.promotion_name) AS name,
  COUNT(*) AS item_rows
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
     UNNEST(items) AS i
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND (
    (event_name IN ('view_promotion', 'select_promotion') AND i.promotion_name IS NOT NULL)
    OR (event_name = 'purchase' AND i.coupon IS NOT NULL AND i.coupon NOT IN ('', '(not set)'))
  )
GROUP BY week, event_name, name
ORDER BY week, item_rows DESC;


-- 3) 주별 가격 기록 여부
SELECT
  DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week,
  COUNT(*)                            AS purchase_item_rows,
  COUNTIF(i.price_in_usd > 0)         AS rows_with_price,
  COUNT(DISTINCT IF(i.price_in_usd > 0, i.item_id, NULL)) AS items_with_price
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
     UNNEST(items) AS i
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'purchase'
GROUP BY week
ORDER BY week;


-- 4) 같은 상품의 주별 가격 ÷ 정상가
WITH p AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week,
    i.item_id,
    i.price_in_usd AS price
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
       UNNEST(items) AS i
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'          -- 가격은 구매 이벤트에만 기록됨
    AND i.price_in_usd > 0
    AND i.item_id IS NOT NULL
    AND i.item_id NOT IN ('', '(not set)')
),

item_week AS (
  -- 상품 × 주별 가격 (중앙값)
  SELECT item_id, week, APPROX_QUANTILES(price, 2)[OFFSET(1)] AS week_price
  FROM p
  GROUP BY item_id, week
),

item_base AS (
  -- 상품별 정상가 = 주별 가격의 중앙값, 가격이 기록된 주 수
  SELECT
    item_id,
    APPROX_QUANTILES(week_price, 2)[OFFSET(1)] AS base_price,
    COUNT(*) AS n_weeks
  FROM item_week
  GROUP BY item_id
)

SELECT
  w.week,
  COUNT(*)                                    AS items,
  ROUND(AVG(w.week_price / b.base_price), 3)  AS avg_price_ratio,       -- 1.000 = 정상가
  COUNTIF(w.week_price < b.base_price * 0.95) AS items_below_95pct,     -- 정상가보다 5% 이상 싼 상품 수
  ROUND(COUNTIF(w.week_price < b.base_price * 0.95) / COUNT(*) * 100, 1) AS pct_items_discounted
FROM item_week AS w
JOIN item_base AS b USING (item_id)
WHERE b.n_weeks >= 6
GROUP BY w.week
ORDER BY w.week;
