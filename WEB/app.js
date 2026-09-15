const API_BASE_URL = "http://localhost:8000"; // 배포 시 Render URL로 교체

const WMO_THEME_MAP = {
  clear: [0, 1],
  cloudy: [2, 3],
  fog: [45, 48],
  rain: [51, 52, 53, 54, 55, 56, 57, 61, 62, 63, 64, 65, 66, 67, 80, 81, 82, 95, 96, 97, 98, 99],
  snow: [71, 72, 73, 74, 75, 76, 77, 85, 86],
};

function themeForWmoCode(code) {
  for (const [theme, codes] of Object.entries(WMO_THEME_MAP)) {
    if (codes.includes(code)) return theme;
  }
  return "clear";
}

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

// ipapi.co가 차단되거나 레이트리밋에 걸려도 날씨는 보여준다. 스펙상 폴백 좌표는 서울이다.
const SEOUL_COORDS = { latitude: 37.5665, longitude: 126.978 };

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

async function loadRankingPreview() {
  try {
    // 크론이 쉬는 02:00~07:00 KST에는 Render 콜드 스타트로 수십 초가 걸릴 수 있다.
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60000);
    const res = await fetch(`${API_BASE_URL}/demo/ranking`, { signal: controller.signal });
    clearTimeout(timeout);
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

const STAGES = ["stage-input", "stage-paper", "stage-writing", "stage-done"];
const TYPE_INTERVAL_MS = 45;
// 하늘이 줄어드는 CSS 트랜지션(0.6s)이 끝난 뒤 타이핑해야 글자가 움직이는 박스 위에 찍히지 않는다.
const SKY_SHIFT_MS = 600;
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

let typingTimer = null;
let typingResolve = null;
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
  const resolve = typingResolve;
  typingResolve = null;
  if (resolve) resolve();
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
    typingResolve = resolve;
    let i = 0;
    typingTimer = setInterval(() => {
      el.textContent += chars[i];
      i += 1;
      if (i === chars.length) {
        stopTyping();
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

function showExhaustedModal(reason) {
  const message = document.getElementById("exhausted-message");
  message.textContent =
    reason === "global"
      ? "지금 많은 분들이 이용 중이에요. 앱에서는 대기 없이 이용할 수 있어요!"
      : "오늘 무료 체험을 다 쓰셨어요. 앱 설치 시 추가 기회를 무료로 드려요!";
  document.getElementById("exhausted-modal").hidden = false;
}

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

document.getElementById("interpret-form").addEventListener("submit", submitDream);
document.getElementById("retry-btn").addEventListener("click", retry);
document.getElementById("modal-close").addEventListener("click", () => {
  document.getElementById("exhausted-modal").hidden = true;
});

loadWeather();
loadRankingPreview();
