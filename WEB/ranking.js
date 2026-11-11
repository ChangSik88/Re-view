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

function buildRow(item, myTag) {
  const isMine = item.tag === myTag;

  const li = document.createElement("li");
  li.className = "ranking-item" + (isMine ? " is-mine" : "");
  li.innerHTML = `
    <button class="ranking-row" type="button" aria-expanded="false">
      <span class="rank">${item.rank}</span>
      <span class="name"></span>
      <span class="summary"></span>
      ${isMine ? '<span class="mine-tag">내 태그</span>' : ""}
      <svg class="chevron" viewBox="0 0 20 20" aria-hidden="true"><path d="M5 7.5L10 12.5L15 7.5" /></svg>
    </button>
    <div class="ranking-panel" aria-hidden="true">
      <div class="ranking-panel-inner">
        <p class="panel-label">태그 풀이</p>
        <p class="panel-summary"></p>
      </div>
    </div>
  `;

  // 서버에서 온 문자열(태그 이름, 정의)은 innerHTML에 끼워 넣지 않고 textContent로 채운다.
  // 태그 풀이 본문은 BE에 아직 없다(dream_tags.json). 생기면 panel-summary 아래에 붙인다.
  li.querySelector(".name").textContent = item.tag;
  li.querySelector(".summary").textContent = item.definition;
  li.querySelector(".panel-summary").textContent = item.definition;

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
  document.getElementById("mine-name").textContent = mine.tag;
  document.getElementById("mine-rank").textContent = `오늘 ${mine.rank}위`;
  document.getElementById("mine-goto").addEventListener("click", () => {
    setOpen(mineRow, true);
    // 행을 만들 때 잡아둔 참조로 스크롤한다. 태그 이름으로 속성 선택자를 만들면
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
  goto.addEventListener("click", () => {
    location.href = "index.html";
  });
  card.hidden = false;
}

async function loadRanking() {
  const myTag = sessionStorage.getItem("lastDreamTag");
  const loadingEl = document.getElementById("ranking-loading");

  try {
    // 크론이 쉬는 02:00~07:00 KST에는 Render 콜드 스타트로 수십 초가 걸릴 수 있다.
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60000);
    const res = await fetch(`${API_BASE_URL}/demo/ranking`, { signal: controller.signal });
    clearTimeout(timeout);
    if (!res.ok) throw new Error("랭킹 실패");
    const data = await res.json();

    document.getElementById("ranking-date").textContent = formatKoreanDate(data.date);

    if (data.items.length === 0) {
      document.getElementById("ranking-empty").hidden = false;
      showMineEmpty();
      return;
    }

    const list = document.getElementById("ranking-list");
    list.innerHTML = "";
    let mineRow = null;
    for (const item of data.items) {
      const row = buildRow(item, myTag);
      if (item.tag === myTag) mineRow = row;
      list.appendChild(row);
    }

    const mine = data.items.find((item) => item.tag === myTag);
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
