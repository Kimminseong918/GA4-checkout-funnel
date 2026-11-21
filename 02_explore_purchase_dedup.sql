/*
[목적]
- 구매를 이벤트 수, 주문 ID, 세션 중 무엇으로 셀지 결정

[결과 요약]
| 항목                | 수    |
| purchase 이벤트     | 5,692 |
| 주문 ID NULL        |    23 |
| 주문 ID '(not set)' |   883 |
| 같은 주문 중복 기록 |   335 |

[판단]
- 구매 = purchase가 있었던 세션 (한 세션 안의 중복은 1로 셈)

[참고사항]
- 고유 주문 ID 4,452에는 '(not set)' 1개 값이 포함됨 → 정상 ID 4,451
- 주문 ID로 확인할 수 없는 이벤트 906건(16%)
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
