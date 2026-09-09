# Re-view 문서

번호는 카테고리 순서다. 10 단위로 띄워 뒀으니 나중에 카테고리를 끼워 넣을 자리가 있다.

| 폴더 | 무엇이 들어가나 |
|---|---|
| `00-overview/` | 제품이 뭔지, 시스템이 왜 이렇게 생겼는지 |
| `10-rules/` | 필수 규칙 — 어기면 안 되는 것 (커밋·브랜치·시크릿 취급) |
| `20-engineering/` | 개발자용 실무 문서 — 설치·실행·코드 컨벤션 |
| `30-design/` | 디자인 토큰, UI 규격 |
| `40-decisions/` | ADR — "왜 그렇게 정했나" 기록 |
| `50-specs/` | 기능 설계 문서 (구현 전) |
| `60-plans/` | 구현 계획 (설계 → 작업 단위 분해) |

## 현재 문서

**00-overview**
- [02-architecture.md](00-overview/02-architecture.md) — 4계층 구조, 기술 선택 이유

**20-engineering**
- [01-onboarding.md](20-engineering/01-onboarding.md) — 설치·실행·진행 이력
- [03-frontend.md](20-engineering/03-frontend.md) — FE 코드 작성 패턴

**30-design**
- [01-design-tokens.md](30-design/01-design-tokens.md) — 색·타이포 실측값

**40-decisions**
- [0001-neon-to-supabase.md](40-decisions/0001-neon-to-supabase.md) — DB 이관, 크론 사고 전말

**50-specs**
- [2026-09-09-promo-web-page-design.md](50-specs/2026-09-09-promo-web-page-design.md) — 홍보 웹페이지(날씨 테마 + 해몽 데모 + 꿈 랭킹)
- 그 외는 날짜-주제 형식으로 쌓인다.

**60-plans**
- 날짜-주제 형식으로 쌓인다. 예: `2026-07-20-favorite-delete-api.md`

## 규칙

- **결정은 `40-decisions/`에 한 번만 쓴다.** 다른 문서는 링크만 건다.
  같은 결정을 README·CLAUDE.md·architecture.md에 복사해 두면 서로 다르게 썩는다
  (실제로 그랬다 — ADR 0001 참고).
- 설치·실행 명령어의 원본은 루트 [README.md](../README.md)다. 여기서는 중복하지 않는다.
- `10-rules/`는 아직 비어 있다. 커밋 컨벤션·브랜치 전략·시크릿 취급 규칙이 들어갈 자리다.
