# 앱 리디자인 이관 계획

Figma `WF(앱버전)`(`104:433`)의 리디자인을 Flutter 앱에 옮기는 순서와 단위다.

관련: [Figma 앱 인벤토리](../30-design/02-figma-app-inventory.md) · [BE 갭 조사](2026-09-19-app-redesign-be-gap.md) · [감정 라벨 ADR](../40-decisions/0002-emotion-label-taxonomy.md) · [미작성 화면 브리프](../30-design/03-missing-screens-brief.md)

## 전제

- **기존 화면은 전부 교체한다.** 신구 화면이 공존하는 기간이 없으므로 토큰을 점진 대체하지 않고 통째로 갈아엎는다.
- **다크 → 라이트 전환이다.** 배경 `#100D10` → `#FFFFFF`, 포인트 `#8F6CFF` → `#6E63FF`. 배경만이 아니라 포인트 색까지 바뀐다.
- **구매·결제·배송·장바구니는 범위 밖이다.** PG 계약이 선행 사안이다.

## 단계

```
0. 기반
   ├─→ 1. BE 없는 화면 ─┐
   └─→ 2. BE 작업 ──────┴─→ 3. BE 의존 화면
                              └─→ 4. 디자인 대기 화면
```

1과 2는 병렬이다. 실제 소요는 `0 → (1‖2) → 3 → 4`.

### 0단계 — 기반

모든 화면이 여기 의존하므로 가장 먼저, 그리고 한 번에 끝낸다. 여기서 틀리면 15개 화면을 다시 고쳐야 한다.

- `FE/lib/theme/app_theme.dart` 색·타이포 토큰을 라이트 기준으로 재정의. `AppTheme.theme`가 지금은 `primarySwatch: Colors.purple` 한 줄뿐이라 실제 테마도 채운다
- `docs/30-design/01-design-tokens.md` 갱신 — 현재 구버전 다크 기준이라 그대로 두면 오독을 부른다
- 공용 위젯 신설: 하단탭(홈/AI-채팅/스토어/설정), 카드, 칩, 버튼, 앱바
- `main.dart` 정리 — 튜토리얼 주석(`// 💡 메모장에 미리 복사해둘...`)과 라우트 정리

**완료 조건**: 기존 화면 하나를 새 토큰으로 바꿔 띄웠을 때 색 리터럴이 남지 않는다.

### 1단계 — BE 없이 되는 화면

2단계와 병렬로 진행한다. 더미로 두는 부분을 미리 정해 뒀다.

| 화면 | 노드 | 더미 처리 |
|---|---|---|
| 로그인 | `104:446` | Google 버튼 비활성 |
| 회원가입 | `107:627` | – |
| 홈(로그인 O / X) | `516:783` `500:905` | Dream Calendar 위젯 |
| 스토어 목록 | `509:560` `505:509` | – |
| 상품 상세 | `510:788` `514:428` | 뱃지 하드코딩, [장바구니][구매하기] 비활성 |
| 모닝 채팅 | `476:548` | 구조화 정보 카드 |
| 나이트 채팅 | `516:1114` | – |

**선행 하나**: 상품 상세의 이미지 캐러셀은 2단계 F(서비스 3줄 수정)가 먼저 있어야 한다. 0단계 직후에 F만 떼어 처리한다.

### 2단계 — BE 작업

A가 C와 3단계 전부의 전제다. **A부터 한다.**

| # | 작업 | 엔드포인트 |
|---|---|---|
| A | 감정 저장·집계 — `ChatEmotion` 모델, 추출, 집계 | `GET /report/emotions` 신규, `GET /report/emotions/timeline` 신규 |
| B | 대시보드 조회 확장 | `GET /chatting/session/all`에 `routine_type`·`from`·`to` |
| C | 월간 캘린더 | `GET /chatting/calendar` 신규 |
| D | 상세 데이터 — `advice` 추가, `tags` 폭 확장 | `POST /chatting/diary`, `GET /chatting/session/single/{id}` |
| E | 채팅 구조화 정보 카드 | `POST /chatting/message`, `POST /chatting/diary` |
| F | 상품 이미지 배열·뱃지 | `GET /item/detail/{id}` |

명세는 Notion `AI SW 융합연구개발 / 개발 / 📋 API 명세서`에 작성돼 있다. 신규 3개는 페이지가 만들어져 있고, 수정 5개는 기존 페이지 하단에 `## 변경 예정 — 리디자인` 절로 붙어 있다. 구현이 끝나면 그 절을 본문에 녹이고 제거한다.

**스키마 변경 3건**: `ChatEmotion` 신설, `ChatRoom.tags` 폭 확장, `Item` 뱃지 필드. 루트에서 `prisma migrate deploy --schema=BE/prisma/schema.prisma`로 적용한다.

### 3단계 — BE 의존 화면

2단계가 끝나야 시작한다.

- 꿈 대시보드 — 통계 뷰 `409:738`, 목록 뷰 `519:1347`
- 하루 대시보드 — `552:275`
- 월간 캘린더 — `515:743`
- 꿈 상세 — AI 요약 `519:1448`, 전문 보기 `519:1515`
- 하루 상세 — 하루 보기 `552:370`, 감정 인사이트 `554:680`

### 4단계 — 디자인 대기 화면

[미작성 화면 브리프](../30-design/03-missing-screens-brief.md)의 5건이다. 디자인이 나오는 대로 순차 이관한다. 우선순위는 꿈 상세 인사이트 탭 · 설정이 높고, 감정 전체보기 · 검색 결과 · 알림 목록이 뒤다.

## PR 단위

단계별로 브랜치를 끊되 1단계만 화면 묶음으로 나눈다. 한 PR이 너무 커지면 리뷰가 안 되기 때문이다.

| 브랜치 | 범위 |
|---|---|
| `feat/redesign-foundation` | 0단계 + 2단계 F |
| `feat/redesign-auth` | 로그인·회원가입 |
| `feat/redesign-home` | 홈 2종 |
| `feat/redesign-store` | 스토어 목록·상세 |
| `feat/redesign-chat` | 모닝·나이트 채팅 |
| `feat/emotion-analysis` | 2단계 A |
| `feat/session-query-filters` | 2단계 B·C |
| `feat/diary-advice-tags` | 2단계 D |
| `feat/chat-info-card` | 2단계 E |
| `feat/redesign-dashboard` | 3단계 대시보드 |
| `feat/redesign-detail-tabs` | 3단계 상세 |

`main` 직접 머지는 하지 않는다.

## 검증

테스트 프레임워크가 없으므로 실행으로 확인한다.

- BE: `python -m py_compile`로 문법 확인 → 서버 기동 후 `curl`로 엔드포인트 확인. AI·DB 관련은 `load_dotenv()` 후 함수를 직접 부르는 일회성 스크립트
- FE: `flutter run`으로 실제 화면 확인. 각 PR의 완료 조건은 "해당 화면이 Figma와 같게 뜬다"

## 열린 항목

- 꿈 상세 `AI 감정 인사이트` 탭의 감정 전이 방향 (디자인 선행)
- 설정 화면 범위 (디자인 선행)
- 월별 칩을 달마다 호출할지 범위 파라미터를 둘지 (3단계 구현 시)
