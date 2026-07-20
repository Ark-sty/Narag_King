# 나락킹 Prototype

Godot 4 프로젝트용 2D 낙하 액션 프로토타입입니다.

## 조작

- `A`, `D`: 좌우 이동 및 낙하 중 좌우 보정
- `J`: 낙하 중 장애물 옆면 근처에서 잡기
- 잡은 상태에서 `WASD`: 다음 이동 방향 조준
- 잡은 상태에서 `Space` 유지: 힘 충전
- `Space` 놓기: 조준 방향으로 재출발
- `R`: 처음 위치에서 재시작

잡기는 장애물 위면이 아니라 좌/우 옆면에서만 동작합니다. 바닥 위에서는 블럭 모서리 근처에서 잡기 키를 누르거나, 블럭 끝으로 걸어가 떨어지기 시작할 때 자동으로 옆면을 잡습니다.

## 구현 위치

- 시작 씬: `scenes/Main.tscn`
- 게임 로직/맵 생성: `scripts/Game.gd`

맵은 `Game.gd`의 `_build_world()`에서 5개 세로 구간으로 생성됩니다. 낙하 데미지는 `SAFE_FALL_DISTANCE`, `DAMAGE_STEP_DISTANCE`, 잡기 거리는 `GRAB_SIDE_DISTANCE`, `GRAB_EDGE_DISTANCE`, `AUTO_GRAB_EDGE_DISTANCE`, 중력/속도/충전값은 파일 상단 상수로 조정할 수 있습니다.
