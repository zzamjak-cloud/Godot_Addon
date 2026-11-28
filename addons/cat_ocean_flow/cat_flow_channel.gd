@tool
class_name CatFlowChannel
extends Resource
## UV 레이어 하나의 흐름(Unity FlowChannel). 평가는 static 순수 함수 evaluate()로 한다.

enum Mode {
	LOOP,       ## 한 방향으로 무한히 흐른다
	PING_PONG,  ## 지정한 범위를 왕복한다 (YoYo)
}

## ease 값으로 쓰는 Custom. CatEase.Type(1~31)과 겹치지 않는다.
const EASE_CUSTOM := 32

const _EASE_HINT := "Linear:1,In Sine:2,Out Sine:3,In Out Sine:4,In Quad:5,Out Quad:6,In Out Quad:7,In Cubic:8,Out Cubic:9,In Out Cubic:10,In Quart:11,Out Quart:12,In Out Quart:13,In Quint:14,Out Quint:15,In Out Quint:16,In Expo:17,Out Expo:18,In Out Expo:19,In Circ:20,Out Circ:21,In Out Circ:22,In Elastic:23,Out Elastic:24,In Out Elastic:25,In Back:26,Out Back:27,In Out Back:28,In Bounce:29,Out Bounce:30,In Out Bounce:31,Custom:32"

## Loop: 한 방향 무한 흐름 / Ping Pong: 범위 왕복
@export var mode: Mode = Mode.LOOP:
	set(v):
		if mode == v:
			return
		mode = v
		emit_changed()
		notify_property_list_changed()
## UV 진행 방향. 평가 시 정규화되므로 길이는 무시된다
@export var direction: Vector2 = Vector2(1.0, 0.0):
	set(v):
		if direction == v:
			return
		direction = v
		emit_changed()
## Loop: 초당 UV 이동량 / Ping Pong: 1왕복에 걸리는 시간(초)
@export var speed: float = 0.05:
	set(v):
		if speed == v:
			return
		speed = v
		emit_changed()
## Ping Pong 왕복 폭 (UV 단위). Loop 에서는 무시된다
@export var range: float = 0.2:
	set(v):
		if range == v:
			return
		range = v
		emit_changed()
## 속도 곡선. Back/Elastic 계열은 범위를 넘는 오버슈트가 있다
@export_custom(PROPERTY_HINT_ENUM, _EASE_HINT) var ease: int = CatEase.Type.LINEAR:
	set(v):
		if ease == v:
			return
		ease = v
		emit_changed()
		notify_property_list_changed()
## ease 가 Custom 일 때 쓰는 곡선 (0~1 구간)
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "Curve", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_ALWAYS_DUPLICATE) var custom_curve: Curve:
	set(v):
		if custom_curve == v:
			return
		if custom_curve != null and custom_curve.changed.is_connected(emit_changed):
			custom_curve.changed.disconnect(emit_changed)
		custom_curve = v
		if custom_curve != null:
			custom_curve.changed.connect(emit_changed)
		emit_changed()
## 이 레이어의 UV 타일링
@export var tiling: Vector2 = Vector2.ONE:
	set(v):
		if tiling == v:
			return
		tiling = v
		emit_changed()


func _init() -> void:
	# 노드를 복제했을 때 두 노드가 같은 채널을 공유하지 않게 한다
	resource_local_to_scene = true


func _validate_property(property: Dictionary) -> void:
	match property.name:
		"range":
			if mode != Mode.PING_PONG:
				property.usage |= PROPERTY_USAGE_READ_ONLY
		"custom_curve":
			if ease != EASE_CUSTOM:
				property.usage |= PROPERTY_USAGE_READ_ONLY


## 기본값이 채워진 채널 (원본 FlowChannel.CreateDefault).
static func create_default(dir: Vector2, spd: float) -> CatFlowChannel:
	var ch := CatFlowChannel.new()
	ch.direction = dir
	ch.speed = spd
	return ch


## 다른 채널 값을 복사한다. 곡선은 복제해 두 채널이 같은 객체를 공유하지 않게 한다.
func copy_from(other: CatFlowChannel) -> void:
	if other == null or other == self:
		return
	mode = other.mode
	direction = other.direction
	speed = other.speed
	range = other.range
	ease = other.ease
	tiling = other.tiling
	if other.custom_curve == null:
		custom_curve = null
	elif custom_curve == null or not _curves_equal(custom_curve, other.custom_curve):
		custom_curve = other.custom_curve.duplicate()


## 지정한 시각의 UV 오프셋. speed 가 0 이하이거나 방향이 영벡터면 ZERO.
static func evaluate(channel: CatFlowChannel, time: float) -> Vector2:
	if channel == null or channel.speed <= 0.0:
		return Vector2.ZERO
	var dir := channel.direction
	var sqr_len := dir.length_squared()
	if sqr_len < 1e-8:
		return Vector2.ZERO
	dir /= sqrt(sqr_len)

	if channel.mode == Mode.LOOP:
		# 사이클 내부에만 이징을 적용해 경계에서 위치가 연속되도록 한다
		var cycles := time * channel.speed
		var whole := floorf(cycles)
		var eased := evaluate_ease(channel.ease, cycles - whole, channel.custom_curve)
		return dir * (whole + eased)

	# Ping Pong: 0 → 1 → 0 삼각파에 이징을 씌운다
	var cycle := fposmod(time / channel.speed, 1.0)
	var triangle := 1.0 - absf(1.0 - 2.0 * cycle)
	return dir * (evaluate_ease(channel.ease, triangle, channel.custom_curve) * channel.range)


## 원본 OceanFlowEase.Evaluate 와 같은 규칙: t 를 [0,1]로 자르고, Custom 은 곡선(없으면 선형).
static func evaluate_ease(ease_type: int, t: float, curve: Curve) -> float:
	t = clampf(t, 0.0, 1.0)
	if ease_type == EASE_CUSTOM:
		return curve.sample(t) if curve != null else t
	return CatEase.evaluate(ease_type, t)


static func _curves_equal(a: Curve, b: Curve) -> bool:
	if a.point_count != b.point_count or a.min_value != b.min_value or a.max_value != b.max_value:
		return false
	for i in a.point_count:
		if a.get_point_position(i) != b.get_point_position(i) \
				or a.get_point_left_tangent(i) != b.get_point_left_tangent(i) \
				or a.get_point_right_tangent(i) != b.get_point_right_tangent(i):
			return false
	return true
