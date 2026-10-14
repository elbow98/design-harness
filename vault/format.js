/* format.js — Design.md §10 숫자·단위 표기의 구현. 의존성 없음.
   브라우저: <script src="format.js"></script> → window.fmt.krw(…)
   모듈:     import { fmt } from "./format.js" 로 쓰려면 맨 아래 export 주석을 푼다.
   값을 화면에 찍을 땐 이 함수만 쓴다. 원값은 data-value에 따로 둔다(복사·내보내기용). */
(function (root) {
  const MINUS = "−"; // 마이너스 기호 — 폭이 +와 같아 정렬이 맞는다
  const nf = (d) => new Intl.NumberFormat("ko-KR", { minimumFractionDigits: d, maximumFractionDigits: d });
  const sign = (n, s) => (n > 0 ? "+" + s : n < 0 ? MINUS + s : s);
  const isNil = (n) => n === null || n === undefined || Number.isNaN(n);
  const NONE = "–"; // 데이터 없음 — 0과 구분

  /** 만·억·조 한글 단위 (요약용). 1억 이상은 억+만 두 단위, 1조 이상은 소수 1자리 조 */
  function korUnit(n, unit) {
    const a = Math.abs(n), neg = n < 0 ? MINUS : "";
    if (a >= 1e12) return neg + nf(1).format(a / 1e12) + "조" + unit;
    if (a >= 1e8) {
      const eok = Math.floor(a / 1e8), man = Math.round((a % 1e8) / 1e4);
      if (man === 10000) return neg + nf(0).format(eok + 1) + "억" + unit;
      return neg + nf(0).format(eok) + "억" + (man ? " " + nf(0).format(man) + "만" : "") + unit;
    }
    if (a >= 1e4) return neg + nf(0).format(Math.round(a / 1e4)) + "만" + unit;
    return neg + nf(0).format(a) + unit;
  }

  const fmt = {
    NONE,
    /** 금액. mode: "full" 12,345,678원 | "short" 1억 2,346만원 | "axis" 1.2억 */
    krw(n, mode = "full") {
      if (isNil(n)) return NONE;
      if (mode === "short") return korUnit(n, "원");
      if (mode === "axis") return fmt.axis(n);
      return (n < 0 ? MINUS : "") + nf(0).format(Math.abs(Math.round(n))) + "원";
    },
    /** 개수. count(1234,"명") → 1,234명 · short면 1만 이상 1.2만명 */
    count(n, unit = "", mode = "full") {
      if (isNil(n)) return NONE;
      if (mode === "short" && Math.abs(n) >= 1e4) return nf(1).format(n / 1e4).replace(/\.0$/, "") + "만" + unit;
      return nf(0).format(n) + unit;
    },
    /** 등락률·수익률: 부호 + 소수 2자리. n은 퍼센트 값(1.23 → +1.23%) */
    change(n, digits = 2) {
      if (isNil(n)) return NONE;
      const r = Number(n.toFixed(digits));
      return sign(r, nf(digits).format(Math.abs(r)) + "%");
    },
    /** 비중·점유율: 부호 없음, 소수 1자리 */
    share(n, digits = 1) { return isNil(n) ? NONE : nf(digits).format(n) + "%"; },
    /** 비율의 차이: %p, 부호 있음 */
    pp(n, digits = 1) {
      if (isNil(n)) return NONE;
      const r = Number(n.toFixed(digits));
      return sign(r, nf(digits).format(Math.abs(r)) + "%p");
    },
    /** 차트 축: 1.2억 · 3,000만 · 1.2조 (단위 글자는 축 제목에) */
    axis(n) {
      if (isNil(n)) return "";
      const a = Math.abs(n), neg = n < 0 ? MINUS : "";
      const trim = (s) => s.replace(/\.0$/, "");
      if (a >= 1e12) return neg + trim(nf(1).format(a / 1e12)) + "조";
      if (a >= 1e8) return neg + trim(nf(1).format(a / 1e8)) + "억";
      if (a >= 1e4) return neg + nf(0).format(a / 1e4) + "만";
      return neg + nf(0).format(a);
    },
    /** 방향 클래스: 시장 데이터용 up/down, 0은 보합(빈 문자열) */
    dir(n) { return isNil(n) || n === 0 ? "" : n > 0 ? "up" : "down"; },
    /** 방향 기호 */
    arrow(n) { return isNil(n) || n === 0 ? "" : n > 0 ? "▲" : "▼"; },
    /** 날짜. mode: "table" 2026.10.14 | "short" 10월 14일(수) (다른 해면 연도 포함) | "axis" 10.14 */
    date(d, mode = "table") {
      if (isNil(d)) return NONE;
      d = d instanceof Date ? d : new Date(d);
      const y = d.getFullYear(), m = d.getMonth() + 1, day = d.getDate();
      const p = (x) => String(x).padStart(2, "0");
      if (mode === "axis") return `${p(m)}.${p(day)}`;
      if (mode === "short") {
        const wd = "일월화수목금토"[d.getDay()];
        return (y !== new Date().getFullYear() ? `${y}년 ` : "") + `${m}월 ${day}일(${wd})`;
      }
      return `${y}.${p(m)}.${p(day)}`;
    },
    /** 시각 14:05 · 상대 시간(1시간 이내) "5분 전" */
    time(d, relative = false) {
      d = d instanceof Date ? d : new Date(d);
      if (relative) {
        const min = Math.round((Date.now() - d.getTime()) / 60000);
        if (min < 1) return "방금";
        if (min < 60) return `${min}분 전`;
      }
      return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
    },
    /** 기준시점 문구: "2026.10.14 15:30 기준" */
    asOf(d) { return `${fmt.date(d)} ${fmt.time(d)} 기준`; },
  };

  root.fmt = fmt;
  if (typeof module !== "undefined") module.exports = { fmt };
})(typeof window !== "undefined" ? window : globalThis);
// export { fmt }; // ESM으로 쓸 때: 위 IIFE 대신 const fmt = …; export { fmt };
