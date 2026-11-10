"use strict";
const api = ["localhost", "127.0.0.1"].includes(location.hostname)
  ? "http://localhost:8000" : "https://re-view-uxww.onrender.com";
const el = id => document.getElementById(id);
let token = "";
let original;

function signOut() {
  token = "";
  original = null;
  el("login").reset();
  el("edit").reset();
  el("login-id").textContent = "";
  el("profile").hidden = true;
  el("login").hidden = false;
}
function showProfile(data) {
  original = data;
  el("login-id").textContent = data.id;
  for (const field of ["name", "birth", "gender"]) el(field).value = data[field] ?? "";
  el("profile").hidden = false;
  el("login").hidden = true;
}
async function request(path, method, body) {
  const headers = {};
  if (token) headers.Authorization = "Bearer " + token;
  if (body) headers["Content-Type"] = "application/json";
  const response = await fetch(api + "/users/" + path, {
    method, headers, body: body && JSON.stringify(body), cache: "no-store"
  });
  if (response.status === 401) {
    if (path === "login") throw Error("아이디 또는 비밀번호를 확인해 주세요.");
    signOut();
    throw Error("다시 로그인해 주세요.");
  }
  if (!response.ok) throw Error(response.status === 422 ? "입력한 값을 확인해 주세요." : "서버 요청을 완료하지 못했습니다.");
  return response.status === 204 ? null : response.json();
}
let pending = false;
async function run(task) {
  if (pending) return;
  pending = true;
  const controls = document.querySelectorAll("input,select,button");
  controls.forEach(control => control.disabled = true);
  el("status").textContent = "처리 중…";
  try { el("status").textContent = await task(); }
  catch (error) { el("status").textContent = error instanceof TypeError ? "서버 연결을 확인해 주세요." : error.message; }
  finally { pending = false; controls.forEach(control => control.disabled = false); }
}
el("login").onsubmit = event => {
  event.preventDefault();
  run(async () => {
    token = "";
    const data = await request("login", "POST", {userAccount: el("account").value, password: el("password").value});
    token = data.access_token;
    el("password").value = "";
    try { showProfile((await request("me", "GET")).result); }
    catch (error) { signOut(); throw error; }
    return "";
  });
};
el("edit").onsubmit = event => {
  event.preventDefault();
  run(async () => {
    const changes = {};
    for (const key of ["name","birth","gender"]) {
      const value = el(key).value.trim() || null;
      if (value !== original[key]) changes[key] = value;
    }
    if (!Object.keys(changes).length) return "변경한 내용이 없습니다.";
    showProfile((await request("me", "PATCH", changes)).result);
    return "저장했습니다.";
  });
};
el("logout").onclick = () => { signOut(); el("status").textContent = "로그아웃했습니다."; };
el("withdraw").onclick = () => {
  if (!confirm("탈퇴하면 이 계정으로 다시 로그인할 수 없습니다. 탈퇴할까요?")) return;
  run(async () => { await request("me", "DELETE"); signOut(); return "회원 탈퇴가 완료됐습니다."; });
};
