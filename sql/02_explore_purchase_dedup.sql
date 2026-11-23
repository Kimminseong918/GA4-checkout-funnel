/*
[목적]
- 구매를 무엇으로 셀지 결정 (이벤트 수 / 주문 ID / 세션)

[결과 요약]
- 구매 이벤트 5,692건 중 같은 주문이 두 번 이상 찍힌 중복 335건
- 주문 ID 확인 불가 906건(16%): 빈 값 23건 + '(not set)' 883건
  → 이벤트 수나 주문 ID로는 구매를 정확히 셀 수 없음

[판단]
- 구매 = 구매 이벤트가 있었던 세션 (한 세션 안의 중복은 1건)
- 매출은 세션 × 주문 ID 단위로 중복 제거 후 합산 (11번, 25번)

[참고사항]
- 고유 주문 ID 4,452개 중 1개는 '(not set)' → 정상 주문 ID 4,451개
- 주문 ID가 없는 구매도 실제 구매라 삭제하지 않음
*/

SELECT
  COUNT(*) AS purchase_events,
  COUNT(DISTINCT ecommerce.transaction_id) AS unique_tx,
  COUNTIF(ecommerce.transaction_id IS NULL) AS null_tx,
  COUNTIF(ecommerce.transaction_id = '(not set)') AS not_set_tx
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'purchase';
