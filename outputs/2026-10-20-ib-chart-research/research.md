# 글로벌 IB 리서치 차트 조사 (2026-10-20)

질문: GS·MS 같은 글로벌 IB는 리포트 차트를 무엇으로, 어떤 형태로 그리나. 하네스에 무엇을 넣을까.
방법: 공개 PDF를 내려받아 페이지를 렌더해 직접 보고, PDF 메타데이터(Creator)·내장 글꼴·출처 줄을 추출했다. 2026-10-17 캡처(`reference/ib-reports/`, GS·EIA·USGS·MAS·S&P·TradeTech)에서 이미 반영한 형태는 빼고 봤다.
반영: Design.md §9 (2026-10-20 변경 이력), 견본 `vault/charts.html` 「밸류에이션·시나리오 형태」.

## 1. 도구 — 차트 소프트웨어는 어느 리포트에도 적혀 있지 않다

| 단계 | 확인한 것 | 근거 |
|---|---|---|
| 데이터 | Bloomberg, FactSet, Datastream/Refinitiv, Haver가 출처 줄에 반복 | [MS AI Rate of Change](https://www.morganstanley.com/content/dam/msdotcom/en/assets/pdfs/Research_AI-Rate-of-Change.pdf) FactSet 31회 · [JPM Guide to the Markets](https://am.jpmorgan.com/content/dam/jpm-am-aem/global/en/insights/market-insights/guide-to-the-markets/mi-guide-to-the-markets-us.pdf) · [GS 채용공고 "Haver is a plus"](https://jobs.anitab.org/companies/goldman-sachs/jobs/47092957-global-investment-research-global-macro-research-structured-credit-research-analyst) |
| 조판 | MS·DB = EidosMedia(편집 출판 시스템), GS·UBS = Word, Citi GPS = InDesign, JPM AM = PowerPoint | 각 PDF의 Creator 메타데이터 |
| 차트 | 차트 글자가 Arial·Calibri 벡터로 남아 Excel 차트를 붙인 것으로 **추정** | 위 PDF들 |
| 글꼴 | GS Univers, MS Gloriola, BofA Connections, UBS Frutiger, Citi CitiSans, DB Univers DB — 은행마다 전용 글꼴 | PDF 내장 글꼴 |

확인 못 함: think-cell·Macrobond를 특정 은행이 쓴다는 1차 근거, MS 내부 차트 도구, 은행 내부 차트 스타일 가이드. GS PlotTool은 Marquee 공개 도구로 있으나 리포트 제작에 쓰는지는 미확인([GS dev](https://developer.gs.com/discover/plottool-pro)).

→ 하네스에 옮길 것은 도구가 아니라 **형식**이다. 글꼴은 Pretendard 유지(은행 전용 글꼴은 브랜드 자산).

## 2. 은행별 관례

| 은행 | 라벨 | 제목 | 출처 줄 |
|---|---|---|---|
| GS | Exhibit N | 결론 문장 | Source: Bloomberg, Goldman Sachs Global Investment Research |
| MS | Exhibit N | 결론 문장 | Source: FactSet, Morgan Stanley Research |
| BofA | Exhibit N | 결론 문장 | Source: BofA Global Research, Bloomberg |
| JPM 리서치·AM | Figure N / 슬라이드 | 명사형 | Source: BEA, FactSet, J.P. Morgan Asset Management |
| UBS | Figure N | 명사형 | Source: UBS Research |
| Citi · Barclays · DB | Figure N | 결론·명사 혼재 / 결론 / 결론 | Source: Citi Research, BEA 등 |

공통: 출처 줄은 원 데이터 → 자사 리서치 순서. 결론형 제목은 GS·MS·BofA·Barclays·DB, 명사형은 JPM·UBS. 하네스는 문서에서 결론형(§9, 2026-10-17)을 유지한다. BofA·UBS·Barclays·DB는 제3자 재게시 사본이라 최신 관례와 다를 수 있다.

## 3. 형태 — 반영한 것

| 형태 | 출처 | 하네스에서 바꾼 점 |
|---|---|---|
| 현재 vs 과거 범위 | [JPM GTM 4Q26](https://am.jpmorgan.com/content/dam/jpm-am-aem/global/en/insights/market-insights/guide-to-the-markets/mi-guide-to-the-markets-us.pdf) 46쪽 | 진회색 막대 → `--border-strong`, 보라·하늘 마름모 → 같은 색의 채운 점/속 빈 점(모양으로 구분), 일본 축 끊기 없음 |
| 평균 ±1σ 선 | 같은 PDF 5쪽 | 그대로(실선) |
| 경기 수축기 음영 | 같은 PDF 30쪽 | `--surface-2`, 경계선 없이 라벨 |
| 기여도 누적 막대 + 합계 마름모 | 같은 PDF 17쪽, [GS ToM 133](https://www.goldmansachs.com/pdfs/insights/pages/top-of-mind/market-concentration-how-big-a-worry/report.pdf) | 점선 연간/분기 구분 → 실선, 6색 → 범주 1~5 |
| 강조 1개 + 회색 막대 | GS ToM 133 8쪽(분위 막대 `Current`, HHI 임계선) | 빨강 강조 → `--series-1` |
| 리스크-리워드 부채꼴 | [MS M Idea](https://www.morganstanley.com/content/dam/msdotcom/what-we-do/wealth-management-images/uit/vintage-values-2024.pdf) 8쪽 | 점선 목표선·옵션 확률 곡선 제외, 등락은 한국식 ▲ 빨강 / ▼ 파랑 |
| 시나리오 표 | [UBS House View 2025.02](https://advisors.ubs.com/mediahandler/media/686580/UBS%20House%20View%20for%20February%202025.pdf) 9쪽, MS 같은 쪽 | 확률 행 맨 위, `tfoot`에 확률 가중 목표가 |

## 4. 보았지만 넣지 않은 것

- 자산군 수익률 퀼트(JPM GTM 59쪽): 자산마다 고정색이라 범주 8개 상한을 넘는다.
- 3×3 스타일 박스(JPM GTM 14쪽), 연수익률 + 연중 최대낙폭(16쪽), 보유기간별 범위(60쪽), 정책 전망 vs 시장 기대(31쪽): 기존 히트맵·범위 막대·선으로 그릴 수 있어 따로 두지 않았다. 필요해지면 견본을 추가한다.
- BofA FMS 순비중·z-score: 지표는 확인했으나 차트 원본을 보지 못했다(공식 PDF 404, 보도 이미지 비어 있음).

## 5. 확인 못 한 것

풋볼필드 밸류에이션, 감응도 표, 점도표 원형, 슬로프 차트, 이익 수정 breadth는 이번에 연 문서에 나오지 않았다. Citi GPS 차트 원본, BofA Institute PDF(404), dbresearch.com(게이트), goldmansachs.com 페이지(WebFetch 403)도 열지 못했다.
