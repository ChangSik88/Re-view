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

async function loadWeather() {
  try {
    const geoRes = await fetch("https://ipapi.co/json/");
    if (!geoRes.ok) throw new Error("ipapi 실패");
    const geo = await geoRes.json();
    const { latitude, longitude, city } = geo;

    const weatherRes = await fetch(
      `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}&current_weather=true`
    );
    if (!weatherRes.ok) throw new Error("open-meteo 실패");
    const weather = await weatherRes.json();
    const code = weather.current_weather.weathercode;

    document.body.className = `theme-${themeForWmoCode(code)}`;
    const widget = document.getElementById("weather-widget");
    document.getElementById("weather-city").textContent = city || "";
    document.getElementById("weather-desc").textContent = `현재 기온 ${weather.current_weather.temperature}°C`;
    widget.hidden = false;
  } catch (e) {
    // 실패해도 기본 테마 유지, 위젯은 숨김 (스펙 5장)
    console.warn("날씨 로딩 실패:", e);
  }
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
  const errorEl = document.getElementById("input-error");
  const submitBtn = document.getElementById("submit-btn");
  errorEl.hidden = true;

  const dream = input.value.trim();
  if (dream.length < 1 || dream.length > 500) {
    errorEl.textContent = "꿈 내용은 1~500자로 입력해 주세요.";
    errorEl.hidden = false;
    return;
  }

  submitBtn.disabled = true;
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
      showExhaustedModal(body.reason);
      return;
    }
    if (res.status === 400) {
      const body = await res.json();
      errorEl.textContent = body.detail;
      errorEl.hidden = false;
      return;
    }
    if (!res.ok) {
      errorEl.textContent = "잠시 후 다시 시도해 주세요.";
      errorEl.hidden = false;
      return;
    }

    const result = await res.json();
    document.getElementById("result-theme").textContent = result.theme;
    document.getElementById("result-vibe").textContent = result.vibe;
    const feelingsEl = document.getElementById("result-feelings");
    feelingsEl.innerHTML = "";
    for (const feeling of result.suggested_feelings) {
      const li = document.createElement("li");
      li.textContent = feeling;
      feelingsEl.appendChild(li);
    }
    document.getElementById("result-reply").textContent = result.ai_reply;
    document.getElementById("result").hidden = false;

    // "내가 해몽한 꿈" — 서버는 방문자를 식별하지 않으므로 클라이언트가 세션 동안만 들고 있는다.
    sessionStorage.setItem("lastDreamCategory", result.dream_category);

    if (result.remaining <= 0) {
      showExhaustedModal("ip");
    }
  } catch (e) {
    errorEl.textContent = "잠시 후 다시 시도해 주세요.";
    errorEl.hidden = false;
  } finally {
    submitBtn.disabled = false;
  }
}

document.getElementById("interpret-form").addEventListener("submit", submitDream);
document.getElementById("modal-close").addEventListener("click", () => {
  document.getElementById("exhausted-modal").hidden = true;
});

loadWeather();
