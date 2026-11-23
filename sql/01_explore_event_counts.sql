/*
[목적]
- 퍼널 단계로 쓸 이벤트가 제대로 기록돼 있는지 확인

[결과 요약]
- 사용자 수: 조회 61,252 → 장바구니 12,545 → 결제 시작 9,715 → 결제 정보 5,751 → 구매 4,419
- 배송 정보(add_shipping_info) 9,714명: 결제 시작과 거의 같음
- 상품 목록 조회(view_item_list) 71건: 사실상 기록 안 됨

[판단]
- 퍼널 5단계 확정: 조회 → 장바구니 → 결제 시작 → 결제 정보 → 구매
- 배송 정보 제외: 결제 시작과 동시에 찍혀 추가 정보 없음
- 상품 목록 조회 제외: 기록 누락

[참고사항]
- 3개월 전체 사용자 수라 단계끼리 나눠 전환율로 쓰지 않음
  (같은 방문의 흐름이 아니고 기간도 섞임 → 퍼널 전환율은 30번, 세션 기준)
- 장바구니는 11월 초 기록 누락으로 실제보다 적게 집계됨 (23번)
- 장바구니 단계는 이후 "구매 의도(장바구니 또는 바로 결제)"로 재정의 (21번)
- 첫 방문(first_visit) 사용자가 약 95% → 신규 비중이 매우 높은 사이트
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
