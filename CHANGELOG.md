# Changelog

## v1.3.1 (2026-10-20)
- Replace brittle PowerShell JSON-based installer with direct Windows CMD invocation of official SmartThings `edge:drivers:package --install --channel --hub` command.
- Avoid native stdout UTF-8 mojibake and `ConvertFrom-Json` failures with Korean labels.
- Do not recreate or re-query previously registered capability/presentation.
- Preserve previous sensor logic, device identity, profiles, all capabilities and System Monitor adapters.

## v1.3.0 (2026-10-20)
- Fix installation failure when missing presentation is returned as HTTP 403 with API code 4040000.
- Create only the missing TYPE6 presentation, then verify before deploying to hub.
- Distinguish missing presentations from genuine permission errors; prevent re-registration.
- Keep v1.2.9 sensor implementation and existing HOBEIAN/TYPE6 profiles unchanged.

## v1.2.9 (2026-10-20)
- Skip TYPE6 capability creation; reuse confirmed `buildbook37604.type6communication`.
- Correct fixed ID in Lua, TYPE6 profile and capability presentation.
- Idempotent presentation registration using CLI 2.1.2 (without positional version).
- Fix System Monitor adapters for lowercase capability ID.
- Preserve original driver packageKey, sensors, settings and rules.

## v1.2.8 (2026-10-20)
- SmartThings CLI 2.x에서 capability presentation 명령에 버전 `1`을 잘못 전달하던 설치 스크립트 수정.
- CLI 1.x/2.x 명령 형식 분기 및 Capability ID 소문자 정규화/재사용.
- 기존 제작자 표시 및 TYPE6 통신 상태 독립 Capability 유지.
- 설치 실패 후 재실행 시 기존 Capability 재사용, 센서 삭제·재등록 불필요.

## v1.2.7 (2026-10-20)
- TYPE6 제작자 문자열에서 통신 정보 삭제. `치즈가루`만 표시.
- TYPE6 통신 상태를 전용 SmartThings Custom Capability로 분리.
- 사용자 계정 namespace의 Capability 생성 및 Presentation 등록을 설치 스크립트에 추가. 계정에 이미 등록되어 있으면 재사용.
- 상태 규격: `linkState`, `lastReceived`, `minutesWithoutRx`, `timeoutMinutes`.
- 마지막 통신 정보는 실제 Zigbee 수신에만 갱신, 클라우드에 최대 5분 단위 데이터 전송.
- 시스템 모니터 OAuth 장치 상태 수집 연동용 모듈과 테스트 추가.
- 기존 ZG-204ZX 프로필/기능 유지, TYPE6 v127 신규 프로필 사용.
- 기존 driver ID(packageKey) 유지, 삭제·재등록 불필요.

## v1.2.6 (2026-10-19)
- TYPE6에서 값이 없는 get_field를 tonumber으로 변환하던 오류 수정.
- TYPE6 초기화/설정 변경 모의 테스트 보강.

## v1.2.5 (2026-10-19)
- TYPE6 통신 watchdog 도입, 기본 60분 무수신 감시/감지값 초기화 옵션.
