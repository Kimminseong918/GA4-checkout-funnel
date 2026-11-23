/*
[목적]
- 퍼널 단계로 쓸 이벤트가 있는지, 제대로 기록됐는지 확인

[결과 요약]
- 사용자 수: 조회 61,252 → 장바구니 12,545 → 결제 시작 9,715 → 구매 4,419
- add_shipping_info(9,714)는 begin_checkout과 거의 같고, view_item_list는 71건뿐이라 제외

[판단]
- 퍼널 단계: view_item → add_to_cart → begin_checkout → add_payment_info → purchase
- add_shipping_info 제외: 결제 시작과 함께 발생해 새 정보 없음
- view_item_list 제외: 기록 누락

[참고사항]
- 사용자 수는 3개월 전체를 합친 값으로, 기간이 섞일 가능성이 있어 이벤트끼리 나눠서 전환율로 사용하지 않음
- add_to_cart는 11월 초 기록 누락으로 실제보다 적게 집계됨 (23번)
- first_visit 사용자가 약 95%: 신규 비중이 매우 높은 구조
*/

SELECT
  event_name,
  COUNT(1) AS event_count,
  COUNT(DISTINCT user_pseudo_id) AS unique_users
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY
  event_name
ORDER BY
  event_count DESC;
