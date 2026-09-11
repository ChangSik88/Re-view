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
  li.dataset.category = item.category;
  li.innerHTML = `
    <button class="ranking-row" aria-expanded="false">
      <span class="rank">${item.rank}</span>
      <span class="name">${item.category}</span>
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

  li.querySelector(".ranking-row").addEventListener("click", () => {
    const expanded = li.classList.toggle("open");
    li.querySelector(".ranking-row").setAttribute("aria-expanded", String(expanded));
    li.querySelector(".ranking-panel").hidden = !expanded;
  });

  return li;
}

async function loadRanking() {
  const myCategory = sessionStorage.getItem("lastDreamCategory");

  try {
    const res = await fetch(`${API_BASE_URL}/demo/ranking`);
    if (!res.ok) throw new Error("랭킹 실패");
    const data = await res.json();

    document.getElementById("ranking-date").textContent = `${data.date} · 오늘 해몽된 꿈만 모았습니다`;

    if (data.items.length === 0) {
      document.getElementById("ranking-empty").hidden = false;
      return;
    }

    const list = document.getElementById("ranking-list");
    list.innerHTML = "";
    for (const item of data.items) {
      list.appendChild(buildRow(item, myCategory));
    }

    const mine = data.items.find((item) => item.category === myCategory);
    if (mine) {
      document.getElementById("mine-name").textContent = mine.category;
      document.getElementById("mine-rank").textContent = `오늘 ${mine.rank}위`;
      document.getElementById("mine-card").hidden = false;
      document.getElementById("mine-goto").addEventListener("click", () => {
        const target = list.querySelector(`[data-category="${mine.category}"]`);
        target?.scrollIntoView({ behavior: "smooth", block: "center" });
      });
    }
  } catch (e) {
    console.warn("랭킹 로딩 실패:", e);
    document.getElementById("ranking-error").hidden = false;
  }
}

loadRanking();
