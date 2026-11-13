const API_BASE_URL = "https://re-view-uxww.onrender.com"; // 배포 시 Render URL로 교체

// 데모 남용 방지용 방문자 식별자(ADR 0002). 쿠키가 아니라 localStorage — WEB과 BE가
// 다른 도메인이라 쿠키를 쓰면 서드파티 쿠키가 되어 Safari 등에서 조용히 차단된다.
// 이 값은 우리 JS가 직접 헤더에 담아 보내므로 그 문제가 없다.
const VISITOR_ID_KEY = "demoVisitorId";

function getVisitorId() {
  let id = localStorage.getItem(VISITOR_ID_KEY);
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem(VISITOR_ID_KEY, id);
  }
  return id;
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
      // 서버에서 온 태그 이름은 textContent로만 넣는다(랭킹 페이지와 같은 이유).
      name.textContent = item.tag;
      card.append(rank, name);
      const li = document.createElement("li");
      li.appendChild(card);
      list.appendChild(li);
    }
    document.getElementById("home-ranking").hidden = false;
  } catch (e) {
    // 랭킹이 죽으면 섹션만 숨긴다.
    console.warn("랭킹 미리보기 로딩 실패:", e);
  }
}

// B1 입력 → B2 카드를 고르는 중 → B3 뒤집히며 올라감 → B4 앞면 → B5 태그와 한 줄 설명, 안내 문구(카드 클릭 대기) → 결과
const STAGES = ["stage-input", "stage-paper", "stage-flip", "stage-front", "stage-reveal", "stage-done"];
const CAPTIONS = {
  "stage-paper": "한 장을 고르는 중...",
  "stage-flip": "뒤집는 중",
  "stage-reveal": "카드를 누르면 해몽을 볼 수 있어요",
};
const FLIP_MS = 900; // home.css의 stage-flip --card-dur와 맞춘다.
const FRONT_HOLD_MS = 1000;
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

// 연출 도중 "다시 해보기"나 재제출이 끼어들면 이전 연출의 남은 단계를 버리기 위한 번호.
let playToken = 0;
let lastDream = "";

function setStage(stage) {
  document.body.classList.remove(...STAGES);
  document.body.classList.add(stage);
  document.getElementById("stage-caption").textContent = CAPTIONS[stage] || "";
  // B4에서 눌러도 받는다. 앞면이 가장 크게 보이는 순간이라 사람들이 바로 누르기 때문이다.
  document.getElementById("tarot-card").disabled = stage !== "stage-front" && stage !== "stage-reveal";
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, reduceMotion ? 0 : ms));
}

function showRemaining(count) {
  document.getElementById("remaining-count").textContent = String(count);
  document.getElementById("remaining").hidden = false;
}

// /demo/tarot 응답을 화면 칸으로 옮긴다. summary는 tag의 한 줄 정의다. 필드가 바뀌면 이 함수만 고친다.
function readReading(data) {
  return {
    imageUrl: data.card.image_url,
    tag: data.tag,
    summary: data.summary,
    details: data.details,
  };
}

// 카드 앞면은 태그 사진 한 장이다(card.image_url, API 기준 상대 경로). 뒤집기 전에 다 받아 두고,
// 없거나 제때 못 받으면 뒷면 문양을 옅게 그린 대체 표시를 쓴다.
const ART_TIMEOUT_MS = 5000; // 사진이 장당 약 270KB라 느린 모바일 회선을 감안한다.

async function renderCardArt(imageUrl) {
  const art = document.getElementById("card-art");
  const emblem = document.createElement("span");
  emblem.className = "emblem";
  emblem.setAttribute("aria-hidden", "true");
  emblem.appendChild(document.createElement("span"));
  art.replaceChildren(emblem);
  if (!imageUrl) return;

  const img = new Image();
  img.className = "card-photo";
  img.alt = "";
  img.src = new URL(imageUrl, API_BASE_URL).href;
  try {
    await Promise.race([
      img.decode(),
      new Promise((_, reject) => setTimeout(() => reject(new Error("시간 초과")), ART_TIMEOUT_MS)),
    ]);
    art.replaceChildren(img);
  } catch (e) {
    console.warn("카드 사진 로딩 실패:", e);
  }
}

// 상세 설명은 keyword로 시작한다(#57 스키마). 시안처럼 앞의 keyword만 굵게 쓴다.
function renderDetail(detail) {
  const p = document.createElement("p");
  if (detail.description.startsWith(detail.keyword)) {
    const strong = document.createElement("strong");
    strong.textContent = detail.keyword;
    p.append(strong, detail.description.slice(detail.keyword.length));
  } else {
    p.textContent = detail.description;
  }
  return p;
}

async function fillReading(reading) {
  await renderCardArt(reading.imageUrl);
  document.getElementById("result-tag").textContent = reading.tag;
  document.getElementById("result-summary").textContent = reading.summary;
  document.getElementById("result-details").replaceChildren(...reading.details.map(renderDetail));
}

// B3 → B4 → B5는 터치 없이 이어진다. B5에서 카드를 누를 때까지 멈춘다.
async function playFlip() {
  const token = playToken;
  setStage("stage-flip");
  await wait(FLIP_MS);
  if (token !== playToken) return;
  setStage("stage-front");
  await wait(FRONT_HOLD_MS);
  if (token !== playToken) return;
  setStage("stage-reveal");
}

// 카드 클릭 → 결과. B4에서 누르면 남은 B5 대기를 버리고 바로 결과로 간다.
function showResult() {
  playToken += 1;
  setStage("stage-done");
}

function backToInput() {
  playToken += 1;
  setStage("stage-input");
}

function showInputError(message) {
  const errorEl = document.getElementById("input-error");
  errorEl.textContent = message;
  errorEl.hidden = false;
}

function showExhaustedModal(reason) {
  const message = document.getElementById("exhausted-message");
  message.textContent =
    reason === "global"
      ? "지금 많은 분들이 이용 중이에요. 잠시 후 다시 시도해 주세요."
      : "오늘 무료 체험을 다 쓰셨어요.";
  document.getElementById("exhausted-modal").hidden = false;
}

// 503은 서버가 AI 실패를 알린 경우, 나머지(연결 끊김, 60초 시간 초과)는 서버가 늦게라도 처리했을 수 있다.
// 제목은 둘 다 "연결이 원활하지 않아요"로 같고, 횟수 차감 여부는 말하지 않는다.
function showErrorModal(cause) {
  document.getElementById("error-message").textContent =
    cause === "ai" ? "잠시 후 다시 시도해 주세요." : "인터넷 연결을 확인하고 다시 시도해 주세요.";
  document.getElementById("error-modal").hidden = false;
}

async function drawCard(dream) {
  const submitBtn = document.getElementById("submit-btn");
  document.getElementById("input-error").hidden = true;
  submitBtn.disabled = true;
  playToken += 1;
  setStage("stage-paper");

  let data;
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60000);
    const res = await fetch(`${API_BASE_URL}/demo/tarot`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Demo-Visitor-Id": getVisitorId() },
      body: JSON.stringify({ dream }),
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (res.status === 429) {
      const body = await res.json();
      backToInput();
      showRemaining(0);
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
      showErrorModal("ai");
      return;
    }
    data = await res.json();
  } catch (e) {
    backToInput();
    showErrorModal("net");
    return;
  } finally {
    submitBtn.disabled = false;
  }

  // "나의 태그" 표시용. 서버는 방문자를 식별하지 않으므로 클라이언트가 세션 동안만 들고 있는다.
  sessionStorage.setItem("lastDreamTag", data.tag);
  showRemaining(data.remaining);
  // 사진을 받는 동안은 B2(카드를 고르는 중)에 머문다.
  await fillReading(readReading(data));
  await playFlip();
}

function submitDream(event) {
  event.preventDefault();
  const dream = document.getElementById("dream-input").value.trim();
  if (dream.length < 1 || dream.length > 500) {
    showInputError("꿈 내용은 1~500자로 입력해 주세요.");
    return;
  }
  lastDream = dream;
  drawCard(dream);
}

// "다시 해보기"는 첫 화면(입력)으로 돌아가 새 꿈을 받는다(시안 메모 994:374). 서버 요청이 없어 횟수도 그대로다.
// 같은 꿈으로 다시 요청하는 것은 오류 안내 창의 "다시 시도"뿐이다.
function retry() {
  backToInput();
  document.getElementById("dream-input").value = "";
  window.scrollTo(0, 0);
}

async function share() {
  const btn = document.getElementById("share-btn");
  const tag = document.getElementById("result-tag").textContent;
  const payload = { title: "굿모닝 드림", text: `오늘 내 꿈의 태그는 "${tag}"`, url: location.href };
  try {
    if (navigator.share) {
      await navigator.share(payload);
      return;
    }
    await navigator.clipboard.writeText(location.href);
    btn.textContent = "링크 복사됨";
    setTimeout(() => { btn.textContent = "공유"; }, 1500);
  } catch (e) {
    // 사용자가 공유 창을 닫으면 AbortError가 난다. 알릴 일이 아니다.
    console.warn("공유 실패:", e);
  }
}

document.getElementById("interpret-form").addEventListener("submit", submitDream);
document.getElementById("tarot-card").addEventListener("click", showResult);
document.getElementById("retry-btn").addEventListener("click", retry);
document.getElementById("share-btn").addEventListener("click", share);
document.getElementById("modal-close").addEventListener("click", () => {
  document.getElementById("exhausted-modal").hidden = true;
});
document.getElementById("error-close").addEventListener("click", () => {
  document.getElementById("error-modal").hidden = true;
});
document.getElementById("error-retry").addEventListener("click", () => {
  document.getElementById("error-modal").hidden = true;
  drawCard(lastDream);
});

loadRankingPreview();
