const API_BASE_URL = "http://localhost:8000"; // 배포 시 Render URL로 교체

function luckBadgeHtml(category) {
  const entry = CATEGORY_DICTIONARY[category];
  const luck = entry ? entry.luck : "b";
  return `<span class="badge badge-${luck}">${LUCK_LABEL[luck]}</span>`;
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
    <button class="ranking-row" aria-expanded="false">
      <span class="rank">${item.rank}</span>
      <span class="name"></span>
      ${luckBadgeHtml(item.category)}
      <span class="summary">${entry.summary}</span>
      ${isMine ? '<span class="mine-tag">내 꿈</span>' : ""}
      <span class="chevron">⌄</span>
    </button>
    <div class="ranking-panel" hidden>
      <p class="ranking-panel-text">${entry.text}</p>
      ${isMine ? '<p class="ranking-panel-foot">오늘 이 꿈을 해몽했습니다.</p>' : ""}
    </div>
  `;

  // 카테고리 이름만 서버에서 오는 값이다. innerHTML에 끼워 넣지 않고 textContent로 채운다.
  // 지금은 BE가 13종 화이트리스트로 정규화해 안전하지만, 카테고리 목록을 넓힐 때
  // 그 정규화를 놓치면 여기가 그대로 XSS 통로가 된다.
  li.querySelector(".name").textContent = item.category;

  li.querySelector(".ranking-row").addEventListener("click", () => {
    const expanded = li.classList.toggle("open");
    li.querySelector(".ranking-row").setAttribute("aria-expanded", String(expanded));
    li.querySelector(".ranking-panel").hidden = !expanded;
  });

  return li;
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

    document.getElementById("ranking-date").textContent = `${data.date} · 오늘 해몽된 꿈만 모았습니다`;

    if (data.items.length === 0) {
      document.getElementById("ranking-empty").hidden = false;
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
      document.getElementById("mine-name").textContent = mine.category;
      document.getElementById("mine-rank").textContent = `오늘 ${mine.rank}위`;
      document.getElementById("mine-card").hidden = false;
      // 행을 만들 때 잡아둔 참조로 스크롤한다. 카테고리 이름으로 속성 선택자를 만들면
      // 이름에 따옴표가 섞이는 순간 선택자 자체가 깨진다.
      document.getElementById("mine-goto").addEventListener("click", () => {
        mineRow?.scrollIntoView({ behavior: "smooth", block: "center" });
      });
    }
  } catch (e) {
    console.warn("랭킹 로딩 실패:", e);
    document.getElementById("ranking-error").hidden = false;
  } finally {
    loadingEl.hidden = true;
  }
}

loadRanking();
