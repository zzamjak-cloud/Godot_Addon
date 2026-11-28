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

### 변경(원본 대비)
- 깊이를 투영 역행렬로 선형화해 직교 카메라에서도 포말·깊이 색이 동작.
- 카메라 추적 UV 보정에 반 크기 항을 더해 크기가 다른 근거리/먼 바다 이음매에서 무늬가 항상 이어짐.
