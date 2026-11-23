/*
[목적]
- 엄격 기준 퍼널에서 빠진 구매 세션(시즌 728, 비시즌 264)이 어떤 단계를 건너뛰었는지 확인

[결과 요약]
| period | 구매  | 조회 없음 | 장바구니 없음 | 결제 시작 없음 | 결제 정보 없음 |
| off    | 1,059 |        40 |   264 (24.9%) |              0 |              0 |
| season | 2,369 |        80 |   728 (30.7%) |              1 |              1 |

[판단]
- 건너뛴 구매는 전부 장바구니 단계 → 결제 단계 기록은 신뢰 가능
- 사전 기준(10%) 초과, 기간별 비율도 다름 → 엄격 기준 퍼널을 메인으로 쓰지 않음

[참고사항]
- 조회 없는 구매도 모두 장바구니 기록이 없음
- 결제 기록 없는 1건(0.04%)은 결론에 영향 없어 별도 처리하지 않음
- v1, v2 테이블 결과 동일
*/

SELECT
  period,
  COUNT(*) AS purchase_sessions,               -- 구매가 있었던 세션 수
  COUNTIF(view_item = 0)        AS no_view,     -- 같은 세션에 상품 조회 기록 없음
  COUNTIF(add_to_cart = 0)      AS no_cart,     -- 장바구니 기록 없음
  COUNTIF(begin_checkout = 0)   AS no_checkout, -- 결제 시작 기록 없음
  COUNTIF(add_payment_info = 0) AS no_payment   -- 결제 정보 기록 없음
FROM `modulabs-project-465602.p1.sessions`
WHERE period IN ('season', 'off')
  AND purchase = 1
GROUP BY period
ORDER BY period;
