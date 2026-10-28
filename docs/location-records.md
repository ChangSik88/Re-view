# Location-based daily reports

Home → 위치 → map pin/place thumbnail → report list → existing AnalysisPage.
Only completed Night reports with an explicit place appear; Morning dream places are never geocoded.
Add/edit/remove a place from the daily report or use 기록에 장소 추가 on the map.
The user chooses a map point and a name. Current location is an optional foreground-only suggestion, requested only after pressing 현재 위치로 이동; denial/service-off retains manual selection.
Existing reports stay unlocated until the user adds a place. No gallery permission or background tracking.

## Storage and deployment

PATCH /chatting/session/{room_id}/location uses the existing JWT dependency and checks ownership on both read and write. Payload: place_name (max 100), latitude (-90..90), longitude (-180..180); all null removes the place. Partial/invalid/non-finite coordinates are rejected. Only completed Night reports can be updated.
GET session/all and session/single return these nullable fields. Location changes do not rewrite the diary date. Repeated visits with the same name and rounded coordinates (4 decimals) are grouped; differently named places remain separate.

Deploy BE with migration 20261028000000_record_location and regenerate Prisma before releasing the new app. Existing Render buildCommand already runs prisma migrate deploy and prisma generate. No production database was changed as part of local implementation. An old backend cannot save places; the app retains the editor and shows a retryable error.

## Map

flutter_map renders live OpenStreetMap standard tiles instead of the illustrative map in Figma. Record thumbnails are supplied by the existing record images. © OpenStreetMap attribution links to its copyright page; identified User-Agent, no bulk downloads or offline prefetch. Provider terms: https://operations.osmfoundation.org/policies/tiles/. Tile errors show a retry control. A commercial/high-volume deployment should provision a suitable tile provider.

Android foreground coarse/fine permissions and iOS NSLocationWhenInUseUsageDescription are declared. No map API secret is needed. GPS availability and actual permission prompts must also be checked on physical Android/iOS devices.

## Verification

FE/test/location_flow_test.dart covers grouping/exclusion, serialization, 320/393-wide map → report navigation, denied GPS/manual selection, and incomplete input. BE/tests/test_record_location.py covers schema validation, ownership, Night-only writes and deletion. Database calls are mocked in backend unit tests; apply the migration in a staging database before production rollout.
