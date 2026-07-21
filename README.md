# 나락킹 Prototype

Godot 4 프로젝트용 2D 낙하 액션 프로토타입입니다.

## 조작

- `A`, `D`: 좌우 이동 및 낙하 중 좌우 보정
- `J`: 잡을 수 있는 지점 근처에서 타이밍을 맞춰 잡기
- 잡은 상태에서 `WASD`: 다음 이동 방향 조준
- 잡은 상태에서 `Space` 유지: 힘 충전
- `Space` 놓기: 조준 방향으로 재출발
- `R`: 처음 위치에서 재시작
- `F10`: 키 설정 메뉴 열기/닫기

잡기 입력은 0.12초 동안 보관되며, 그동안 장애물의 좌/우 옆면이나 경사면 손잡이에 가까워지면 잡습니다. 평평한 발판 위에서 잡기 키를 누르고 있으면 발판에서 밀려날 때 방금 밟던 발판의 가장자리만 자동으로 잡습니다. 이 홀드 입력으로 공중의 다른 물체를 연속해서 잡지는 않습니다. 경사면의 수직 손잡이는 물리 충돌 없이 선분과의 거리로 잡기를 판정하며, 성공하면 현재 위치에서 속도만 멈추고 기존 잡기 상태로 전환합니다.

키 설정 메뉴에서는 각 동작을 키보드 키 또는 마우스 버튼으로 변경하거나 기본값으로 복원할 수 있습니다. 변경한 입력은 사용자 데이터 폴더의 `input_bindings.cfg`에 저장되며 다음 실행 때 자동으로 불러옵니다. 이미 사용 중인 입력을 지정하면 두 동작의 입력이 서로 교환됩니다.

## 구현 위치

- 시작 씬: `scenes/Main.tscn`
- 메인 게임 루프: `scripts/Game.gd`
- 편집 가능한 레벨 씬: `scenes/level/Level01.tscn`
- 레벨 배경/경계 생성 및 잡기 데이터 수집: `scripts/level/LevelGeometry.gd`
- 발판/기둥 노드: `scripts/level/PlatformBlock.gd`
- 대각선 완충면 노드: `scripts/level/DiagonalRoute.gd`
- 플레이어 생성/표시: `scripts/player/PlayerCharacter.gd`
- 잡기 판정/입력 버퍼/모서리 보정: `scripts/player/GrabSystem.gd`
- HUD: `scripts/ui/GameHud.gd`
- 충돌 속도 피해 계산: `scripts/ImpactDamage.gd`
- 대각선 경사면 감속 계산: `scripts/DiagonalSlideResponse.gd`
- 입력 설정 저장/복원: `scripts/InputBindings.gd`
- 키 설정 UI: `scripts/ControlsMenu.gd`

맵 배치는 `scenes/level/Level01.tscn`에서 조정합니다. `SafePlatform*`, `GripPost*`, `DiagonalSurface*`, `GrabPoint*` 노드를 Godot 에디터에서 직접 옮기고 Inspector에서 값을 바꿀 수 있습니다.

`SafePlatform*`, `GripPost*`는 `grab_sides`를 `Both`, `Left Only`, `Right Only` 중 하나로 설정해 잡을 수 있는 면을 고릅니다. 여기서 Left/Right는 오브젝트 자체의 왼쪽/오른쪽 면입니다. 잡을 수 있는 면은 노란색 세로 하이라이트로 표시됩니다. `GrabPoint*`는 충돌 없이 통과되는 작은 원형 손잡이이며, `radius`와 `grab_reach`로 크기와 잡기 허용 범위를 조정합니다. 좌우 맵 끝(`LeftWall`/`RightWall`)은 충돌체가 있어 플레이어를 막지만 마찰이 0으로 설정되어 있어 벽에 붙잡혀 멈추지 않습니다.

충격 피해는 `ImpactDamage.gd`의 `SAFE_IMPACT_SPEED`, `LETHAL_IMPACT_SPEED`, 피해 곡선 상수로 조정합니다. 잡기 거리와 발판 이탈 보정은 `GrabSystem.gd`, 입력 버퍼는 `Game.gd`의 `GRAB_INPUT_BUFFER_MSEC`에서 조정합니다.

## 개발 테스트 씬

- `scenes/dev/DiagonalSlideTest.tscn`: 피해를 감수하고 감속하는 대각선 완충면의 자동 시연 씬입니다. 저속·중속·고속 낙하가 자동 반복되며 `Space`로 다음 조건, `R`로 현재 조건을 다시 실행할 수 있습니다.
