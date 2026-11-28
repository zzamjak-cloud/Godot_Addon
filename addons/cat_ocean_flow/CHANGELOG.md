# Changelog

형식: [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/), 버전: [SemVer](https://semver.org/lang/ko/).

## [1.0.0] - 2026-11-28

### 추가
- Unity URP OceanFlow를 Godot 4.7로 이식.
- `CatOceanFlowSurface`: 바다·호수 그리드(구멍·카메라 추적·시선 교차점 추적·월드 고정 UV·파도 가장자리 페이드·먼 바다 동기화).
- `CatOceanFlowRiver`: Curve3D 경로 리본(호 길이 등간격 재샘플·폭 곡선·닫힌 물길·다음 강 사슬 동기화·강 전용 파동 기본값), 편집용 자식 `Path3D`.
- `CatFlowChannel`: Loop/PingPong UV 흐름 리소스(`CatEase` 31종 + Custom 곡선).
- 셰이더 `cat_ocean_flow.gdshaderinc`: 깊이 색·접경 포말·셀 거품·노이즈 난류·Gerstner 파도·셀 톤 하이라이트. 기능 조합별 생성 셰이더 캐시.
- 도구 메뉴 "바다 세트 만들기", "강 세트 만들기".
- 랜덤성(텍스처 페치·셰이더 변형 추가 없음, 정점 셰이더의 저주파 함수): 파도 위상 지터 `wave_phase_jitter`, 너울 묶음 `swell_variation`·`swell_scale`, 셀 거품·하이라이트 얼룩 `surface_breakup`·`surface_breakup_scale`. 먼 바다·다음 강 동기화 대상이며 강은 더 작은 크기를 기본값으로 쓴다.

### 변경(원본 대비)
- 깊이를 투영 역행렬로 선형화해 직교 카메라에서도 포말·깊이 색이 동작.
- 잔물결을 `sin(x)·cos(z)` 격자 대신 서로 다른 방향·주파수비의 방향파 3개 합으로 계산(최대 진폭은 그대로 `ripple.x`). 새 랜덤성 값을 0으로 두어도 잔물결 모양은 원본과 다르다.
- 카메라 추적 UV 보정에 반 크기 항을 더해 크기가 다른 근거리/먼 바다 이음매에서 무늬가 항상 이어짐.
