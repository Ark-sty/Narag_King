# 나락킹 Prototype

Godot 4 프로젝트용 2D 낙하 액션 프로토타입입니다.

## 조작

- `A`, `D`: 좌우 이동 및 낙하 중 좌우 보정
- `J`: 낙하 중 장애물 옆면 근처에서 잡기
- 잡은 상태에서 `WASD`: 다음 이동 방향 조준
- 잡은 상태에서 `Space` 유지: 힘 충전
- `Space` 놓기: 조준 방향으로 재출발
- `R`: 처음 위치에서 재시작
- `F10`: 키 설정 메뉴 열기/닫기

잡기는 장애물 위면이 아니라 좌/우 옆면에서만 동작합니다. 바닥 위에서는 블럭 모서리 근처에서 잡기 키를 누르거나, 블럭 끝으로 걸어가 떨어지기 시작할 때 자동으로 옆면을 잡습니다.

키 설정 메뉴에서는 각 동작을 키보드 키 또는 마우스 버튼으로 변경하거나 기본값으로 복원할 수 있습니다. 변경한 입력은 사용자 데이터 폴더의 `input_bindings.cfg`에 저장되며 다음 실행 때 자동으로 불러옵니다. 이미 사용 중인 입력을 지정하면 두 동작의 입력이 서로 교환됩니다.

## 구현 위치

- 시작 씬: `scenes/Main.tscn`
- 게임 로직/맵 생성: `scripts/Game.gd`
- 충돌 속도 피해 계산: `scripts/ImpactDamage.gd`
- 입력 설정 저장/복원: `scripts/InputBindings.gd`
- 키 설정 UI: `scripts/ControlsMenu.gd`

맵은 `Game.gd`의 `_build_world()`에서 5개 세로 구간으로 생성됩니다. 충격 피해는 `ImpactDamage.gd`의 `SAFE_IMPACT_SPEED`, `LETHAL_IMPACT_SPEED`, 피해 곡선 상수로 조정합니다. 잡기 거리 `GRAB_SIDE_DISTANCE`, `GRAB_EDGE_DISTANCE`, `AUTO_GRAB_EDGE_DISTANCE`와 중력/속도/충전값은 `Game.gd` 파일 상단 상수로 조정할 수 있습니다.
