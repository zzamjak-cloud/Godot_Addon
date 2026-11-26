# CAT Godot Addons

Unity용으로 만든 CAT 패키지들을 Godot 4.7+ 애드온으로 옮겨 모아 둔 레포입니다. 레포 자체가 개발·데모용 Godot 프로젝트이며, 실제 배포 단위는 `addons/` 아래 폴더 하나하나입니다.

## 애드온 목록

| 애드온 | 버전 | 설명 | 원본 (Unity) |
|---|---|---|---|
| [cat_core](addons/cat_core/README.md) | 1.0.0 | 공용 코드(이징 31종) | — |
| [cat_text_fx](addons/cat_text_fx/README.md) · [기능 소개 페이지](https://zzamjak-cloud.github.io/Godot_Addon/cat_text_fx/) | 1.0.0 | 텍스트 외곽선·글로우·곡선·글자 애니메이션·마스크 흐름 | [TMPEffect](https://github.com/zzamjak-cloud/TMPEffect) |

## 설치

필요한 애드온 폴더(+ `cat_core`)만 프로젝트의 `addons/`에 넣으면 됩니다.

**방법 1 — 복사**: 이 레포의 `addons/cat_core`와 `addons/cat_<name>`을 대상 프로젝트의 `addons/`에 복사합니다.

**방법 2 — [GodotEnv](https://github.com/chickensoft-games/GodotEnv)** (버전 고정·업데이트가 쉬움): 대상 프로젝트에 `addons.json`을 만들고 `godotenv addons install`을 실행합니다.

```json
{
  "path": "addons",
  "addons": {
    "cat_core":    { "url": "https://github.com/zzamjak-cloud/Godot_Addon.git", "checkout": "cat_core/v1.0.0", "subfolder": "addons/cat_core" },
    "cat_text_fx": { "url": "https://github.com/zzamjak-cloud/Godot_Addon.git", "checkout": "cat_text_fx/v1.0.0", "subfolder": "addons/cat_text_fx" }
  }
}
```

태그는 `<애드온>/vX.Y.Z` 형식이고 애드온마다 따로 붙습니다.

## 개발

- 애드온 추가·변환 규칙: [CLAUDE.md](CLAUDE.md)
- 데모: `demo/<addon>/`, 테스트: `tests/<addon>/`, 샘플 영상: `docs/media/<addon>/` (`tools/record_showcase.sh`로 생성)

## 라이선스

MIT — [LICENSE](LICENSE)
