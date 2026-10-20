# TYPE6 - 치즈가루 시스템 모니터 연동 사양 (v1.3.1)

## 목적
- `buildbook37604.driverInformation.author` = `치즈가루`만 유지.
- TYPE6 통신 상태는 별도의 SmartThings custom capability의 속성으로 게시.
- SmartThings 공식 `health` ONLINE/OFFLINE과 별도: 무수신 판정은 '통신 끊김 의심', 즉 '주의(caution)'에 대응.
- 정상 상태 -> 의심 상태, 의심 -> 정상 상태의 변화에만 장애/복구 이벤트 기록(중복 방지).

## 데이터 확인
- 설치 스크립트 완료 뒤 `docs/TYPE6-CAPABILITY-ID.txt`에서 실제 capabilityId 확인.
- 응답: `GET https://api.smartthings.com/v1/devices/<deviceId>/status` (기존 OAuth r:devices)
- 위치: `components.main["buildbook37604.type6communication"]`
- 속성:
  - `linkState.value` = `checking` / `normal` / `suspect`
  - `minutesWithoutRx.value` = 수신 없음 시간 (5분 단위 내림)
  - `lastReceived.value` = UTC ISO 8601 / '없음'
  - `timeoutMinutes.value` = 사용자 판정 기준 (분)

## 시스템 모니터 표시/알림 권장
- 공식 health=OFFLINE -> `offline`(기존 시스템 모니터 장애 처리 우선)
- 공식 health=ONLINE + linkState=suspect -> `caution`, 'TYPE6 통신 끊김 의심'
- linkState=normal + 공식 health=ONLINE -> `online`, '통신 정상'
- linkState=checking -> '통신 확인 중', 장애 알림 발행하지 않음
- `monitor/type6_monitor_adapter.py`(Python) 또는 `monitor/type6_monitor_adapter.js`(JavaScript)를 기존 수집 루틴에 연결.
- 모니터의 기존 SmartThings API 조회·캐시·장애 기록에 위 결과를 합쳐야 웹 화면과 알림이 변경됨.
- 신규 webhook, TCP 포트, NAS URL 또는 추가 토큰은 필요하지 않음.

## 주의
- 이 Edge 드라이버 ZIP만 설치해도 **기존 시스템 모니터 프로그램이 자동 수정되지는 않음**.
- 운영용 시스템 모니터 ZIP을 확보해야 서버/웹 UI/장애기록/HA 알림 파이프라인까지 실제로 연결 가능.
- Zigbee 배터리 센서의 절전으로 인해 60분 무수신이 오판일 수 있음. `type6CommTimeout` 조정 가능.

## v1.3.1 capability ID and retry behavior
- The already-created capability ID is `buildbook37604.type6communication` (lowercase).
- The installer never sends `capabilities:create` again. It creates the presentation only for HTTP 403 with internal code `4040000` and an explicit missing-presentation message.
- Python and JS adapters accept both mixed-case and lowercase capability IDs.
- The production System Monitor app is not modified by this ZIP.
