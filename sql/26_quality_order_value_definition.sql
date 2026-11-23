/*
[목적]
- 매출을 나누는 분모(구매 세션 / 주문 / 구매 고객)에 따라 값이 어떻게 다른지 확인하고 용어를 정함

[결과 요약]
| period | 구매 세션 | 주문  | 구매 고객 | 매출    | 구매 세션당 매출 | 주문당 객단가 | 고객당 매출 |
| off    |     1,059 | 1,113 |     1,016 |  53,507 |            50.53 |         48.07 |       52.66 |
| season |     2,369 | 2,663 |     2,203 | 185,072 |            78.12 |         69.50 |       84.01 |

[판단]
- 지금까지 '객단가'라고 부른 값(매출 ÷ 구매 세션)은 정확히는 '구매 세션당 매출'
  → KPI 트리(세션 × 세션 전환율 × 구매 세션당 매출 = 매출)에 사용
- A/B 가드레일은 한 번 주문할 때의 금액을 봐야 하므로 '주문당 객단가'(매출 ÷ 주문)를 사용
- 단위를 바꿔도 비시즌 하락폭은 −31% ~ −37%로 결론 같음

[참고사항]
- 주문 수 = SUM(tx_count). '(not set)'·NULL 주문 번호도 1건으로 셈
- 구매 고객은 user_pseudo_id(쿠키) 기준이라 기기를 바꾼 사람은 다른 고객으로 집계
- A/B 대상 집단(할인 기간 신규)의 주문당 객단가는 40번
*/

SELECT
  period,
  SUM(purchase)  AS purchase_sessions,
  SUM(tx_count)  AS orders,
  COUNT(DISTINCT IF(purchase = 1, SPLIT(session_key, '-')[OFFSET(0)], NULL)) AS buyers,
  ROUND(SUM(revenue), 0) AS revenue,
  ROUND(SAFE_DIVIDE(SUM(revenue), SUM(purchase)), 2) AS rev_per_purchase_session,
  ROUND(SAFE_DIVIDE(SUM(revenue), SUM(tx_count)), 2) AS aov_per_order,
  ROUND(SAFE_DIVIDE(
    SUM(revenue),
    COUNT(DISTINCT IF(purchase = 1, SPLIT(session_key, '-')[OFFSET(0)], NULL))
  ), 2) AS rev_per_buyer
FROM `modulabs-project-465602.p1.sessions`
WHERE period IN ('season', 'off')
GROUP BY period
ORDER BY period;
