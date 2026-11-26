@tool
class_name CatEase
extends RefCounted
## Unity TMPEffects Easing(DOTween 호환 31종)을 이식한 이징 함수 모음.
## 입력 t는 클램프하지 않으며, Back/Elastic 등은 [0,1] 밖의 값을 낼 수 있다.

# 정수값은 Unity EaseType과 같다(1부터 시작).
enum Type {
	LINEAR = 1, IN_SINE, OUT_SINE, IN_OUT_SINE,
	IN_QUAD, OUT_QUAD, IN_OUT_QUAD,
	IN_CUBIC, OUT_CUBIC, IN_OUT_CUBIC,
	IN_QUART, OUT_QUART, IN_OUT_QUART,
	IN_QUINT, OUT_QUINT, IN_OUT_QUINT,
	IN_EXPO, OUT_EXPO, IN_OUT_EXPO,
	IN_CIRC, OUT_CIRC, IN_OUT_CIRC,
	IN_ELASTIC, OUT_ELASTIC, IN_OUT_ELASTIC,
	IN_BACK, OUT_BACK, IN_OUT_BACK,
	IN_BOUNCE, OUT_BOUNCE, IN_OUT_BOUNCE,
}

const _BACK_S := 1.70158
const _BACK_S_INOUT := 1.70158 * 1.525
const _ELASTIC_PERIOD := 0.3
const _ELASTIC_PERIOD_INOUT := 0.45
const _ELASTIC_S := 0.3 * 0.25
const _ELASTIC_S_INOUT := 0.45 * 0.25
const _BOUNCE_N1 := 7.5625
const _BOUNCE_D1 := 2.75


## 이징 값. 알 수 없는 type은 LINEAR로 취급한다.
static func evaluate(type: int, t: float) -> float:
	match type:
		Type.IN_SINE: return 1.0 - cos(t * PI * 0.5)
		Type.OUT_SINE: return sin(t * PI * 0.5)
		Type.IN_OUT_SINE: return -0.5 * (cos(PI * t) - 1.0)
		Type.IN_QUAD: return t * t
		Type.OUT_QUAD: return t * (2.0 - t)
		Type.IN_OUT_QUAD: return 2.0 * t * t if t < 0.5 else -1.0 + (4.0 - 2.0 * t) * t
		Type.IN_CUBIC: return t * t * t
		Type.OUT_CUBIC:
			var u := t - 1.0
			return u * u * u + 1.0
		Type.IN_OUT_CUBIC:
			if t < 0.5:
				return 4.0 * t * t * t
			var u := 2.0 * t - 2.0
			return 0.5 * u * u * u + 1.0
		Type.IN_QUART: return t * t * t * t
		Type.OUT_QUART:
			var u := t - 1.0
			return 1.0 - u * u * u * u
		Type.IN_OUT_QUART:
			if t < 0.5:
				return 8.0 * t * t * t * t
			var u := t - 1.0
			return 1.0 - 8.0 * u * u * u * u
		Type.IN_QUINT: return t * t * t * t * t
		Type.OUT_QUINT:
			var u := t - 1.0
			return u * u * u * u * u + 1.0
		Type.IN_OUT_QUINT:
			if t < 0.5:
				return 16.0 * t * t * t * t * t
			var u := 2.0 * t - 2.0
			return 0.5 * u * u * u * u * u + 1.0
		Type.IN_EXPO: return 0.0 if t <= 0.0 else pow(2.0, 10.0 * (t - 1.0))
		Type.OUT_EXPO: return 1.0 if t >= 1.0 else 1.0 - pow(2.0, -10.0 * t)
		Type.IN_OUT_EXPO:
			if t <= 0.0:
				return 0.0
			if t >= 1.0:
				return 1.0
			if t < 0.5:
				return 0.5 * pow(2.0, 10.0 * (2.0 * t - 1.0))
			return 0.5 * (2.0 - pow(2.0, -10.0 * (2.0 * t - 1.0)))
		Type.IN_CIRC: return 1.0 - sqrt(1.0 - t * t)
		Type.OUT_CIRC:
			var u := t - 1.0
			return sqrt(1.0 - u * u)
		Type.IN_OUT_CIRC:
			if t < 0.5:
				var u := 2.0 * t
				return -0.5 * (sqrt(1.0 - u * u) - 1.0)
			var u2 := 2.0 * t - 2.0
			return 0.5 * (sqrt(1.0 - u2 * u2) + 1.0)
		Type.IN_ELASTIC:
			if t <= 0.0:
				return 0.0
			if t >= 1.0:
				return 1.0
			return -(pow(2.0, 10.0 * (t - 1.0)) * sin((t - 1.0 - _ELASTIC_S) * TAU / _ELASTIC_PERIOD))
		Type.OUT_ELASTIC:
			if t <= 0.0:
				return 0.0
			if t >= 1.0:
				return 1.0
			return pow(2.0, -10.0 * t) * sin((t - _ELASTIC_S) * TAU / _ELASTIC_PERIOD) + 1.0
		Type.IN_OUT_ELASTIC:
			if t <= 0.0:
				return 0.0
			if t >= 1.0:
				return 1.0
			var s := 2.0 * t
			var w := sin((s - 1.0 - _ELASTIC_S_INOUT) * TAU / _ELASTIC_PERIOD_INOUT)
			if s < 1.0:
				return -0.5 * (pow(2.0, 10.0 * (s - 1.0)) * w)
			return pow(2.0, -10.0 * (s - 1.0)) * w * 0.5 + 1.0
		Type.IN_BACK: return t * t * ((_BACK_S + 1.0) * t - _BACK_S)
		Type.OUT_BACK:
			var u := t - 1.0
			return u * u * ((_BACK_S + 1.0) * u + _BACK_S) + 1.0
		Type.IN_OUT_BACK:
			var s := 2.0 * t
			if s < 1.0:
				return 0.5 * (s * s * ((_BACK_S_INOUT + 1.0) * s - _BACK_S_INOUT))
			var u := s - 2.0
			return 0.5 * (u * u * ((_BACK_S_INOUT + 1.0) * u + _BACK_S_INOUT) + 2.0)
		Type.IN_BOUNCE: return 1.0 - _out_bounce(1.0 - t)
		Type.OUT_BOUNCE: return _out_bounce(t)
		Type.IN_OUT_BOUNCE:
			if t < 0.5:
				return (1.0 - _out_bounce(1.0 - 2.0 * t)) * 0.5
			return (1.0 + _out_bounce(2.0 * t - 1.0)) * 0.5
	return t


## curve가 있으면 Curve 샘플을, 없으면 이징 함수를 쓴다.
static func sample(type: int, curve: Curve, t: float) -> float:
	if curve != null:
		return curve.sample(t)
	return evaluate(type, t)


static func _out_bounce(t: float) -> float:
	if t < 1.0 / _BOUNCE_D1:
		return _BOUNCE_N1 * t * t
	if t < 2.0 / _BOUNCE_D1:
		var u := t - 1.5 / _BOUNCE_D1
		return _BOUNCE_N1 * u * u + 0.75
	if t < 2.5 / _BOUNCE_D1:
		var u := t - 2.25 / _BOUNCE_D1
		return _BOUNCE_N1 * u * u + 0.9375
	var u := t - 2.625 / _BOUNCE_D1
	return _BOUNCE_N1 * u * u + 0.984375
