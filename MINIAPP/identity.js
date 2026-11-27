// 토스 사용자 식별키를 WEB/app.js의 방문자 ID 자리에 넣는다. build.mjs가 묶어서 app.js보다 먼저 실행한다.
// 실패하거나 지원되지 않으면 아무것도 저장하지 않아 app.js의 임의 UUID가 그대로 쓰인다.
// 서버는 이 값을 하루 횟수 카운터 키로만 쓴다. 로그인이나 사용자 데이터에 쓰게 되면
// User.createAnonymousKeyAuthCode()와 서버 교환 방식으로 바꿔야 한다.
import { User } from "@apps-in-toss/web-framework";

const STORAGE_KEY = "demoVisitorId";
const HEADER = "X-Demo-Visitor-Id";
const WAIT_MS = 2000; // SDK 브리지에는 시간 제한이 없다.

async function saveAnonymousKey() {
  try {
    const { hash } = await User.getAnonymousKey();
    // 서버가 100자에서 자르고, 헤더에 못 넣는 문자가 있으면 fetch가 실패한다.
    if (!/^[\x21-\x7e]{1,100}$/.test(hash)) {
      console.warn("식별키를 헤더에 쓸 수 없는 형식:", hash.length);
      return;
    }
    localStorage.setItem(STORAGE_KEY, hash);
  } catch (e) {
    console.warn("식별키 발급 실패:", e);
  }
}

const ready = Promise.race([
  saveAnonymousKey(),
  new Promise((resolve) => setTimeout(resolve, WAIT_MS)),
]);

// 식별키가 오기 전에 해몽을 누르면 app.js가 UUID를 이미 헤더에 담은 상태라, 보내기 직전에 다시 읽는다.
const originalFetch = window.fetch;
window.fetch = async (input, init) => {
  if (init?.headers?.[HEADER]) {
    await ready;
    init.headers[HEADER] = localStorage.getItem(STORAGE_KEY);
  }
  return originalFetch(input, init);
};
