# 홍보 웹페이지 Figma WF 디자인 적용 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기능이 완성된 정적 홍보 웹페이지(`WEB/`)에 Figma WF(웹버전) 디자인 — 날씨 테마 4종(+안개), F1~F5 결과 연출, 길흉 도장, 한지풍 랭킹 전체보기 — 을 입힌다.

**Architecture:** 공용 `style.css`(리셋·`[hidden]`·폰트·유동 스케일 변수 `--f`·도장)와 페이지 전용 `home.css`/`ranking.css`로 나눈다. 크기는 전부 `clamp(모바일, calc(모바일 + 차이 * var(--f)), 데스크탑)`으로 두 시안 사이를 보간하고, 구조가 달라지는 곳만 640px에서 분기한다. 홈 연출은 `body`의 `stage-*` 클래스 교체 + CSS transition, 결론 타이핑만 JS 타이머다.

**Tech Stack:** 순수 HTML/CSS/JS, Google Fonts(Gowun Batang, Noto Sans KR, Noto Serif KR 서브셋).

**참고 스펙:** `docs/superpowers/specs/2026-09-15-promo-web-figma-design-apply-design.md` (섹션 번호는 이 문서 기준)

## Global Constraints

- 빌드 도구·프레임워크·npm 의존성을 추가하지 않는다. 외부 리소스는 Google Fonts CSS 링크뿐이다.
- 테스트 프레임워크는 없다. 각 태스크 검증은 `node --check`, 아래 id 계약 스크립트, `python -m http.server`로 띄운 실제 브라우저 확인으로 한다.
- 아래 id는 이름·개수(각 1개) 그대로 유지한다. 새 id는 이와 겹치지 않게만 추가한다.
  - `index.html`: `weather-widget, weather-city, weather-desc, dream-input, submit-btn, input-error, result, result-theme, result-vibe, result-feelings, result-reply, exhausted-modal, exhausted-message, modal-close, interpret-form`
  - `ranking.html`: `ranking-date, mine-card, mine-name, mine-rank, mine-goto, ranking-list, ranking-loading, ranking-empty, ranking-error`
- `WEB/style.css`에 `[hidden] { display: none !important; }` 규칙이 항상 있어야 한다.
- 서버에서 온 카테고리 이름은 `textContent`로만 넣는다(`innerHTML` 금지).
- 밤 테마, 랭킹 검색바는 만들지 않는다.
- 유동 스케일 공식: `clamp(Mpx, calc(Mpx + (D−M) * var(--f)), Dpx)` — M은 360px 시안 값, D는 1280px 시안 값. `--f`는 `style.css` `:root`에 정의.
- 구조 분기 브레이크포인트는 `@media (max-width: 640px)` 하나만 쓴다.
- `API_BASE_URL`은 기존 값(`http://localhost:8000`)을 건드리지 않는다.
- 커밋 메시지 끝에 `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`를 붙인다. main에 직접 머지하지 않고 PR로 올린다.

### 공용 검증 명령 (각 태스크에서 참조)

**V1 — JS 문법:**
```bash
node --check WEB/app.js && node --check WEB/ranking.js && node --check WEB/categoryDictionary.js && echo JS_OK
```
Expected: `JS_OK`

**V2 — id 계약 + CSS 괄호 + hidden 규칙:**

아래 내용을 **레포 밖**(세션 scratchpad 등)에 `check_web_contract.py`로 저장한 뒤, 워크트리 루트에서 `python <저장경로>/check_web_contract.py`로 실행한다. (heredoc으로 넘기는 방식은 워크트리 격리 세션에서 차단된다. 이 스크립트는 계획 작성 시 수정 전 코드에 대고 돌려 `OK`를 확인했다.)

```python
from html.parser import HTMLParser
from collections import Counter
import re, sys

class P(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = Counter()
    def handle_starttag(self, tag, attrs):
        for k, v in attrs:
            if k == "id":
                self.ids[v] += 1

CONTRACT = {
    "WEB/index.html": ["weather-widget", "weather-city", "weather-desc", "dream-input", "submit-btn",
                       "input-error", "result", "result-theme", "result-vibe", "result-feelings",
                       "result-reply", "exhausted-modal", "exhausted-message", "modal-close", "interpret-form"],
    "WEB/ranking.html": ["ranking-date", "mine-card", "mine-name", "mine-rank", "mine-goto",
                         "ranking-list", "ranking-loading", "ranking-empty", "ranking-error"],
}
ok = True
for path, ids in CONTRACT.items():
    p = P()
    p.feed(open(path, encoding="utf-8").read())
    for i in ids:
        if p.ids[i] != 1:
            print(f"{path}: id '{i}' count={p.ids[i]}")
            ok = False
    dup = [k for k, c in p.ids.items() if c > 1]
    if dup:
        print(f"{path}: duplicate ids {dup}")
        ok = False

import glob
for css in glob.glob("WEB/*.css"):
    text = re.sub(r"/\*.*?\*/", "", open(css, encoding="utf-8").read(), flags=re.S)
    if text.count("{") != text.count("}"):
        print(f"{css}: brace mismatch {text.count('{')} vs {text.count('}')}")
        ok = False

if "[hidden]" not in open("WEB/style.css", encoding="utf-8").read():
    print("WEB/style.css: [hidden] rule missing")
    ok = False

print("OK" if ok else "FAIL")
sys.exit(0 if ok else 1)
```
Expected: `OK`

**V3 — 로컬 서빙:**
```bash
python -m http.server 5500 --directory WEB
```
브라우저에서 `http://localhost:5500/` 접속. BE 연동이 필요한 확인은 루트에서 venv 활성화 후 `cd BE && WEB_ORIGIN=http://localhost:5500 uvicorn app.main:app --reload`(PowerShell: `$env:WEB_ORIGIN="http://localhost:5500"; uvicorn app.main:app --reload`).

---

## File Structure

| 파일 | 상태 | 책임 |
|---|---|---|
| `WEB/style.css` | 수정 | 공용 리셋, `[hidden]`, 폰트 변수, `--f`, 길흉 도장 `.seal` |
| `WEB/categoryDictionary.js` | 수정 | 사전 데이터 + `luckOf(category)`, `createSeal(luck)` |
| `WEB/ranking.html` | 수정 | 랭킹 전체보기 마크업 |
| `WEB/ranking.css` | 신규 | 랭킹 전용 스타일 |
| `WEB/ranking.js` | 수정 | 랭킹 렌더링, 펼침 트랜지션, 내 꿈 카드 두 상태 |
| `WEB/index.html` | 수정 | 홈 마크업(하늘·땅·입력·미리보기·결과·팝업) |
| `WEB/home.css` | 신규 | 홈 전용: 테마 토큰, 일러스트, 입력, 미리보기, 결과 연출, 팝업 |
| `WEB/app.js` | 수정 | 테마 적용, 날씨, 랭킹 미리보기, 제출·단계 연출 |

태스크 순서: Task 1(공용) → Task 2(랭킹 페이지, 독립 완결) → Task 3(홈 F1) → Task 4(홈 F2~F5) → Task 5(통합 검증·PR).

---

## Task 1: 공용 기반 — 폰트·유동 스케일 변수·길흉 도장

**Files:**
- Modify: `WEB/style.css:1-5` (`:root`), 파일 끝에 `.seal` 추가
- Modify: `WEB/categoryDictionary.js:18` (`LUCK_LABEL`) 및 파일 끝에 헬퍼 추가

**Interfaces:**
- Produces:
  - CSS 변수 `--font-serif`, `--font-sans`, `--f` (`:root`)
  - CSS 컴포넌트 `.seal` + 수식자 `.seal-g` / `.seal-h` / `.seal-b`, 크기 변수 `--seal-size`(기본 40px), 색 변수 `--seal-color`
  - JS 전역 `LUCK_LABEL = { g: "길몽", h: "흉몽", b: "조건에 따라 갈림" }`
  - JS 전역 `luckOf(category: string) -> "g" | "h" | "b"` (사전에 없으면 `"b"`)
  - JS 전역 `createSeal(luck: "g"|"h"|"b") -> HTMLSpanElement` (`<span class="seal seal-{luck}" role="img" aria-label="..."><span>吉</span>…</span>`)

- [ ] **Step 1: `style.css`의 `:root`에 공용 변수 추가**

`WEB/style.css` 1~5행을 아래로 교체한다(기존 `--bg/--fg/--accent`는 Task 3에서 홈 옛 규칙과 함께 지운다):

```css
:root {
  --bg: #eef1f7;
  --fg: #1f2430;
  --accent: #5b6bff;

  --font-serif: "Gowun Batang", "Noto Serif KR", serif;
  --font-sans: "Noto Sans KR", -apple-system, BlinkMacSystemFont, sans-serif;
  /* 360px 화면에서 0px, 1280px 화면에서 1px.
     clamp(모바일값, calc(모바일값 + 차이 * var(--f)), 데스크탑값)으로 두 시안 사이를 선형 보간한다. */
  --f: calc((100vw - 360px) / 920);
}
```

- [ ] **Step 2: `style.css` 파일 끝에 길흉 도장 추가**

```css
/* 길흉 도장 — Figma "Seal · 길흉 도장"(672:15). 기준 40px 안에 36px 바깥 원·30px 안쪽 원.
   Figma의 -9°는 반시계 기준이라 CSS에서는 +9deg다. */
.seal {
  --seal-size: 40px;
  --seal-color: #be241f;
  position: relative;
  display: inline-flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  width: var(--seal-size);
  height: var(--seal-size);
  transform: rotate(9deg);
  font-family: var(--font-serif);
  font-weight: 700;
  font-size: calc(var(--seal-size) * 0.425);
  line-height: 1.18;
  color: var(--seal-color);
}
.seal::before,
.seal::after {
  content: "";
  position: absolute;
  border-style: solid;
  border-color: var(--seal-color);
  border-radius: 50%;
}
.seal::before {
  inset: 5%;
  border-width: calc(var(--seal-size) * 0.04);
  opacity: 0.85;
}
.seal::after {
  inset: 12.5%;
  border-width: calc(var(--seal-size) * 0.02);
  opacity: 0.45;
}
.seal > span { opacity: 0.9; }
.seal-g { --seal-color: #be241f; }
.seal-h { --seal-color: #1e2836; }
.seal-b {
  --seal-color: #49525f;
  font-size: calc(var(--seal-size) * 0.25);
  line-height: 1.05;
}
```

- [ ] **Step 3: `categoryDictionary.js` 라벨 변경 + 헬퍼 추가**

18행 `const LUCK_LABEL = { g: "길몽", h: "흉몽", b: "양면" };`를 아래로 교체한다:

```javascript
const LUCK_LABEL = { g: "길몽", h: "흉몽", b: "조건에 따라 갈림" };
const LUCK_GLYPHS = { g: ["吉"], h: ["凶"], b: ["吉", "凶"] };

function luckOf(category) {
  const entry = CATEGORY_DICTIONARY[category];
  return entry ? entry.luck : "b";
}

// 홈 결과 화면과 랭킹 목록이 같은 도장을 쓴다. 글자는 상수라도 DOM으로 만들어 innerHTML을 피한다.
function createSeal(luck) {
  const seal = document.createElement("span");
  seal.className = `seal seal-${luck}`;
  seal.setAttribute("role", "img");
  seal.setAttribute("aria-label", LUCK_LABEL[luck]);
  for (const glyph of LUCK_GLYPHS[luck]) {
    const span = document.createElement("span");
    span.textContent = glyph;
    seal.appendChild(span);
  }
  return seal;
}
```

- [ ] **Step 4: 문법·계약 검증**

Run: V1, V2
Expected: `JS_OK`, `OK`

- [ ] **Step 5: 도장 렌더 확인**

V3로 서빙 후 `http://localhost:5500/ranking.html`을 열고(BE 없어도 됨) 개발자도구 콘솔에서:

```javascript
["g", "h", "b"].forEach((l) => document.body.prepend(createSeal(l)));
document.querySelectorAll(".seal").forEach((s) => (s.style.margin = "12px"));
```

Expected: 페이지 맨 위에 吉(빨강)·凶(먹빛)·吉凶(회색, 두 글자 세로) 도장 3개가 이중 원 안에 시계방향으로 살짝 기울어져 보인다. 폰트 링크는 Task 2에서 붙으므로 이 시점 글꼴은 시스템 세리프여도 된다. 확인 후 새로고침으로 원복.

- [ ] **Step 6: Commit**

```bash
git add WEB/style.css WEB/categoryDictionary.js
git commit -m "$(cat <<'EOF'
feat: 웹 공용 폰트·유동 스케일 변수와 길흉 도장 컴포넌트 추가

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: 랭킹 전체보기 페이지 (한지 디자인 + F3 해몽 전 + F4 자동 펼침)

**Files:**
- Modify: `WEB/ranking.html` (전체 교체)
- Create: `WEB/ranking.css`
- Modify: `WEB/ranking.js` (전체 교체)
- Modify: `WEB/style.css` — 옛 랭킹 규칙 블록 삭제

**Interfaces:**
- Consumes: `luckOf`, `createSeal`, `CATEGORY_DICTIONARY`(Task 1), `--f`·`--font-*`·`.seal`(Task 1), `GET /demo/ranking` → `{ date: "YYYY-MM-DD", items: [{ rank, category }] }`, `sessionStorage["lastDreamCategory"]`
- Produces: 없음(페이지 완결)

- [ ] **Step 1: `style.css`에서 옛 랭킹 규칙 삭제**

`WEB/style.css`에서 `.ranking-page { max-width: 640px; }` 줄부터 파일 끝의 `.ranking-loading { … }` 블록까지(원본 105~209행: `.ranking-page`, `.back-link`, `.ranking-header .date`, `.mine-card`, `.mine-name`, `.mine-rank`, `.mine-goto`, `.ranking-list`, `.ranking-item`, `.ranking-row` 계열, `.ranking-panel` 계열, `.badge` 계열, `.ranking-empty`, `@media (max-width: 480px)`, `.ranking-loading`)를 삭제한다. **Task 1에서 파일 끝에 추가한 `.seal` 블록은 남긴다** — 옛 블록은 `.seal` 주석 줄 바로 앞에서 끝난다.

- [ ] **Step 2: `ranking.html` 전체 교체**

```html
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Re-view — 오늘 사람들이 많이 꾼 꿈</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Gowun+Batang:wght@400;700&family=Noto+Sans+KR:wght@400;500;700&display=swap" />
  <!-- Gowun Batang에 凶 글리프가 없을 때를 대비한 폴백. 두 글자만 서브셋으로 받는다. -->
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Serif+KR:wght@700&text=%E5%90%89%E5%87%B6&display=swap" />
  <link rel="stylesheet" href="style.css" />
  <link rel="stylesheet" href="ranking.css" />
</head>
<body class="ranking-body">
  <nav class="rk-nav">
    <a href="index.html" class="rk-back" aria-label="홈으로">←<span class="rk-back-text"> 홈으로</span></a>
    <span class="rk-logo">굿모닝 드림</span>
    <span class="rk-nav-title">전체보기</span>
  </nav>

  <main class="rk-content">
    <header class="rk-header">
      <div class="rk-title">
        <h1>오늘 사람들이 많이 꾼 꿈</h1>
        <p id="ranking-date" class="rk-date"></p>
      </div>

      <div id="mine-card" class="mine-card" hidden>
        <span class="mine-label">내가<br />해몽한 꿈</span>
        <span id="mine-name" class="mine-name"></span>
        <span id="mine-rank" class="mine-rank"></span>
        <button id="mine-goto" class="mine-goto" type="button">순위 보기</button>
      </div>
    </header>

    <ul class="rk-legend" aria-label="길흉 표시 안내">
      <li><span class="seal seal-g" aria-hidden="true"><span>吉</span></span>길몽</li>
      <li><span class="seal seal-h" aria-hidden="true"><span>凶</span></span>흉몽</li>
      <li><span class="seal seal-b" aria-hidden="true"><span>吉</span><span>凶</span></span>조건에 따라 갈림</li>
    </ul>

    <p id="ranking-loading" class="rk-status">불러오는 중…</p>
    <ol id="ranking-list" class="ranking-list"></ol>
    <p id="ranking-empty" class="rk-status" hidden>아직 오늘 해몽된 꿈이 없어요.</p>
    <p id="ranking-error" class="rk-status rk-error" hidden>랭킹을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.</p>
  </main>

  <script src="categoryDictionary.js"></script>
  <script src="ranking.js"></script>
</body>
</html>
```

- [ ] **Step 3: `ranking.css` 생성**

수치 출처: 데스크탑 `D · 전체보기 · F2`(673:2)·`F3`(678:266), 모바일 `M · 전체보기 · F2`(675:47).

```css
/* Task 3 전까지 style.css에 옛 홈용 body·button 규칙이 남아 있어 폰트·버튼 여백을 여기서 명시한다. */
.ranking-body {
  min-height: 100vh;
  background: #fbf8f0;
  color: #211d14;
  font-family: var(--font-sans);
}

/* ── 네비게이션 ── */
.rk-nav {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: clamp(16px, calc(16px + 6 * var(--f)), 22px) clamp(20px, calc(20px + 26 * var(--f)), 46px);
  border-bottom: 1px solid #ebe4d3;
  color: #9e6630;
}
.rk-logo {
  order: -1;
  font-family: var(--font-serif);
  font-size: 20px;
  font-weight: 700;
}
.rk-back {
  margin-left: auto;
  color: inherit;
  font-size: 12.5px;
  font-weight: 700;
  text-decoration: none;
}
.rk-nav-title {
  display: none;
  font-family: var(--font-serif);
  font-size: 17px;
  font-weight: 700;
}

/* ── 본문 ── */
.rk-content {
  box-sizing: content-box;
  max-width: 1000px;
  margin: 0 auto;
  padding:
    clamp(22px, calc(22px + 18 * var(--f)), 40px)
    clamp(20px, calc(20px + 120 * var(--f)), 140px)
    clamp(48px, calc(48px + 32 * var(--f)), 80px);
}

.rk-header {
  display: flex;
  align-items: flex-end;
  gap: 48px;
  padding-bottom: 24px;
}
.rk-title {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 8px;
  min-width: 0;
}
.rk-title h1 {
  margin: 0;
  font-size: clamp(22px, calc(22px + 10 * var(--f)), 32px);
  font-weight: 700;
  letter-spacing: -0.03em;
}
.rk-date {
  margin: 0;
  font-size: clamp(12px, calc(12px + 1 * var(--f)), 13px);
  color: #7c7360;
}

/* ── 내가 해몽한 꿈 (F1/F4) ── */
.mine-card {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  gap: 13px;
  width: min(372px, 100%);
  padding: 13px 16px;
  border: 1.4px solid #e2d9c3;
  border-radius: 13px;
  background: #f5f0e2;
}
.mine-label {
  font-size: 11px;
  font-weight: 700;
  line-height: 14px;
  color: #7c7360;
}
.mine-name {
  font-size: 17px;
  font-weight: 700;
  letter-spacing: -0.03em;
}
.mine-rank {
  margin-left: auto;
  font-size: 12.5px;
  font-weight: 700;
}
.mine-goto {
  width: auto;
  margin: 0;
  padding: 6px 11px;
  border: 0;
  border-radius: 7px;
  background: #211d14;
  color: #fff;
  font-size: 11.5px;
  font-weight: 700;
  white-space: nowrap;
  cursor: pointer;
}

/* ── 해몽 전 (F3): 같은 요소를 두 줄 문구 + 버튼 격자로 재배치 ── */
.mine-card.is-empty {
  display: grid;
  grid-template-columns: 1fr auto;
  column-gap: 13px;
  row-gap: 3px;
  border-style: dashed;
  background: none;
}
.mine-card.is-empty .mine-label { display: none; }
.mine-card.is-empty .mine-name {
  grid-column: 1;
  font-size: 14px;
  letter-spacing: 0;
}
.mine-card.is-empty .mine-rank {
  grid-column: 1;
  margin-left: 0;
  font-size: 11.5px;
  font-weight: 400;
  color: #7c7360;
}
.mine-card.is-empty .mine-goto {
  grid-column: 2;
  grid-row: 1 / span 2;
  align-self: center;
  padding: 7px 12px;
}

/* ── 범례 ── */
.rk-legend {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 18px;
  margin: 0;
  padding: 0 0 10px 16px;
  list-style: none;
}
.rk-legend li {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  color: #7c7360;
}
.rk-legend .seal {
  --seal-size: 24px;
  transform: none;
}

/* ── 목록 ── */
.ranking-list {
  margin: 0;
  padding: 0;
  border-top: 1px solid #ebe4d3;
  list-style: none;
}
.ranking-list:empty { border-top: 0; }
.ranking-item { border-bottom: 1px solid #ebe4d3; }
.ranking-item.is-mine { background: #f5f0e2; }

.ranking-row {
  display: grid;
  grid-template-columns: 56px 118px 56px minmax(0, max-content) auto 1fr 20px;
  grid-template-areas: "rank name seal summary tag . chev";
  align-items: center;
  width: 100%;
  margin: 0;
  padding: 12px 16px;
  border: 0;
  background: none;
  color: inherit;
  text-align: left;
  cursor: pointer;
}
.ranking-row:focus-visible {
  outline: 2px solid #9e6630;
  outline-offset: -2px;
}
.ranking-row .rank {
  grid-area: rank;
  font-size: 15px;
  font-weight: 700;
  color: #aba290;
}
.ranking-item.is-mine .rank,
.ranking-item.open .rank { color: #211d14; }
.ranking-row .name {
  grid-area: name;
  overflow: hidden;
  font-size: 16.5px;
  font-weight: 700;
  letter-spacing: -0.025em;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ranking-row .seal-slot {
  grid-area: seal;
  display: flex;
}
.ranking-row .summary {
  grid-area: summary;
  overflow: hidden;
  font-size: 13.5px;
  color: #7c7360;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ranking-row .mine-tag {
  grid-area: tag;
  margin-left: 10px;
  padding: 2px 7px;
  border: 1px solid #e2d9c3;
  border-radius: 5px;
  background: #fff;
  font-size: 10.5px;
  font-weight: 700;
  color: #7c7360;
  white-space: nowrap;
}
.ranking-row .chevron {
  grid-area: chev;
  width: 20px;
  height: 20px;
  fill: none;
  stroke: #aba290;
  stroke-width: 1.7;
  stroke-linecap: round;
  stroke-linejoin: round;
  transition: transform 0.25s ease;
}
.ranking-item.open .chevron {
  transform: rotate(180deg);
  stroke: #211d14;
}

/* ── 펼침 패널: max-height 트랜지션. 열린 뒤에는 JS가 none으로 풀어 준다. ── */
.ranking-panel {
  max-height: 0;
  overflow: hidden;
  transition: max-height 0.3s ease;
}
.ranking-panel-inner {
  display: grid;
  grid-template-columns: 118px minmax(0, 620px);
  align-items: baseline;
  padding: 2px 64px 20px 72px;
}
.panel-label {
  margin: 0;
  font-size: 11px;
  font-weight: 500;
  color: #aba290;
}
.panel-summary {
  display: none;
  margin: 0;
}
.panel-text {
  margin: 0;
  font-size: 14px;
  line-height: 1.75;
}

/* ── 상태 문구 ── */
.rk-status {
  margin: 40px 0 0;
  font-size: 13px;
  color: #7c7360;
  text-align: center;
}
.rk-error { color: #a03f3a; }

@media (prefers-reduced-motion: reduce) {
  .ranking-panel,
  .ranking-row .chevron { transition: none; }
}

/* ── 모바일: 네비·헤더·행 구성이 바뀐다 (Figma M · 전체보기) ── */
@media (max-width: 640px) {
  .rk-logo { display: none; }
  .rk-back {
    margin-left: 0;
    font-size: 15px;
  }
  .rk-back-text { display: none; }
  .rk-nav-title { display: inline; }

  .rk-header {
    flex-direction: column;
    align-items: stretch;
    gap: 16px;
    padding-bottom: 12px;
  }
  .rk-title { gap: 6px; }

  .mine-card {
    width: auto;
    gap: 10px;
    padding: 11px 14px;
    border-radius: 12px;
  }
  .mine-card.is-empty { column-gap: 10px; }
  .mine-label {
    font-size: 10px;
    line-height: 13px;
  }
  .mine-name { font-size: 16px; }
  .mine-rank { font-size: 12px; }
  .mine-goto {
    padding: 5px 10px;
    font-size: 11px;
  }

  .rk-legend {
    gap: 12px;
    padding: 8px 0 8px 4px;
  }
  .rk-legend li {
    gap: 5px;
    font-size: 11px;
  }
  .rk-legend .seal { --seal-size: 20px; }

  .ranking-row {
    grid-template-columns: 24px minmax(0, max-content) auto 1fr 40px 18px;
    grid-template-areas: "rank name tag . seal chev";
    column-gap: 6px;
    padding: 9px 10px;
  }
  .ranking-row .rank { font-size: 13px; }
  .ranking-row .name { font-size: 15.5px; }
  .ranking-row .summary { display: none; }
  .ranking-row .seal { --seal-size: 34px; }
  .ranking-row .mine-tag {
    margin-left: 0;
    padding: 1px 6px;
    font-size: 10px;
  }
  .ranking-row .chevron {
    width: 18px;
    height: 18px;
  }

  .ranking-panel-inner {
    grid-template-columns: 1fr;
    row-gap: 6px;
    padding: 0 14px 16px 40px;
  }
  .panel-label { font-size: 10.5px; }
  .panel-summary {
    display: block;
    font-size: 13.5px;
    font-weight: 700;
  }
  .panel-text {
    font-size: 13px;
    line-height: 1.7;
  }
}
```

- [ ] **Step 4: `ranking.js` 전체 교체**

```javascript
const API_BASE_URL = "http://localhost:8000"; // 배포 시 Render URL로 교체

function formatKoreanDate(isoDate) {
  const [, month, day] = isoDate.split("-").map(Number);
  return `${month}월 ${day}일`;
}

function setOpen(li, open) {
  if (li.classList.contains("open") === open) return;
  const panel = li.querySelector(".ranking-panel");
  li.classList.toggle("open", open);
  li.querySelector(".ranking-row").setAttribute("aria-expanded", String(open));
  panel.setAttribute("aria-hidden", String(!open));
  // max-height는 none에서 숫자로 트랜지션되지 않는다. 실제 높이를 먼저 박아 두고 목표값으로 옮긴다.
  panel.style.maxHeight = `${panel.scrollHeight}px`;
  if (!open) {
    panel.getBoundingClientRect();
    panel.style.maxHeight = "0px";
  }
}

function buildRow(item, myCategory) {
  const entry = CATEGORY_DICTIONARY[item.category] || {
    summary: "아직 해몽 사전에 없는 카테고리예요.",
    text: "이 카테고리는 아직 전통 해몽 사전에 등록되지 않았어요.",
  };
  const isMine = item.category === myCategory;

  const li = document.createElement("li");
  li.className = "ranking-item" + (isMine ? " is-mine" : "");
  li.innerHTML = `
    <button class="ranking-row" type="button" aria-expanded="false">
      <span class="rank">${item.rank}</span>
      <span class="name"></span>
      <span class="seal-slot"></span>
      <span class="summary">${entry.summary}</span>
      ${isMine ? '<span class="mine-tag">내 꿈</span>' : ""}
      <svg class="chevron" viewBox="0 0 20 20" aria-hidden="true"><path d="M5 7.5L10 12.5L15 7.5" /></svg>
    </button>
    <div class="ranking-panel" aria-hidden="true">
      <div class="ranking-panel-inner">
        <p class="panel-label">전통 해몽</p>
        <p class="panel-summary">${entry.summary}</p>
        <p class="panel-text">${entry.text}</p>
      </div>
    </div>
  `;

  // 카테고리 이름만 서버에서 오는 값이다. innerHTML에 끼워 넣지 않고 textContent로 채운다.
  // 지금은 BE가 13종 화이트리스트로 정규화해 안전하지만, 카테고리 목록을 넓힐 때
  // 그 정규화를 놓치면 여기가 그대로 XSS 통로가 된다.
  li.querySelector(".name").textContent = item.category;
  li.querySelector(".seal-slot").appendChild(createSeal(luckOf(item.category)));

  const panel = li.querySelector(".ranking-panel");
  // 열림 트랜지션이 끝나면 제한을 풀어, 열린 채로 창 폭이 줄어도 본문이 잘리지 않게 한다.
  panel.addEventListener("transitionend", () => {
    if (li.classList.contains("open")) panel.style.maxHeight = "none";
  });
  li.querySelector(".ranking-row").addEventListener("click", () => {
    setOpen(li, !li.classList.contains("open"));
  });

  return li;
}

function showMine(mine, mineRow) {
  document.getElementById("mine-name").textContent = mine.category;
  document.getElementById("mine-rank").textContent = `오늘 ${mine.rank}위`;
  document.getElementById("mine-goto").addEventListener("click", () => {
    setOpen(mineRow, true);
    // 행을 만들 때 잡아둔 참조로 스크롤한다. 카테고리 이름으로 속성 선택자를 만들면
    // 이름에 따옴표가 섞이는 순간 선택자 자체가 깨진다.
    mineRow.scrollIntoView({ behavior: "smooth", block: "center" });
  });
  document.getElementById("mine-card").hidden = false;
}

// 기록이 없거나, 자정이 지나 어제 꿈만 남아 오늘 목록에 없을 때.
function showMineEmpty() {
  const card = document.getElementById("mine-card");
  card.classList.add("is-empty");
  document.getElementById("mine-name").textContent = "아직 해몽한 꿈이 없어요";
  document.getElementById("mine-rank").textContent = "꿈을 풀어보면 오늘 몇 위인지 알려드려요";
  const goto = document.getElementById("mine-goto");
  goto.textContent = "해몽하러 가기";
  // 홈은 로드 시 방문자 날씨로 테마를 정하므로 링크만 걸면 된다.
  goto.addEventListener("click", () => {
    location.href = "index.html";
  });
  card.hidden = false;
}

async function loadRanking() {
  const myCategory = sessionStorage.getItem("lastDreamCategory");
  const loadingEl = document.getElementById("ranking-loading");

  try {
    // 크론이 쉬는 02:00~07:00 KST에는 Render 콜드 스타트로 수십 초가 걸릴 수 있다.
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60000);
    const res = await fetch(`${API_BASE_URL}/demo/ranking`, { signal: controller.signal });
    clearTimeout(timeout);
    if (!res.ok) throw new Error("랭킹 실패");
    const data = await res.json();

    document.getElementById("ranking-date").textContent = `${formatKoreanDate(data.date)} · 오늘 해몽된 꿈만 모았어요`;

    if (data.items.length === 0) {
      document.getElementById("ranking-empty").hidden = false;
      showMineEmpty();
      return;
    }

    const list = document.getElementById("ranking-list");
    list.innerHTML = "";
    let mineRow = null;
    for (const item of data.items) {
      const row = buildRow(item, myCategory);
      if (item.category === myCategory) mineRow = row;
      list.appendChild(row);
    }

    const mine = data.items.find((item) => item.category === myCategory);
    if (mine) {
      showMine(mine, mineRow);
    } else {
      showMineEmpty();
    }
  } catch (e) {
    console.warn("랭킹 로딩 실패:", e);
    document.getElementById("ranking-error").hidden = false;
  } finally {
    loadingEl.hidden = true;
  }
}

loadRanking();
```

- [ ] **Step 5: 문법·계약 검증**

Run: V1, V2
Expected: `JS_OK`, `OK`

추가 확인(카테고리 textContent 유지):
```bash
grep -n 'textContent = item.category' WEB/ranking.js
```
Expected: 1줄 출력.

- [ ] **Step 6: 브라우저 확인 — BE 연동**

V3로 `WEB/`을 서빙하고 로컬 BE를 `WEB_ORIGIN=http://localhost:5500`으로 띄운다. 랭킹에 데이터가 없으면 홈(옛 화면)에서 해몽을 2회 실행해 두거나 curl로 `POST /demo/interpret`를 호출한다.

| 확인 | 방법 | 합격 |
|---|---|---|
| F1 데스크탑 | 폭 1280px로 `ranking.html` | Figma 678:92와 네비·제목·범례·행 배치·색 일치 |
| F3 해몽 전 | 콘솔 `sessionStorage.removeItem("lastDreamCategory")` 후 새로고침 | 점선 카드 "아직 해몽한 꿈이 없어요", 버튼 클릭 시 `index.html` 이동 |
| F1 내 꿈 | 콘솔 `sessionStorage.setItem("lastDreamCategory", "<목록에 있는 카테고리>")` 후 새로고침 | 실선 카드 "오늘 N위", 해당 행 배경 `#f5f0e2`, "내 꿈" 태그 |
| F4 순위 보기 | "순위 보기" 클릭 | 해당 행이 펼쳐지며 화면 중앙으로 스크롤 |
| F2 펼침 | 아무 행 2개 클릭 | 둘 다 독립적으로 열림, 높이가 부드럽게 늘어남, 셰브론 180° 회전·진한색 |
| 접힘 | 열린 행 다시 클릭 | 높이가 부드럽게 줄어듦 |
| 잘림 없음 | 행을 연 상태로 창 폭을 1280→400px로 줄임 | 패널 본문이 잘리지 않음 |
| 모바일 | 폭 360px | Figma 675:47처럼 네비 "← 전체보기", 요약은 행에서 사라지고 펼친 패널에 굵게 표시, 태그가 이름 옆 |
| 중간 폭 | 641px, 900px | 행 요소 겹침·가로 스크롤 없음 |
| 에러 | BE 종료 후 새로고침 | 에러 문구만 표시, 카드 숨김 |
| 凶 글리프 | 개발자도구 Elements에서 凶 글자 선택 → Computed → Rendered Fonts | Gowun Batang 또는 Noto Serif KR(둘 중 하나로 吉·凶이 같은 계열) |

- [ ] **Step 7: Commit**

```bash
git add WEB/ranking.html WEB/ranking.css WEB/ranking.js WEB/style.css
git commit -m "$(cat <<'EOF'
feat: 랭킹 전체보기에 Figma 한지 디자인 적용 (도장·범례·해몽 전 카드·자동 펼침)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: 홈 F1 — 날씨 테마·일러스트·한 줄 입력·랭킹 미리보기

**Files:**
- Modify: `WEB/index.html` (전체 교체)
- Create: `WEB/home.css` (F1 + 결과 영역 기본 스타일까지. 단계 연출은 Task 4에서 이어 붙임)
- Modify: `WEB/app.js` — 테마 적용·날씨·미리보기 추가, 옛 버튼 문구 조작 제거
- Modify: `WEB/style.css` (전체 교체 — 공용 규칙만 남김)

**Interfaces:**
- Consumes: `createSeal`, `luckOf`(Task 1 — Task 4에서 사용), `GET /demo/ranking`
- Produces (Task 4가 사용):
  - `body` 클래스: `home`, `theme-{clear|cloudy|fog|rain|snow}`, `stage-input`
  - 전역 함수 `applyTheme(theme: string) -> void`
  - 전역 변수 `weatherLabel: string | null` (날씨 조회 성공 시 "맑음" 등)
  - 전역 함수 `kstDateParts() -> { month: string, day: string, weekday: string }`
  - `index.html` 신규 id: `hero-sub`, `hero-title`, `home-ranking`, `home-ranking-list`, `result-date-long`, `result-date-short`, `result-quote`, `result-seal-slot`, `retry-btn`, `result-app-link`
  - CSS 변수(테마 토큰) — 아래 Step 3 표의 이름 그대로

- [ ] **Step 1: `style.css` 전체 교체 (공용만 남김)**

옛 홈 규칙(`body`, `.page`, `.weather-widget`, `textarea`, `button`, `.error-message`, `.result`, `.ranking-link`, `.modal`, `.modal-content`, `body.theme-*`)과 `--bg/--fg/--accent`를 지운다. `.seal` 블록은 Task 1 그대로다.

```css
:root {
  --font-serif: "Gowun Batang", "Noto Serif KR", serif;
  --font-sans: "Noto Sans KR", -apple-system, BlinkMacSystemFont, sans-serif;
  /* 360px 화면에서 0px, 1280px 화면에서 1px.
     clamp(모바일값, calc(모바일값 + 차이 * var(--f)), 데스크탑값)으로 두 시안 사이를 선형 보간한다. */
  --f: calc((100vw - 360px) / 920);
}

* { box-sizing: border-box; }

/* hidden 속성은 브라우저 기본 스타일의 display:none이라, 아래 클래스들의
   display:flex에 캐스케이드에서 진다. !important로 되돌려야 hidden이 실제로 먹는다. */
[hidden] {
  display: none !important;
}

body {
  margin: 0;
  font-family: var(--font-sans);
}

button,
input {
  font: inherit;
}

/* 길흉 도장 — Figma "Seal · 길흉 도장"(672:15). 기준 40px 안에 36px 바깥 원·30px 안쪽 원.
   Figma의 -9°는 반시계 기준이라 CSS에서는 +9deg다. */
.seal {
  --seal-size: 40px;
  --seal-color: #be241f;
  position: relative;
  display: inline-flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  width: var(--seal-size);
  height: var(--seal-size);
  transform: rotate(9deg);
  font-family: var(--font-serif);
  font-weight: 700;
  font-size: calc(var(--seal-size) * 0.425);
  line-height: 1.18;
  color: var(--seal-color);
}
.seal::before,
.seal::after {
  content: "";
  position: absolute;
  border-style: solid;
  border-color: var(--seal-color);
  border-radius: 50%;
}
.seal::before {
  inset: 5%;
  border-width: calc(var(--seal-size) * 0.04);
  opacity: 0.85;
}
.seal::after {
  inset: 12.5%;
  border-width: calc(var(--seal-size) * 0.02);
  opacity: 0.45;
}
.seal > span { opacity: 0.9; }
.seal-g { --seal-color: #be241f; }
.seal-h { --seal-color: #1e2836; }
.seal-b {
  --seal-color: #49525f;
  font-size: calc(var(--seal-size) * 0.25);
  line-height: 1.05;
}
```

- [ ] **Step 2: `index.html` 전체 교체**

```html
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Re-view — 오늘의 꿈 해몽</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Gowun+Batang:wght@400;700&family=Noto+Sans+KR:wght@400;500;700&display=swap" />
  <!-- Gowun Batang에 凶 글리프가 없을 때를 대비한 폴백. 두 글자만 서브셋으로 받는다. -->
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Serif+KR:wght@700&text=%E5%90%89%E5%87%B6&display=swap" />
  <link rel="stylesheet" href="style.css" />
  <link rel="stylesheet" href="home.css" />
</head>
<body class="home theme-clear stage-input">
  <main class="scene">
    <div class="sky">
      <div class="decor decor-soft" aria-hidden="true"><span></span><span></span><span></span></div>
      <div class="decor decor-rain" aria-hidden="true"><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span></div>
      <div class="decor decor-snow" aria-hidden="true"><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span></div>
      <div class="sun" aria-hidden="true"></div>
      <div class="cloud" aria-hidden="true"><span class="c1"></span><span class="c2"></span><span class="c3"></span><span class="base"></span></div>

      <header class="topbar">
        <span class="logo">굿모닝 드림</span>
        <section id="weather-widget" class="weather-widget" hidden>
          <span class="weather-dot" aria-hidden="true"></span>
          <!-- Figma에 도시명이 없어 표시하지 않는다. id 계약 때문에 요소만 남긴다. -->
          <span id="weather-city" hidden></span>
          <span id="weather-desc"></span>
        </section>
      </header>

      <div class="hero-copy">
        <p id="hero-sub" class="hero-sub">맑은 아침이에요</p>
        <h1 id="hero-title" class="hero-title">햇살 좋은 아침,<br />어떤 꿈을 꿨나요?</h1>
      </div>
    </div>

    <div class="ground">
      <form id="interpret-form" class="dream-form">
        <div class="dream-pill">
          <input id="dream-input" type="text" maxlength="500" autocomplete="off" aria-label="간밤에 꾼 꿈" placeholder="간밤에 꾼 꿈을 한 줄로 적어보세요" />
          <button type="submit" id="submit-btn" aria-label="해몽 받기">
            <span class="btn-label">해몽 받기</span><span class="btn-arrow" aria-hidden="true">→</span>
          </button>
        </div>
        <p id="input-error" class="error-message" hidden></p>
      </form>

      <section id="home-ranking" class="preview" hidden>
        <div class="preview-head">
          <span class="preview-label"><span class="preview-label-long">오늘 아침 </span>많이 찾는 꿈</span>
          <a href="ranking.html" class="ranking-link">전체보기 →</a>
        </div>
        <ol id="home-ranking-list" class="preview-list"></ol>
      </section>

      <article id="result" class="result" hidden>
        <div class="result-meta">
          <span><span id="result-date-long" class="result-date-long"></span><span id="result-date-short" class="result-date-short"></span></span>
          <span>굿모닝 드림</span>
        </div>
        <div class="result-box"><h2 id="result-theme"></h2></div>
        <p id="result-quote" class="result-quote"></p>
        <p id="result-vibe" class="reveal"></p>
        <ul id="result-feelings" class="reveal"></ul>
        <div class="result-body reveal">
          <p id="result-reply"></p>
          <span id="result-seal-slot" class="result-seal"></span>
        </div>
        <div class="result-actions reveal">
          <button type="button" id="retry-btn" class="btn-ghost">다시 풀<span class="long">어보</span>기</button>
          <a href="#" id="result-app-link" class="btn-fill">앱에서 이어 쓰기</a>
        </div>
      </article>
    </div>
  </main>

  <div id="exhausted-modal" class="modal" hidden>
    <div class="modal-content">
      <p id="exhausted-message">앱에서 더 해보세요! 앱 설치 시 추가 기회를 무료로 드려요.</p>
      <div class="modal-actions">
        <button type="button" id="modal-close" class="btn-ghost">닫기</button>
        <a href="#" id="app-store-link" class="btn-fill">앱 설치하러 가기</a>
      </div>
    </div>
  </div>

  <script src="categoryDictionary.js"></script>
  <script src="app.js"></script>
</body>
</html>
```

- [ ] **Step 3: `home.css` 생성 — 토큰·하늘·땅·입력·미리보기·결과 기본·팝업**

토큰 값 출처: `D·맑음 F1/F5`(588:46, 588:117), `D·흐림 F1/F5`(589:46, 589:141), `D·비 F1/F5`(590:46, 590:169), `D·눈 F1/F5`(591:46, 591:201), 모바일 `M·맑음 F1/F5`(595:46, 595:117). 일러스트 SVG 에셋은 단색·그라디언트 원/둥근 사각형이라 같은 값으로 CSS 재현한다(태양 글로우 = SVG drop-shadow stdDeviation 45 → `box-shadow` blur 90px).

```css
/* ════════════ 테마 토큰 ════════════ */
body.home {
  --sky-bg: #fdf6e9;
  --ground-bg: #fbf0dd;
  --paper-bg: #fdf6e9;
  --horizon: #f0d1b7;
  --logo: #9e6630;
  --meta: #947b65;
  --dot: #fcc364;
  --hero-sub: #9d6f47;
  --hero-title: #604734;
  --pill-bg: rgba(255, 253, 249, 0.85);
  --pill-border: #f2e2d0;
  --placeholder: rgba(80, 62, 47, 0.55);
  --btn-bg: #f9d28a;
  --btn-fg: #593b1f;
  --link: #9e6630;
  --card-bg: #fff7ea;
  --card-border: #ebd7c3;
  --card-name: #7d5b40;
  --r-meta: #8d7563;
  --r-box: rgba(171, 90, 72, 0.45);
  --r-title: #412614;
  --r-quote: #8d7563;
  --r-text: #705848;
  --ghost-bg: #fef4e5;
  --ghost-border: #ead3bc;
  --ghost-fg: #7c5335;
  --seal-good: #be241f;
  --cloud-side: #eceff2;
  --cloud-center: #f6f9fb;
}

/* 안개는 Figma 시안이 없어 흐림을 그대로 쓴다(스펙 2장). */
body.home.theme-cloudy,
body.home.theme-fog {
  --sky-bg: linear-gradient(#e8ebef, #dde2e7 60%, #d5dbe2);
  --ground-bg: linear-gradient(#d8dfe6, #cdd5de);
  --paper-bg: #f2f5f9;
  --horizon: #c3cbd4;
  --logo: #586b80;
  --meta: #687686;
  --dot: #b0b8c1;
  --hero-sub: #586b80;
  --hero-title: #262f38;
  --pill-bg: rgba(242, 245, 249, 0.85);
  --pill-border: #c3cbd4;
  --placeholder: rgba(38, 47, 56, 0.55);
  --btn-bg: #96aec7;
  --btn-fg: #fff;
  --link: #586b80;
  --card-bg: #d8dfe6;
  --card-border: #c3cbd4;
  --card-name: #565f68;
  --r-meta: #747b83;
  --r-box: rgba(88, 107, 128, 0.45);
  --r-title: #262f38;
  --r-quote: #747b83;
  --r-text: #565f68;
  --ghost-bg: #eff2f6;
  --ghost-border: #ced5dc;
  --ghost-fg: #4c5a69;
  --seal-good: #a03f3a;
  --cloud-side: #eceff2;
  --cloud-center: #f6f9fb;
}

body.home.theme-rain {
  --sky-bg: linear-gradient(#d8e7f2, #cadeeb 60%, #c2d8e6);
  --ground-bg: linear-gradient(#c3d8e6, #adc9d9);
  --paper-bg: #eff5f9;
  --horizon: #a6c2d4;
  --logo: #456d8f;
  --meta: #597288;
  --dot: #7da4c0;
  --hero-sub: #456d8f;
  --hero-title: #22303b;
  --pill-bg: rgba(239, 245, 249, 0.85);
  --pill-border: #a6c2d4;
  --placeholder: rgba(34, 48, 59, 0.55);
  --btn-bg: #6dabdf;
  --btn-fg: #fff;
  --link: #456d8f;
  --card-bg: #c3d8e6;
  --card-border: #a6c2d4;
  --card-name: #4f5d68;
  --r-meta: #6e7983;
  --r-box: rgba(69, 103, 131, 0.45);
  --r-title: #22303b;
  --r-quote: #6e7983;
  --r-text: #4f5d68;
  --ghost-bg: #edf3f7;
  --ghost-border: #cad6df;
  --ghost-fg: #455b6d;
  --seal-good: #a43b36;
  --cloud-side: #a1b8c8;
  --cloud-center: #b8cad8;
}

body.home.theme-snow {
  --sky-bg: linear-gradient(#dae2ee, #d0d8e8 60%, #cbd0e4);
  --ground-bg: linear-gradient(#f1f3f9, #e6e9f2);
  --paper-bg: #f7f8fc;
  --horizon: #fafcff;
  --logo: #656b97;
  --meta: #6e728f;
  --dot: #fbfcff;
  --hero-sub: #656b97;
  --hero-title: #2c2f3d;
  --pill-bg: rgba(247, 248, 252, 0.85);
  --pill-border: #fafcff;
  --placeholder: rgba(44, 47, 61, 0.55);
  --btn-bg: #c7cef9;
  --btn-fg: #3a385b;
  --link: #656b97;
  --card-bg: #f1f3f9;
  --card-border: #fafcff;
  --card-name: #5a5d6a;
  --r-meta: #777a85;
  --r-box: rgba(96, 103, 134, 0.45);
  --r-title: #2c2f3d;
  --r-quote: #777a85;
  --r-text: #5a5d6a;
  --ghost-bg: #f3f5f9;
  --ghost-border: #d7dae4;
  --ghost-fg: #545972;
  --seal-good: #a83634;
  --cloud-side: #e3e8f2;
  --cloud-center: #f2f5fb;
}

/* ════════════ 크기 토큰 (F1 기준. 단계별 값은 Task 4) ════════════ */
body.home {
  --gutter: clamp(20px, calc(20px + 26 * var(--f)), 46px);
  --sky-h: clamp(459px, calc(459px + 37 * var(--f)), 496px);
  --sun: clamp(150px, calc(150px + 67 * var(--f)), 217px);
  --sun-sink: -0.32;
  --cloud-bottom: clamp(23px, calc(23px + 11 * var(--f)), 34px);
  --pill-h: clamp(56px, calc(56px + 12 * var(--f)), 68px);
  --pill-btn-h: clamp(42px, calc(42px + 8 * var(--f)), 50px);

  background: var(--paper-bg);
  color: var(--hero-title);
}

/* ════════════ 하늘 ════════════ */
.sky {
  position: relative;
  height: var(--sky-h);
  overflow: hidden;
  border-bottom: 2px solid var(--horizon);
  background: var(--sky-bg);
}

.decor {
  position: absolute;
  inset: 0;
  display: none;
}
.decor span { position: absolute; }
.theme-cloudy .decor-soft,
.theme-fog .decor-soft,
.theme-rain .decor-rain,
.theme-snow .decor-snow { display: block; }

/* 흐림: 흐릿한 배경 구름 (340×170, 300×150, 280×140 @1280×496) */
.decor-soft span {
  aspect-ratio: 2 / 1;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.5);
  filter: blur(15px);
}
.decor-soft span:nth-child(1) { left: -10%; top: 4%; width: 26.6%; }
.decor-soft span:nth-child(2) { left: 64%; top: 2%; width: 23.4%; }
.decor-soft span:nth-child(3) { left: -4%; top: 20%; width: 21.9%; }

/* 비·눈 장식은 상단바 아래에서 시작해 날씨 표기 글자를 가로지르지 않게 한다(스펙 6.2). */
.decor-rain,
.decor-snow { top: 64px; }

.decor-rain span {
  width: 3px;
  height: 14px;
  border-radius: 2px;
  background: rgba(86, 146, 197, 0.7);
}
/* Figma 1번 빗줄기는 좌표가 순환해 (0,0)에 떨어져 있었다. 패턴상 오른쪽 끝으로 옮긴다. */
.decor-rain span:nth-child(1) { left: calc(100% - 3px); top: 5%; }
.decor-rain span:nth-child(2) { left: 97%; top: 23%; }
.decor-rain span:nth-child(3) { left: 94%; top: 41%; }
.decor-rain span:nth-child(4) { left: 91%; top: 59%; }
.decor-rain span:nth-child(5) { left: 88%; top: 5%; }
.decor-rain span:nth-child(6) { left: 85%; top: 23%; }
.decor-rain span:nth-child(7) { left: 82%; top: 41%; }
.decor-rain span:nth-child(8) { left: 79%; top: 59%; }
.decor-rain span:nth-child(9) { left: 76%; top: 5%; }
.decor-rain span:nth-child(10) { left: 73%; top: 23%; }

.decor-snow span {
  width: 3px;
  height: 3px;
  border-radius: 50%;
  background: #fff;
}
.decor-snow span:nth-child(3n + 2) { width: 4px; height: 4px; }
.decor-snow span:nth-child(3n) { width: 5.5px; height: 5.5px; }
.decor-snow span:nth-child(1) { left: 0%; top: 0%; }
.decor-snow span:nth-child(2) { left: 53%; top: 29%; }
.decor-snow span:nth-child(3) { left: 6%; top: 58%; }
.decor-snow span:nth-child(4) { left: 59%; top: 87%; }
.decor-snow span:nth-child(5) { left: 12%; top: 16%; }
.decor-snow span:nth-child(6) { left: 65%; top: 45%; }
.decor-snow span:nth-child(7) { left: 18%; top: 74%; }
.decor-snow span:nth-child(8) { left: 71%; top: 3%; }
.decor-snow span:nth-child(9) { left: 24%; top: 32%; }
.decor-snow span:nth-child(10) { left: 77%; top: 61%; }
.decor-snow span:nth-child(11) { left: 30%; top: 90%; }
.decor-snow span:nth-child(12) { left: 83%; top: 19%; }
.decor-snow span:nth-child(13) { left: 36%; top: 48%; }
.decor-snow span:nth-child(14) { left: 89%; top: 77%; }
.decor-snow span:nth-child(15) { left: 42%; top: 6%; }
.decor-snow span:nth-child(16) { left: 95%; top: 35%; }
.decor-snow span:nth-child(17) { left: 48%; top: 64%; }
.decor-snow span:nth-child(18) { left: 1%; top: 93%; }

/* 맑음: 태양 (그라디언트 #FFE490→#FFC57A, 글로우 rgba(255,228,144,.5)) */
.sun {
  position: absolute;
  bottom: calc(var(--sun) * var(--sun-sink));
  left: 50%;
  display: none;
  width: var(--sun);
  height: var(--sun);
  border-radius: 50%;
  background: linear-gradient(#ffe490, #ffc57a);
  box-shadow: 0 0 90px rgba(255, 228, 144, 0.5);
  transform: translateX(-50%);
}
.theme-clear .sun { display: block; }

/* 흐림·비·눈: 원 3개 + 둥근 받침 (묶음 410×242 @1280) */
.cloud {
  position: absolute;
  bottom: var(--cloud-bottom);
  left: 50%;
  display: none;
  width: clamp(283px, calc(283px + 127 * var(--f)), 410px);
  aspect-ratio: 410 / 242;
  transform: translateX(-50%);
}
.theme-cloudy .cloud,
.theme-fog .cloud,
.theme-rain .cloud,
.theme-snow .cloud { display: block; }
.cloud span {
  position: absolute;
  border-radius: 50%;
}
.cloud .c1 { left: 0; top: 23.97%; width: 39.02%; aspect-ratio: 1; background: var(--cloud-side); }
.cloud .c2 { left: 27.56%; top: 0; width: 48.05%; aspect-ratio: 1; background: var(--cloud-center); }
.cloud .c3 { left: 64.15%; top: 27.27%; width: 35.85%; aspect-ratio: 1; background: var(--cloud-side); }
.cloud .base {
  left: 4.39%;
  top: 57.85%;
  width: 93.41%;
  height: 42.15%;
  border-radius: 999px;
  background: var(--cloud-center);
}

/* ── 상단바: 로고와 날씨를 같은 거터로 정렬 ── */
.topbar {
  position: absolute;
  top: 0;
  right: 0;
  left: 0;
  z-index: 2;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 26px var(--gutter) 0;
}
.logo {
  font-family: var(--font-serif);
  font-size: clamp(15px, calc(15px + 6 * var(--f)), 21px);
  font-weight: 700;
  color: var(--logo);
}
.weather-widget {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: clamp(10px, calc(10px + 2.5 * var(--f)), 12.5px);
  color: var(--meta);
}
.weather-dot {
  width: clamp(7px, calc(7px + 1 * var(--f)), 8px);
  height: clamp(7px, calc(7px + 1 * var(--f)), 8px);
  border-radius: 50%;
  background: var(--dot);
}

/* ── 부제·헤드라인 ── */
.hero-copy {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: clamp(104px, calc(104px + 14 * var(--f)), 118px) 24px 0;
  text-align: center;
}
.hero-sub {
  margin: 0;
  font-family: var(--font-serif);
  font-size: clamp(14px, calc(14px + 3 * var(--f)), 17px);
  color: var(--hero-sub);
}
.hero-title {
  max-width: 720px;
  margin: 0;
  font-family: var(--font-serif);
  font-size: clamp(24px, calc(24px + 14 * var(--f)), 38px);
  font-weight: 700;
  line-height: clamp(34px, calc(34px + 18 * var(--f)), 52px);
  color: var(--hero-title);
}

/* ════════════ 땅 ════════════ */
.ground {
  display: flex;
  flex-direction: column;
  min-height: calc(100vh - var(--sky-h));
  min-height: calc(100svh - var(--sky-h));
  background: var(--ground-bg);
}

/* ── 한 줄 입력: 경계선 정중앙에 걸친다 ── */
.dream-form {
  position: relative;
  z-index: 2;
  width: min(680px, 100% - 72px);
  margin: calc(var(--pill-h) / -2 - 1px) auto 0;
}
.dream-pill {
  display: flex;
  align-items: center;
  gap: 8px;
  height: var(--pill-h);
  /* 버튼을 사방 같은 간격으로 중앙 정렬한다(스펙 6.2). */
  padding: 0 calc((var(--pill-h) - var(--pill-btn-h)) / 2) 0 clamp(16px, calc(16px + 8 * var(--f)), 24px);
  border: 1px solid var(--pill-border);
  border-radius: 999px;
  background: var(--pill-bg);
}
.dream-pill:focus-within { box-shadow: 0 0 0 3px var(--pill-border); }
#dream-input {
  flex: 1;
  min-width: 0;
  border: 0;
  outline: none;
  background: transparent;
  font-size: clamp(12.5px, calc(12.5px + 2.5 * var(--f)), 15px);
  color: var(--hero-title);
}
#dream-input::placeholder { color: var(--placeholder); }
#submit-btn {
  flex-shrink: 0;
  min-width: 140px;
  height: var(--pill-btn-h);
  padding: 0 20px;
  border: 0;
  border-radius: 999px;
  background: var(--btn-bg);
  color: var(--btn-fg);
  font-size: 14.5px;
  font-weight: 700;
  cursor: pointer;
}
#submit-btn:disabled {
  opacity: 0.6;
  cursor: default;
}
.btn-arrow { display: none; }

.error-message {
  margin: 12px 0 0;
  font-size: 13px;
  color: #a03f3a;
  text-align: center;
}

/* ── 오늘 아침 많이 찾는 꿈: 화면 하단에 붙는다 ── */
.preview {
  margin-top: auto;
  padding: 40px var(--gutter) clamp(26px, calc(26px + 4 * var(--f)), 30px);
}
.preview-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  margin-bottom: clamp(8px, calc(8px + 4 * var(--f)), 12px);
  font-size: clamp(10px, calc(10px + 2.5 * var(--f)), 12.5px);
}
.preview-label { color: var(--meta); }
.ranking-link {
  color: var(--link);
  font-weight: 700;
  text-decoration: none;
}
.preview-list {
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  gap: clamp(8px, calc(8px + 4 * var(--f)), 12px);
  margin: 0;
  padding: 0;
  list-style: none;
}
.preview-card {
  display: flex;
  flex-direction: column;
  gap: 4px;
  height: clamp(56px, calc(56px + 8 * var(--f)), 64px);
  padding: clamp(9px, calc(9px + 3 * var(--f)), 12px) clamp(10px, calc(10px + 4 * var(--f)), 14px);
  border: 1px solid var(--card-border);
  border-radius: clamp(12px, calc(12px + 2 * var(--f)), 14px);
  background: var(--card-bg);
  text-decoration: none;
}
.preview-rank {
  font-size: clamp(9px, calc(9px + 1.5 * var(--f)), 10.5px);
  color: var(--meta);
}
.preview-name {
  overflow: hidden;
  font-size: clamp(10.5px, calc(10.5px + 1.5 * var(--f)), 12px);
  font-weight: 500;
  color: var(--card-name);
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* ════════════ 결과 (정적 배치. 단계 연출은 Task 4) ════════════ */
.result {
  width: min(970px, 100% - 48px);
  margin: 0 auto;
  padding: clamp(26px, calc(26px + 26 * var(--f)), 52px) 0 clamp(28px, calc(28px + 20 * var(--f)), 48px);
  color: var(--r-text);
}
.result-meta {
  display: flex;
  justify-content: space-between;
  font-size: clamp(9px, calc(9px + 2 * var(--f)), 11px);
  color: var(--r-meta);
}
.result-date-short { display: none; }
.result-box {
  margin-top: clamp(16px, calc(16px + 12 * var(--f)), 28px);
  padding: clamp(13px, calc(13px + 7 * var(--f)), 20px) clamp(14px, calc(14px + 14 * var(--f)), 28px);
  border: 1.5px solid var(--r-box);
  border-radius: 2px;
}
#result-theme {
  margin: 0;
  font-family: var(--font-serif);
  font-size: clamp(18px, calc(18px + 14 * var(--f)), 32px);
  font-weight: 700;
  line-height: clamp(25px, calc(25px + 20 * var(--f)), 45px);
  color: var(--r-title);
}
.result-quote {
  margin: 16px 0 0;
  font-family: var(--font-serif);
  font-size: clamp(11.5px, calc(11.5px + 4.5 * var(--f)), 16px);
  line-height: clamp(19px, calc(19px + 11 * var(--f)), 30px);
  color: var(--r-quote);
}
#result-vibe {
  margin: 20px 0 0;
  font-family: var(--font-serif);
  font-size: clamp(13.5px, calc(13.5px + 7.5 * var(--f)), 21px);
  line-height: clamp(21px, calc(21px + 14 * var(--f)), 35px);
}
#result-feelings {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin: 12px 0 0;
  padding: 0;
  list-style: none;
}
#result-feelings li {
  padding: 3px 10px;
  border: 1px solid var(--ghost-border);
  border-radius: 999px;
  background: var(--ghost-bg);
  font-size: clamp(11px, calc(11px + 1.5 * var(--f)), 12.5px);
  color: var(--ghost-fg);
}
/* 좁아지면 설명(기준 620px)이 한 줄을 다 쓰고 도장이 다음 줄 오른쪽으로 내려간다(Figma M F5). */
.result-body {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  gap: 16px;
  margin-top: 20px;
}
#result-reply {
  flex: 1 1 620px;
  max-width: 620px;
  margin: 0;
  font-size: clamp(11.5px, calc(11.5px + 4.5 * var(--f)), 16px);
  line-height: clamp(20px, calc(20px + 13 * var(--f)), 33px);
}
.result-seal { margin-left: auto; }
.result-seal .seal { --seal-size: clamp(46px, calc(46px + 46 * var(--f)), 92px); }
.result-seal .seal-g { --seal-color: var(--seal-good); }
/* F5 낙관은 목록용 도장보다 원이 굵고 옅다(Figma 588:133~135). */
.result-seal .seal::before {
  inset: 0;
  border-width: calc(var(--seal-size) * 0.027);
  opacity: 0.72;
}
.result-seal .seal::after {
  inset: 7.6%;
  border-width: 1px;
  opacity: 0.36;
}
.result-seal .seal > span { opacity: 0.72; }

.result-actions {
  display: flex;
  gap: clamp(8px, calc(8px + 4 * var(--f)), 12px);
  margin-top: clamp(24px, calc(24px + 9 * var(--f)), 33px);
}
.btn-ghost,
.btn-fill {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  height: clamp(36px, calc(36px + 8 * var(--f)), 44px);
  padding: 0 16px;
  border-radius: 999px;
  font-size: clamp(11px, calc(11px + 2.5 * var(--f)), 13.5px);
  font-weight: 700;
  text-decoration: none;
  cursor: pointer;
}
.btn-ghost {
  min-width: clamp(110px, calc(110px + 40 * var(--f)), 150px);
  border: 1px solid var(--ghost-border);
  background: var(--ghost-bg);
  color: var(--ghost-fg);
}
.btn-fill {
  min-width: clamp(150px, calc(150px + 20 * var(--f)), 170px);
  border: 0;
  background: var(--btn-bg);
  color: var(--btn-fg);
}

/* ════════════ 소진 팝업 ════════════ */
.modal {
  position: fixed;
  inset: 0;
  z-index: 10;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
  background: rgba(33, 29, 20, 0.45);
}
.modal-content {
  width: min(340px, 100%);
  padding: 28px 24px 22px;
  border-radius: 16px;
  background: var(--paper-bg);
  text-align: center;
}
#exhausted-message {
  margin: 0 0 20px;
  font-family: var(--font-serif);
  font-size: 16px;
  line-height: 1.6;
  color: var(--r-title);
}
.modal-actions {
  display: flex;
  justify-content: center;
  gap: 8px;
}

/* ════════════ 모바일 구조 분기 ════════════ */
@media (max-width: 640px) {
  #submit-btn {
    width: var(--pill-btn-h);
    min-width: 0;
    padding: 0;
    border-radius: 50%;
    font-size: 16px;
    font-weight: 400;
  }
  .btn-label { display: none; }
  .btn-arrow { display: inline; }

  .preview-label-long { display: none; }
  .preview-list { grid-template-columns: repeat(3, 1fr); }
  .preview-list li:nth-child(n + 4) { display: none; }

  .result-date-long { display: none; }
  .result-date-short { display: inline; }
  .long { display: none; }
}
```

- [ ] **Step 4: `app.js` — 테마·날씨·미리보기**

`WEB/app.js`를 아래처럼 바꾼다. `submitDream` 본문은 Task 4에서 교체하므로 이 태스크에서는 **버튼 문구를 바꾸는 두 줄만** 지운다(새 버튼은 안에 `<span>`이 있어 `textContent` 대입이 버튼을 망가뜨린다).

(a) 3~16행(`WMO_THEME_MAP`, `themeForWmoCode`) 바로 아래에 추가:

```javascript
// 안개는 Figma에 전용 시안이 없어 흐림 문구를 그대로 쓰고 날씨 표기만 "안개"로 둔다.
const THEME_COPY = {
  clear: { label: "맑음", sub: "맑은 아침이에요", title: ["햇살 좋은 아침,", "어떤 꿈을 꿨나요?"], placeholder: "간밤에 꾼 꿈을 한 줄로 적어보세요" },
  cloudy: { label: "흐림", sub: "흐린 아침이에요", title: ["구름 낀 아침,", "어떤 꿈을 꿨나요?"], placeholder: "간밤에 꾼 꿈을 한 줄로 적어보세요" },
  fog: { label: "안개", sub: "흐린 아침이에요", title: ["구름 낀 아침,", "어떤 꿈을 꿨나요?"], placeholder: "간밤에 꾼 꿈을 한 줄로 적어보세요" },
  rain: { label: "비", sub: "비 오는 아침이에요", title: ["빗소리 듣는 아침,", "간밤의 꿈은요?"], placeholder: "비를 맞으며 걷는 꿈을 꿨어요" },
  snow: { label: "눈", sub: "눈 내리는 아침이에요", title: ["포근한 눈 오는 날,", "어떤 꿈을 꿨어요?"], placeholder: "눈 쌓인 길을 걷는 꿈을 꿨어요" },
};

// 날씨 조회에 성공했을 때만 채운다. 실패 시 결과 화면 날짜 줄에 날씨를 붙이지 않는다.
let weatherLabel = null;

function applyTheme(theme) {
  document.body.classList.remove(...Object.keys(THEME_COPY).map((t) => `theme-${t}`));
  document.body.classList.add(`theme-${theme}`);
  const copy = THEME_COPY[theme];
  document.getElementById("hero-sub").textContent = copy.sub;
  document.getElementById("hero-title").replaceChildren(copy.title[0], document.createElement("br"), copy.title[1]);
  document.getElementById("dream-input").placeholder = copy.placeholder;
}

function kstDateParts() {
  const parts = new Intl.DateTimeFormat("ko-KR", {
    timeZone: "Asia/Seoul",
    month: "numeric",
    day: "numeric",
    weekday: "long",
  }).formatToParts(new Date());
  const pick = (type) => parts.find((p) => p.type === type).value;
  return { month: pick("month"), day: pick("day"), weekday: pick("weekday") };
}
```

(b) `fetchLocation`을 아래로 교체한다(도시명을 더 이상 표시하지 않아 반환값에서 뺀다):

```javascript
async function fetchLocation() {
  try {
    const res = await fetch("https://ipapi.co/json/");
    if (!res.ok) throw new Error("ipapi 응답 실패");
    const geo = await res.json();
    // 레이트리밋에 걸리면 200이면서 {"error": true}를 준다. ok만으로는 판정할 수 없어 좌표 유무로 본다.
    if (typeof geo.latitude !== "number" || typeof geo.longitude !== "number") {
      throw new Error("ipapi 좌표 없음");
    }
    return { latitude: geo.latitude, longitude: geo.longitude };
  } catch (e) {
    console.warn("위치 조회 실패, 서울 좌표로 폴백:", e);
    return { ...SEOUL_COORDS };
  }
}
```

(c) `loadWeather`를 아래로 교체한다:

```javascript
async function loadWeather() {
  const { latitude, longitude } = await fetchLocation();

  try {
    const weatherRes = await fetch(
      `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}&current_weather=true`
    );
    if (!weatherRes.ok) throw new Error("open-meteo 실패");
    const weather = await weatherRes.json();
    const theme = themeForWmoCode(weather.current_weather.weathercode);

    applyTheme(theme);
    weatherLabel = THEME_COPY[theme].label;
    const { month, day } = kstDateParts();
    document.getElementById("weather-desc").textContent = `${weatherLabel} · ${month}/${day}`;
    document.getElementById("weather-widget").hidden = false;
  } catch (e) {
    // 날씨가 죽어도 페이지는 뜬다 — 기본 테마를 유지하고 위젯만 숨긴다.
    console.warn("날씨 로딩 실패:", e);
  }
}
```

(d) `loadWeather` 아래에 추가:

```javascript
async function loadRankingPreview() {
  try {
    const res = await fetch(`${API_BASE_URL}/demo/ranking`);
    if (!res.ok) throw new Error("랭킹 실패");
    const data = await res.json();
    if (data.items.length === 0) return;

    const list = document.getElementById("home-ranking-list");
    for (const item of data.items.slice(0, 6)) {
      const card = document.createElement("a");
      card.href = "ranking.html";
      card.className = "preview-card";
      const rank = document.createElement("span");
      rank.className = "preview-rank";
      rank.textContent = String(item.rank).padStart(2, "0");
      const name = document.createElement("span");
      name.className = "preview-name";
      // 서버에서 온 카테고리 이름은 textContent로만 넣는다(랭킹 페이지와 같은 이유).
      name.textContent = item.category;
      card.append(rank, name);
      const li = document.createElement("li");
      li.appendChild(card);
      list.appendChild(li);
    }
    document.getElementById("home-ranking").hidden = false;
  } catch (e) {
    // 스펙 5장: 랭킹이 죽으면 섹션만 숨긴다.
    console.warn("랭킹 미리보기 로딩 실패:", e);
  }
}
```

(e) `submitDream` 안에서 아래 두 줄을 삭제한다:

```javascript
  submitBtn.textContent = "해몽하는 중…";
```
```javascript
    submitBtn.textContent = "해몽하기";
```

(f) 파일 끝 `loadWeather();` 아래에 추가:

```javascript
loadRankingPreview();
```

- [ ] **Step 5: 문법·계약 검증**

Run: V1, V2
Expected: `JS_OK`, `OK`

```bash
grep -n 'name.textContent = item.category' WEB/app.js
```
Expected: 1줄 출력.

- [ ] **Step 6: 브라우저 확인 — 테마·반응형**

V3로 서빙(BE 없이 먼저). 개발자도구 콘솔에서 테마를 강제한다:

```javascript
applyTheme("clear");   // → Figma 588:46
applyTheme("cloudy");  // → Figma 589:46
applyTheme("fog");     // → 흐림과 동일해야 함
applyTheme("rain");    // → Figma 590:46
applyTheme("snow");    // → Figma 591:46
```

| 확인 | 합격 |
|---|---|
| 테마 4종 | 폭 1280px에서 각 Figma 스크린샷과 하늘·땅 색, 경계선, 부제·헤드라인 문구·색, 입력 알약·버튼 색, 일러스트(태양/구름+장식) 일치 |
| 안개 | 흐림과 화면이 같음 |
| 입력 위치 | 알약 세로 중심이 경계선과 일치, 버튼이 알약 안에서 위·아래·오른쪽 간격 동일 |
| 상단바 정렬 | 로고 왼쪽 여백 = 날씨 표기 오른쪽 여백(날씨 위젯은 날씨 조회 성공 시에만 보임 — 네트워크가 되면 자동 표시) |
| 비·눈 장식 | 날씨 표기 글자와 겹치지 않음, 좌상단 모서리에 외딴 빗줄기 없음 |
| 모바일 360px | Figma 595:46처럼 버튼이 원형 "→", 헤드라인 24px 2줄, 태양 150px |
| 유동 스케일 | 360→1280px로 창을 천천히 넓힐 때 글자·태양·알약이 계단 없이 커짐(640px에서 버튼 모양만 바뀜) |
| 1600px | 요소가 1280px 값에서 더 커지지 않고, 가로 스크롤 없음 |
| 미리보기 | 로컬 BE 기동 + 랭킹 데이터가 있을 때 카드 6개(640px 이하 3개), 카드·"전체보기 →" 클릭 시 `ranking.html` |
| 미리보기 실패 | BE 꺼진 상태에서 섹션 자체가 보이지 않음 |

- [ ] **Step 7: Commit**

```bash
git add WEB/index.html WEB/home.css WEB/app.js WEB/style.css
git commit -m "$(cat <<'EOF'
feat: 홈 F1에 Figma 날씨 테마·일러스트·한 줄 입력·랭킹 미리보기 적용

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: 홈 F2~F5 — 결과 연출 + 길흉 낙관

**Files:**
- Modify: `WEB/home.css` — 파일 끝에 단계 연출 규칙 추가
- Modify: `WEB/app.js` — `submitDream`·`showExhaustedModal` 사이 흐름 교체, 연출 함수 추가, 이벤트 연결

**Interfaces:**
- Consumes: `applyTheme`, `weatherLabel`, `kstDateParts`(Task 3), `createSeal`, `luckOf`(Task 1), Task 3 신규 id(`result-date-long`, `result-date-short`, `result-quote`, `result-seal-slot`, `retry-btn`), `POST /demo/interpret` → `{ theme, vibe, suggested_feelings, ai_reply, remaining, dream_category }`
- Produces: 전역 함수 `showPaper(dream: string)`, `playResult(result: object) -> Promise<void>`, `backToInput()`, `retry()`, `setStage(stage: "stage-input"|"stage-paper"|"stage-writing"|"stage-done")` — 콘솔 검증에 사용

- [ ] **Step 1: `home.css` 끝에 단계 연출 추가**

```css
/* ════════════ 단계 연출 (F2~F5) ════════════ */
/* F2 종이가 올라온다: 하늘 496→352 (모바일 값은 데스크탑 비율로 환산) */
body.home.stage-paper {
  --sky-h: clamp(264px, calc(264px + 88 * var(--f)), 352px);
  --sun: clamp(130px, calc(130px + 70 * var(--f)), 200px);
  --sun-sink: -0.41;
  --cloud-bottom: -6px;
}
/* F3~F5: 하늘 →256 (Figma 588:87, 588:117 / 595:117) */
body.home.stage-writing,
body.home.stage-done {
  --sky-h: clamp(192px, calc(192px + 64 * var(--f)), 256px);
  --sun: clamp(108px, calc(108px + 59 * var(--f)), 167px);
  --sun-sink: -0.31;
  --cloud-bottom: clamp(-46px, calc(-32px - 14 * var(--f)), -32px);
}

.sky { transition: height 0.6s ease; }
.sun { transition: width 0.6s ease, height 0.6s ease, bottom 0.6s ease; }
.cloud { transition: bottom 0.6s ease; }

/* 경계선 위로 종이색이 번지는 띠 (Figma 588:78, 36px) */
.sky::after {
  content: "";
  position: absolute;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 1;
  height: 36px;
  background: linear-gradient(to bottom, transparent, var(--paper-bg));
  opacity: 0;
  transition: opacity 0.6s ease;
}
body.home:not(.stage-input) .sky::after { opacity: 1; }

.hero-copy { transition: opacity 0.3s ease, visibility 0.3s; }
body.home:not(.stage-input) .hero-copy {
  visibility: hidden;
  opacity: 0;
}
body.home:not(.stage-input) .dream-form,
body.home:not(.stage-input) .preview { display: none; }
body.home:not(.stage-input) .ground { background: var(--paper-bg); }

/* F2·F3 커서 */
.stage-paper #result-theme::after,
.stage-writing #result-theme::after {
  content: "|";
  margin-left: 2px;
  font-weight: 400;
  animation: caret-blink 1s steps(1) infinite;
}
@keyframes caret-blink {
  50% { opacity: 0; }
}

/* F4~F5 순차 등장 */
.result .reveal {
  opacity: 0;
  transform: translateY(8px);
  transition: opacity 0.5s ease, transform 0.5s ease;
}
.stage-done .result .reveal {
  opacity: 1;
  transform: none;
}
.stage-done #result-vibe { transition-delay: 0s; }
.stage-done #result-feelings { transition-delay: 0.15s; }
.stage-done .result-body { transition-delay: 0.3s; }
.stage-done .result-actions { transition-delay: 1.1s; }

/* 낙관: 설명이 뜬 뒤 도장이 찍히듯 줄어들며 나타난다 */
.result-seal {
  opacity: 0;
  transform: scale(1.4);
  transition: opacity 0.35s ease 0.9s, transform 0.35s cubic-bezier(0.2, 1.6, 0.4, 1) 0.9s;
}
.stage-done .result-seal {
  opacity: 1;
  transform: none;
}

@media (prefers-reduced-motion: reduce) {
  body.home *,
  body.home *::before,
  body.home *::after {
    transition: none !important;
    animation: none !important;
  }
}
```

- [ ] **Step 2: `app.js` — 연출 상수·함수 추가**

`showExhaustedModal` 함수 **위에** 추가한다:

```javascript
const STAGES = ["stage-input", "stage-paper", "stage-writing", "stage-done"];
const TYPE_INTERVAL_MS = 45;
// 하늘이 줄어드는 CSS 트랜지션(0.6s)이 끝난 뒤 타이핑해야 글자가 움직이는 박스 위에 찍히지 않는다.
const SKY_SHIFT_MS = 600;
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

let typingTimer = null;
// 연출 도중 "다시 풀어보기"나 재제출이 끼어들면 이전 연출의 남은 단계를 버리기 위한 번호.
let playToken = 0;

function setStage(stage) {
  document.body.classList.remove(...STAGES);
  document.body.classList.add(stage);
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, reduceMotion ? 0 : ms));
}

function stopTyping() {
  clearInterval(typingTimer);
  typingTimer = null;
}

function typeText(el, text) {
  stopTyping();
  const chars = Array.from(text);
  if (reduceMotion || chars.length === 0) {
    el.textContent = text;
    return Promise.resolve();
  }
  el.textContent = "";
  return new Promise((resolve) => {
    let i = 0;
    typingTimer = setInterval(() => {
      el.textContent += chars[i];
      i += 1;
      if (i === chars.length) {
        stopTyping();
        resolve();
      }
    }, TYPE_INTERVAL_MS);
  });
}

function fillResultMeta() {
  const { month, day, weekday } = kstDateParts();
  const suffix = weatherLabel ? ` · ${weatherLabel}` : "";
  document.getElementById("result-date-long").textContent = `${month}월 ${day}일 ${weekday}${suffix}`;
  document.getElementById("result-date-short").textContent = `${month}/${day} ${weekday.charAt(0)}${suffix}`;
}

// F2: 제출 즉시. BE 응답을 기다리는 동안 빈 박스 + 커서가 로딩 표시를 겸한다.
function showPaper(dream) {
  playToken += 1;
  stopTyping();
  fillResultMeta();
  document.getElementById("result-quote").textContent = `"${dream}"`;
  document.getElementById("result-theme").textContent = "";
  document.getElementById("result-vibe").textContent = "";
  document.getElementById("result-feelings").replaceChildren();
  document.getElementById("result-reply").textContent = "";
  document.getElementById("result-seal-slot").replaceChildren();
  document.getElementById("result").hidden = false;
  setStage("stage-paper");
}

// F3~F5
async function playResult(result) {
  const token = playToken;
  document.getElementById("result-vibe").textContent = result.vibe;
  const feelingsEl = document.getElementById("result-feelings");
  for (const feeling of result.suggested_feelings) {
    const li = document.createElement("li");
    li.textContent = feeling;
    feelingsEl.appendChild(li);
  }
  document.getElementById("result-reply").textContent = result.ai_reply;
  document.getElementById("result-seal-slot").appendChild(createSeal(luckOf(result.dream_category)));

  setStage("stage-writing");
  await wait(SKY_SHIFT_MS);
  if (token !== playToken) return;
  await typeText(document.getElementById("result-theme"), result.theme);
  if (token !== playToken) return;
  setStage("stage-done");
}

function backToInput() {
  playToken += 1;
  stopTyping();
  document.getElementById("result").hidden = true;
  setStage("stage-input");
}

function showInputError(message) {
  const errorEl = document.getElementById("input-error");
  errorEl.textContent = message;
  errorEl.hidden = false;
}

function retry() {
  backToInput();
  const input = document.getElementById("dream-input");
  input.value = "";
  input.focus();
}
```

- [ ] **Step 3: `app.js` — `submitDream` 전체 교체**

```javascript
async function submitDream(event) {
  event.preventDefault();
  const input = document.getElementById("dream-input");
  const submitBtn = document.getElementById("submit-btn");
  document.getElementById("input-error").hidden = true;

  const dream = input.value.trim();
  if (dream.length < 1 || dream.length > 500) {
    showInputError("꿈 내용은 1~500자로 입력해 주세요.");
    return;
  }

  submitBtn.disabled = true;
  showPaper(dream);
  let result;
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60000);
    const res = await fetch(`${API_BASE_URL}/demo/interpret`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ dream }),
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (res.status === 429) {
      const body = await res.json();
      backToInput();
      showExhaustedModal(body.reason);
      return;
    }
    if (res.status === 400) {
      const body = await res.json();
      backToInput();
      showInputError(body.detail);
      return;
    }
    if (!res.ok) {
      backToInput();
      showInputError("잠시 후 다시 시도해 주세요.");
      return;
    }
    result = await res.json();
  } catch (e) {
    backToInput();
    showInputError("잠시 후 다시 시도해 주세요.");
    return;
  } finally {
    // 연출 대기(await playResult) 전에 풀어야 연출 중 "다시 풀어보기" 후 재제출이 막히지 않는다.
    submitBtn.disabled = false;
  }

  // "내가 해몽한 꿈" — 서버는 방문자를 식별하지 않으므로 클라이언트가 세션 동안만 들고 있는다.
  sessionStorage.setItem("lastDreamCategory", result.dream_category);
  await playResult(result);

  if (result.remaining <= 0) {
    showExhaustedModal("ip");
  }
}
```

- [ ] **Step 4: `app.js` — 이벤트 연결**

파일 끝의 `document.getElementById("interpret-form").addEventListener("submit", submitDream);` 바로 아래에 추가:

```javascript
document.getElementById("retry-btn").addEventListener("click", retry);
```

- [ ] **Step 5: 문법·계약 검증**

Run: V1, V2
Expected: `JS_OK`, `OK`

```bash
grep -n 'textContent = "해몽' WEB/app.js
```
Expected: 출력 없음(버튼 문구 조작이 남아 있지 않음).

- [ ] **Step 6: 브라우저 확인 — BE 없이 연출만**

V3로 서빙, 폭 1280px, 콘솔:

```javascript
applyTheme("clear");
showPaper("높은 곳에서 하늘을 나는 꿈을 꿨어요");
// 3초 정도 F2 상태를 본 뒤:
playResult({
  theme: "날아오르는 꿈은 자신감이 차오르는 신호예요",
  vibe: "오늘 하루, 미뤄뒀던 일을 꺼내보기 좋은 날이에요",
  suggested_feelings: ["설렘", "해방감", "기대"],
  ai_reply: "높은 곳에서 하늘을 나는 꿈은 전통 해몽에서 억눌린 것에서 벗어나는 상징으로 읽힙니다. 최근 스스로를 시험하는 일이 있었다면, 그 결과를 기다리는 마음이 꿈으로 나타난 것일 수 있어요. 떨어지지 않고 끝까지 날았다면 특히 좋은 징조입니다.",
  remaining: 1,
  dream_category: "뱀",
});
```

| 확인 | 합격 |
|---|---|
| F2 | 헤드라인·입력·미리보기가 사라지고 하늘이 줄며 태양이 경계선 뒤로 내려감, 땅이 종이색, 빈 박스에 커서 깜빡임, 인용문 표시 — Figma 588:73 |
| F3 | 하늘이 한 번 더 줄어든 뒤 결론이 한 글자씩 찍힘 — Figma 588:87 |
| F5 | 코멘트 → 감정 칩 → 설명 → 吉 낙관(찍히듯) → 버튼 순으로 나타남 — Figma 588:117 |
| 인용문 | 박스 테두리와 겹치지 않음 |
| 결과 정렬 | 결과 영역이 화면 가로 중앙 |
| 날짜 줄 | "N월 N일 N요일"(날씨 조회 성공 시 " · 맑음" 추가), 오른쪽 "굿모닝 드림" |
| 도장 3종 | `dream_category`를 `"쫓김"`(凶 먹빛), `"물"`(吉凶 회색 두 글자), `"없는값"`(吉凶)으로 바꿔 각각 확인 |
| 테마별 낙관색 | `applyTheme("rain")` 후 같은 명령 → 吉이 `#a43b36` 계열 |
| 모바일 360px | Figma 595:117처럼 하늘 192px, 박스 제목 18px, 도장이 설명 아래 오른쪽, 버튼 "다시 풀기"·"앱에서 이어 쓰기", 날짜 "N/N 요" |
| 다시 풀어보기 | 클릭 시 F1으로 돌아오고 입력이 비고 포커스 |
| 연출 중 끼어들기 | `playResult(...)` 직후 0.3초 안에 `retry()` → F1 유지, 이후 F5로 튀지 않음 |
| 모션 줄이기 | 개발자도구 Rendering → Emulate `prefers-reduced-motion: reduce` 후 새로고침·재실행 → 즉시 F5 |

- [ ] **Step 7: 브라우저 확인 — BE 연동**

로컬 BE를 `WEB_ORIGIN=http://localhost:5500`으로 띄운다.

| 확인 | 방법 | 합격 |
|---|---|---|
| 정상 | 꿈 입력 후 Enter | F2(응답 대기 중 커서) → F3 → F5, 실제 응답 필드가 모두 표시 |
| 랭킹 연동 | 결과 확인 후 새로고침 → 미리보기의 "전체보기 →" 클릭 | 랭킹 페이지에 내 꿈 카드·"내 꿈" 태그 |
| 소진 | 같은 IP로 두 번째 해몽 완료 | F5까지 연출된 뒤 소진 팝업 |
| 429 | 세 번째 제출 | F2가 잠깐 보였다가 F1으로 복귀 + 팝업 |
| 400 | 콘솔 `document.getElementById("dream-input").removeAttribute("maxlength")` 후 501자 입력 제출 | 프론트 검증에서 F2로 가지 않고 인라인 메시지 |
| 5xx/네트워크 | BE 종료 후 제출 | F2 → F1 복귀 + "잠시 후 다시 시도해 주세요." |
| 팝업 닫기 | "닫기" | 팝업 사라짐(`[hidden]` 규칙 동작) |

- [ ] **Step 8: Commit**

```bash
git add WEB/home.css WEB/app.js
git commit -m "$(cat <<'EOF'
feat: 홈 해몽 결과에 F2~F5 전환 연출과 길흉 낙관 적용

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: 통합 검증 + PR

**Files:**
- 코드 변경 없음(검증에서 결함이 나오면 해당 태스크 파일을 고치고 별도 커밋)

**Interfaces:**
- Consumes: Task 1~4 결과 전체

- [ ] **Step 1: 정적 검증 일괄**

Run: V1, V2
Expected: `JS_OK`, `OK`

```bash
grep -n 'innerHTML' WEB/app.js WEB/ranking.js
```
Expected: `WEB/ranking.js`의 `li.innerHTML = \`` 템플릿(사전 상수만 삽입)과 `list.innerHTML = "";` 두 줄뿐. 템플릿 안에 `item.category`가 들어가지 않음을 눈으로 확인.

- [ ] **Step 2: 반응형 스윕**

V3 + 로컬 BE. 개발자도구 반응형 모드에서 폭 360 / 480 / 640 / 641 / 900 / 1280 / 1600px 각각:

| 화면 | 확인 |
|---|---|
| 홈 F1 (5개 테마 중 clear, rain) | 가로 스크롤 없음, 알약이 경계선 중앙, 미리보기 카드 겹침 없음 |
| 홈 F5 | 도장·설명·버튼 겹침 없음, 641~900px에서 도장이 설명 옆 또는 아래로 자연스럽게 위치 |
| 랭킹 F1 + 한 행 펼침 | 행 요소 겹침 없음, 641px에서 데스크탑 구성·640px에서 모바일 구성 |

- [ ] **Step 3: 스펙 합격 조건 대조**

`docs/superpowers/specs/2026-09-15-promo-web-figma-design-apply-design.md` 9장 표의 모든 행을 체크한다. 불합격 항목이 있으면 해당 태스크 파일을 고치고 V1·V2 재실행 후 커밋한다:

```bash
git add <고친 파일>
git commit -m "$(cat <<'EOF'
fix: <무엇을 고쳤는지>

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: 브랜치 푸시 + PR 생성**

main에 직접 머지하지 않는다. 원격 브랜치명은 `feat/` 관례를 따른다.

```bash
git push -u origin HEAD:feat/promo-web-figma-design
gh pr create --base main --head feat/promo-web-figma-design --title "feat: 홍보 웹페이지 Figma WF 디자인 적용" --body "$(cat <<'EOF'
## Summary
- 홈: 날씨 테마 4종(+안개=흐림), 한 줄 입력, 랭킹 미리보기, F2~F5 결과 연출, 길흉 낙관
- 랭킹 전체보기: 한지 디자인, 길흉 도장·범례, 해몽 전 카드, 순위 보기 자동 펼침, 펼침 트랜지션
- 360~1280px 유동 스케일(`--f`) + 640px 구조 분기, Figma 좌표 정렬 보정
- 스펙: docs/superpowers/specs/2026-09-15-promo-web-figma-design-apply-design.md

## Test plan
- [ ] `node --check` JS 3개, id 계약 스크립트 OK
- [ ] 테마 4종 + 안개 Figma 대조
- [ ] 로컬 BE로 정상/400/429/5xx 흐름
- [ ] 랭킹 F1~F4, 펼침 트랜지션, 모바일 구성
- [ ] 360/640/641/1280/1600px 반응형 스윕

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL 출력.
