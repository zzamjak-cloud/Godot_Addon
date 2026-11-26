# CAT Core

CAT 애드온들이 함께 쓰는 공용 코드. 다른 `cat_*` 애드온은 이 폴더에만 의존할 수 있고, 이 폴더는 어떤 애드온에도 의존하지 않는다.

## 설치

`addons/cat_core` 폴더를 프로젝트의 `addons/`에 복사한다. 플러그인을 켜지 않아도 `class_name`은 등록된다.

## CatEase

Unity TMPEffects `Easing`(DOTween 호환 31종)을 GDScript로 옮긴 정적 이징 함수.

```gdscript
var v := CatEase.evaluate(CatEase.Type.OUT_BACK, 0.5)
var w := CatEase.sample(CatEase.Type.LINEAR, my_curve, 0.5)  # curve가 있으면 Curve 우선
```

| 멤버 | 설명 |
|---|---|
| `enum Type` | `LINEAR = 1` … `IN_OUT_BOUNCE = 31`. 정수값이 Unity `EaseType`과 같다 |
| `evaluate(type, t)` | 이징 값. t는 클램프하지 않아 Back/Elastic은 [0,1] 밖의 값을 낸다. 알 수 없는 type은 LINEAR |
| `sample(type, curve, t)` | `curve != null`이면 `curve.sample(t)`, 아니면 `evaluate` |

## Unity 원본과의 대응

| Unity | Godot |
|---|---|
| `Easing.Evaluate(EaseType, t)` | `CatEase.evaluate(type, t)` |
| `EaseValue` / `AnimationCurveValue` | `CatEase.Type` enum + 선택적 `Curve` 리소스 |

## 원본과의 차이

- `Curve`는 Unity `AnimationCurve`와 보간 방식·범위 처리가 달라, 커브를 쓰는 값은 원본과 정확히 같지 않다. 오버슈트가 필요한 커브는 `Curve.min_value`/`max_value`를 넓혀 쓴다.
