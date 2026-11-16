// WEB/을 dist/로 복사하고 미니앱에 필요한 차이만 덮어쓴다. 화면 코드는 WEB/ 한 곳에만 둔다.
import { cpSync, readFileSync, rmSync, writeFileSync } from "node:fs";

const API = "https://re-view-uxww.onrender.com";

// 토스 출시 체크리스트: 자체 뒤로가기와 토스 내비 뒤로가기 중복 금지, 자사 앱 설치 유도 금지.
// 공유는 intoss:// 스킴이 필요해 2단계에서 SDK로 붙인다.
const HIDE = `<style>.rk-back, #share-btn, #app-store-link { display: none !important; }</style>\n</head>`;

// 찾을 문자열이 없으면 WEB/이 바뀐 것이다. 조용히 넘어가지 않고 빌드를 멈춘다.
function patch(file, pairs) {
  let text = readFileSync(file, "utf8");
  for (const [from, to] of pairs) {
    const found = from instanceof RegExp ? from.test(text) : text.includes(from);
    if (!found) {
      throw new Error(`${file}: 바꿀 문자열을 찾지 못했다: ${from}`);
    }
    text = text.replace(from, to);
  }
  writeFileSync(file, text);
}

rmSync("dist", { recursive: true, force: true });
cpSync("../WEB", "dist", { recursive: true });

const apiLine = [/^const API_BASE_URL = .*$/m, `const API_BASE_URL = "${API}";`];
patch("dist/app.js", [apiLine]);
patch("dist/ranking.js", [apiLine]);
patch("dist/index.html", [["</head>", HIDE]]);
patch("dist/ranking.html", [["</head>", HIDE]]);
