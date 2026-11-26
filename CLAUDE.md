# CAT Godot Addons — 애드온 생성·관리 규칙

이 레포는 Unity용으로 만들었던 CAT 패키지들을 Godot 4.7+ 애드온으로 옮겨 모아 두는 **통합 레포**이자 개발·데모용 Godot 프로젝트다.
새 애드온을 추가하거나 Unity 패키지를 변환할 때는 아래 규칙을 따른다.

## 1. 레포 구조

```
Godot_Addon/
├─ project.godot            ← 개발·데모 프로젝트 (배포 대상 아님)
├─ demo/<addon_id>/         ← 애드온별 예제 씬 (배포 대상 아님)
├─ tests/<addon_id>/        ← 헤드리스 검증 스크립트 (배포 대상 아님)
└─ addons/
   ├─ cat_core/             ← 공용 코드(이징 등). 다른 애드온은 여기에만 의존 가능
   └─ cat_<name>/           ← 배포 단위. 이 폴더 하나만 복사해도 동작해야 한다(cat_core 제외)
```

## 2. 이름 규칙

| 대상 | 규칙 | 예 |
|---|---|---|
| 애드온 폴더(=addon_id) | `cat_` + snake_case | `addons/cat_text_fx` |
| `class_name` | `Cat` + PascalCase. 전역 이름 충돌 방지를 위해 접두사 필수 | `CatTextFX`, `CatEase` |
| 파일명 | snake_case.gd, 클래스와 1:1 | `cat_text_fx.gd` |
| 시그널·메서드·변수 | snake_case | `play()`, `appear_finished` |
| 리소스(프리셋) | `Cat<Name>Preset` 클래스 + `.tres` | `CatTextAnimationPreset` |
| 태그 | `<addon_id>/vX.Y.Z` (SemVer) | `cat_text_fx/v1.0.0` |

- 같은 `class_name`이 두 곳에 있으면 Godot이 오류를 내므로 공용 코드는 반드시 `cat_core`에 한 번만 둔다. 애드온끼리 코드를 복사하지 않는다.
- 의존 방향은 `cat_<name>` → `cat_core` 한 방향만 허용한다. `cat_core`는 어떤 애드온에도 의존하지 않는다.
- `cat_core`에 의존하는 애드온은 README 맨 위에 `필요: cat_core >= X.Y.Z`를 적고, 그 버전 이상의 `cat_core` 태그와 함께 설치하도록 안내한다.

## 3. 애드온 폴더 필수 파일

```
addons/cat_<name>/
├─ plugin.cfg        ← name="CAT <Name>", author="zzamjak", version="X.Y.Z", script="plugin.gd"
├─ plugin.gd         ← @tool EditorPlugin (에디터 전용 등록만. 런타임 로직 금지)
├─ README.md         ← 설치·빠른 시작·노드/속성 표·Unity 원본과의 대응표
├─ CHANGELOG.md      ← Keep a Changelog 형식
├─ LICENSE           ← MIT (루트 LICENSE와 동일)
├─ icons/            ← 노드 아이콘(16px SVG, 선택)
└─ *.gd / shaders/ / presets/
```

- 런타임 노드는 `class_name`으로 등록한다(플러그인을 켜지 않아도 동작해야 한다). `plugin.gd`는 인스펙터 플러그인·메뉴 등 에디터 기능만 담당한다.
- `plugin.cfg`의 `version`, `CHANGELOG.md`, 태그 버전을 항상 같이 올린다.

## 4. 코드 규칙 (GDScript)

- 언어는 **GDScript**(C# 금지: 웹 내보내기 불가, 사용하는 프로젝트마다 .NET 빌드 필요).
- 정적 타입을 쓴다(`var x: float`, `func f() -> void`). 인스펙터에서 바로 확인할 노드는 `@tool`.
- 설명·주석·문서는 한국어, 식별자는 영어. 주석은 꼭 필요한 이유(WHY)만 쓴다.
- `@export_group`으로 인스펙터를 단계별로 묶는다(Unity 인스펙터 섹션과 같은 구성).
- 모바일을 기준으로 삼는다: `_process`는 필요할 때만 켜고(`set_process`), 매 프레임 배열·딕셔너리를 새로 만들지 않으며, 값이 바뀔 때만 다시 계산한다(dirty 플래그).
- 공개 API는 Unity 원본의 메서드 이름을 snake_case로 그대로 옮겨서 사용법이 대응되게 한다(`Play()` → `play()`, `SetOutline()` → `set_outline()`).

## 5. Unity 패키지 → Godot 애드온 변환 절차

1. 원본 UPM 패키지의 README·CHANGELOG·Script를 읽고 컴포넌트별 기능 명세(속성·기본값·수식)를 먼저 정리한다.
2. 대응 표를 만든다: Unity 개념 → Godot 개념.
   - MonoBehaviour 컴포넌트 → 노드(대상 노드의 자식으로 붙이거나 대상 노드 자체를 대체)
   - ScriptableObject 프리셋 → `Resource` 상속 클래스 + `.tres`
   - Material/Shader 속성 → `ShaderMaterial` 또는 `draw_*` 호출
   - UnityEvent/C# event → `signal`
   - Coroutine/DOTween → `_process` 또는 `Tween`, 이징은 `cat_core`의 `CatEase`
   - AnimationCurve → `Curve` 리소스
3. Godot에 대응물이 없는 기능은 README의 "원본과의 차이" 절에 적는다(조용히 빼지 않는다).
4. `demo/<addon_id>/`에 기능별 예제 씬을, `tests/<addon_id>/`에 헤드리스 검증 스크립트를 만든다.
5. **기능별 샘플 영상**을 만든다(상세 기능 설명서에 쓰는 자료).
   - 씬: `demo/<addon_id>/showcase/NN_<feature>.tscn` — 1280x720, 상단 기능명 캡션, 하단 핵심 속성 값, 5~8초 안에 기능이 다 보이게 스스로 연출하는 스크립트.
   - 녹화: `tools/record_showcase.sh [씬이름...]` (현재 cat_text_fx 전용. 새 애드온은 같은 구조로 `tools/record_<addon_id>.sh`를 만들거나 이 스크립트에 애드온 인자를 추가) — Godot Movie Maker(`--write-movie`, `--fixed-fps 60`)로 녹화 후 ffmpeg로 변환. 레포 창 크기와 무관하게 1280x720 임시 프로젝트에서 녹화하며, 렌더 멈춤을 막으려고 결과가 두 번 같을 때까지 재녹화한다.
   - 결과: `docs/media/<addon_id>/NN_<feature>.mp4`(H.264, 2MB 이하)와 README용 `.gif`(가로 640, 3MB 이하). 애드온 README의 기능 절마다 GIF를 넣는다.
   - 기능을 고치면 해당 영상을 다시 녹화한다. 녹화 후 프레임 몇 장을 PNG로 뽑아 직접 확인한다.

## 6. 검증

```bash
GODOT=/Users/woody/dev/Godo_Project/Godot_v4.7.2-stable_macos.universal/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path . --import 2>&1 | grep -E "SCRIPT ERROR|Parse Error|ERROR:"   # 아무것도 안 나와야 함 (class_name 등록도 이 단계에서 됨)
$GODOT --headless --path . -s tests/<addon_id>/test_<name>.gd                         # 종료 코드 0이어야 함
$GODOT --path . -s tests/cat_text_fx/capture.gd -- <scene.tscn> <out.png>              # 시각 효과는 창 모드 캡처로 확인
```

- Godot 헤드리스는 스크립트 오류가 있어도 종료 코드 0으로 끝나는 경우가 많다. **출력에서 `SCRIPT ERROR|Parse Error|ERROR:`를 반드시 grep**하고, 테스트 스크립트(`extends SceneTree`)는 실패 시 `quit(1)`을 호출한다.
- 새 클론·새 class_name 추가 후에는 `--import`를 먼저 1회 돌려야 `-s` 테스트에서 class_name이 해석된다.
- 헤드리스는 로직만 증명한다. 그리기 결과가 있는 기능은 데모 씬을 창 모드로 캡처해 PNG를 직접 확인한다.
- 파싱 오류 없음 + 테스트 종료 코드 0 + (그리기 기능이면) 캡처 확인일 때만 완료로 본다.

## 7. 배포·설치

- 개발은 이 레포 하나에서 하고, 다른 프로젝트에는 **애드온 폴더 단위로** 설치한다.
- 권장: [GodotEnv](https://github.com/chickensoft-games/GodotEnv)의 `addons.json`에서 `subfolder`로 필요한 애드온만 받는다.

```json
{
  "path": "addons",
  "addons": {
    "cat_core":    { "url": "https://github.com/zzamjak-cloud/Godot_Addon.git", "checkout": "cat_core/v1.0.0", "subfolder": "addons/cat_core" },
    "cat_text_fx": { "url": "https://github.com/zzamjak-cloud/Godot_Addon.git", "checkout": "cat_text_fx/v1.0.0", "subfolder": "addons/cat_text_fx" }
  }
}
```

- 도구 없이 쓸 때는 `addons/cat_core`와 필요한 `addons/cat_<name>` 폴더를 대상 프로젝트의 `addons/`에 복사한다.
- 새 애드온을 추가하면 루트 README의 애드온 목록 표에 한 줄을 추가한다.
