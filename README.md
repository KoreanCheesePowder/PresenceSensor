# C.P Tuya Presence Sensor v1.3.2 - Auto Installer

## 설치 (명령어 입력 불필요)

1. ZIP 파일을 새 폴더에 압축 해제합니다.
2. **`SETUP-AND-INSTALL.cmd`를 더블클릭**합니다.
3. 배포, CheesePowder 채널 반영, 메인 허브 설치, 설치 확인을 자동 수행합니다.
4. 설치 결과는 `INSTALL-RESULT.txt` 파일에 자동 저장됩니다.

SmartThings CLI가 설치되어 있고 인증되어 있어야 합니다.
센서 5대, 드라이버 ID, 기존 루틴, 설정, Capability는 삭제하거나 재등록하지 않습니다.
기존 Capability와 Presentation은 다시 생성하지 않습니다.

## 변경 범위

이번 AUTO ZIP은 **v1.3.2와 센서 Lua 코드/프로필이 완전히 동일**합니다.
Windows CMD 배포 스크립트만 개선했습니다.
기존 ZG-204ZX 3대와 TYPE6 2대 지원을 유지합니다.

## 설치 결과 판정

- 성공: 허브 설치 목록에서 기존 드라이버 ID가 확인됩니다.
- 경고: 설치는 확인됐지만 센서 버전 정보는 아직 갱신되지 않았습니다.
- 실패: 설치 로그에 오류 출력 및 비정상 종료 코드를 남깁니다.

제품 호환성 및 실제 Zigbee 통신은 허브에서 별도 검증해야 합니다.
