@tool
class_name CatTextCurve
extends CatTextModifier
## 글자를 Curve를 따라 배치한다. Curve X = 텍스트 가로 위치(0~1), Y = 높이 비율(위쪽 +).
## 결과는 화면 좌표(y 아래 +, 회전 시계 방향 +)로 CatText.curve_offset_y / curve_angle에 기록된다.

## null이면 곡선 없음(평평, 오프셋 0). set_arch_curve()·set_wave_curve()는 비어 있으면 새 Curve를 만든다.
@export var curve: Curve:
	set(value):
		if curve == value:
			return
		if curve != null and curve.changed.is_connected(refresh):
			curve.changed.disconnect(refresh)
		curve = value
		if curve != null:
			curve.changed.connect(refresh)
		refresh()
## 픽셀. 동적 보정을 켜면 "기준 조건에서의 강도".
@export var curve_scale: float = 50.0:
	set(value):
		curve_scale = value
		refresh()
## 가시 글자 오프셋 평균을 0으로 맞춰 블록이 한쪽으로 밀리지 않게 한다.
@export var preserve_vertical_center: bool = true:
	set(value):
		preserve_vertical_center = value
		refresh()

@export_group("Rotation")
@export var rotate_along_curve: bool = true:
	set(value):
		rotate_along_curve = value
		refresh()
@export_range(0.0, 1.0) var rotation_strength: float = 1.0:
	set(value):
		rotation_strength = clampf(value, 0.0, 1.0)
		refresh()

@export_group("Dynamic Scale")
@export var enable_dynamic_curve_scale: bool = true:
	set(value):
		enable_dynamic_curve_scale = value
		refresh()
@export var reference_visible_character_count: float = 10.0:
	set(value):
		reference_visible_character_count = value
		refresh()
@export var reference_font_size: float = 36.0:
	set(value):
		reference_font_size = value
		refresh()
## (0,0)이면 Rect 보정을 쓰지 않는다.
@export var reference_rect_size: Vector2 = Vector2.ZERO:
	set(value):
		reference_rect_size = value
		refresh()

var _dirty := true
var _cached_version := -1
var _cached_size := Vector2(-1.0, -1.0)
var _cached_font_size := -1
var _offsets := PackedFloat32Array()
var _angles := PackedFloat32Array()


static func create_default_curve() -> Curve:
	var c := Curve.new()
	c.min_value = -2.0
	c.max_value = 2.0
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.5, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c


## 다음 그리기에서 오프셋을 다시 계산한다.
func refresh() -> void:
	_dirty = true
	_notify_changed()


func set_arch_curve(height: float) -> void:
	var c := _editable_curve()
	c.clear_points()
	c.add_point(Vector2(0.0, 0.0), 0.0, 2.0)
	c.add_point(Vector2(0.5, 1.0), 0.0, 0.0)
	c.add_point(Vector2(1.0, 0.0), -2.0, 0.0)
	curve_scale = height
	refresh()


func set_wave_curve(amplitude: float, frequency: float = 1.0) -> void:
	var c := _editable_curve()
	c.clear_points()
	var key_count := maxi(5, int(round(frequency * 4.0)) + 1)
	for i in key_count:
		var t := float(i) / float(key_count - 1)
		var w := frequency * TAU
		# 키 사이가 사인파처럼 이어지도록 해석적 기울기를 탄젠트로 쓴다.
		var tangent := w * cos(t * w)
		c.add_point(Vector2(t, sin(t * w)), tangent, tangent)
	curve_scale = amplitude
	refresh()


func reset_curve() -> void:
	var c := _editable_curve()
	c.clear_points()
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(1.0, 0.0))
	curve_scale = 0.0
	refresh()


func _editable_curve() -> Curve:
	if curve == null:
		curve = create_default_curve()
	curve.min_value = minf(curve.min_value, -2.0)
	curve.max_value = maxf(curve.max_value, 2.0)
	return curve


## CatText._draw에서 호출된다. 캐시가 유효하면 다시 계산하지 않는다.
func fill_offsets(text: CatText) -> void:
	var n := text.get_cluster_count()
	var version := text.get_layout_version()
	var fs := text.get_effective_font_size()
	if _dirty or _offsets.size() != n or version != _cached_version or text.size != _cached_size or fs != _cached_font_size:
		_compute(text, n)
		_dirty = false
		_cached_version = version
		_cached_size = text.size
		_cached_font_size = fs
	# 배열은 공유(COW)되므로 복사 없이 넘어간다.
	text.curve_offset_y = _offsets
	text.curve_angle = _angles


## 원본 GetEffectiveCurveScale과 같은 공식.
static func compute_effective_scale(base_scale: float, dynamic: bool, visible_count: int, ref_chars: float,
		ref_font: float, current_font_size: float, rect_size: Vector2, ref_rect: Vector2) -> float:
	if not dynamic or visible_count <= 0:
		return base_scale
	var char_factor := float(maxi(1, visible_count)) / maxf(1.0, ref_chars)
	var font_factor := current_font_size / maxf(0.01, ref_font)
	var s := base_scale * char_factor * font_factor
	if ref_rect.x > 0.01 and ref_rect.y > 0.01:
		s *= sqrt(maxf(0.01, absf(rect_size.x * rect_size.y)) / maxf(0.01, ref_rect.x * ref_rect.y))
	elif ref_rect.x > 0.01:
		s *= rect_size.x / maxf(0.01, ref_rect.x)
	elif ref_rect.y > 0.01:
		s *= rect_size.y / maxf(0.01, ref_rect.y)
	return s


func get_effective_curve_scale(text: CatText) -> float:
	var visible_count := 0
	for k in text.get_cluster_count():
		if text.is_cluster_visible(k):
			visible_count += 1
	return compute_effective_scale(curve_scale, enable_dynamic_curve_scale, visible_count,
		reference_visible_character_count, reference_font_size, float(text.get_effective_font_size()),
		text.size, reference_rect_size)


func _compute(text: CatText, n: int) -> void:
	if _offsets.size() != n:
		_offsets.resize(n)
		_angles.resize(n)
	_offsets.fill(0.0)
	_angles.fill(0.0)
	var bounds := text.get_text_bounds()
	if n == 0 or curve == null or bounds.size.x <= 0.0:
		return
	var eff := get_effective_curve_scale(text)
	var min_x := bounds.position.x
	var width := bounds.size.x
	var sum := 0.0
	var visible_count := 0
	for k in n:
		if not text.is_cluster_visible(k):
			continue
		var r := text.get_cluster_rect(k)
		var nx := (r.position.x + r.size.x * 0.5 - min_x) / width
		var cy := curve.sample(nx) * eff
		var angle := 0.0
		if rotate_along_curve and rotation_strength > 0.0:
			var x0 := clampf(nx - 0.001, 0.0, 1.0)
			var x1 := clampf(nx + 0.001, 0.0, 1.0)
			var y0 := curve.sample(x0) * eff
			var y1 := curve.sample(x1) * eff
			angle = rad_to_deg(atan2(y1 - y0, (x1 - x0) * width)) * rotation_strength
		# Unity(y 위 +, 반시계 +) → Godot(y 아래 +, 시계 +)
		_offsets[k] = -cy
		_angles[k] = -angle
		sum += cy
		visible_count += 1
	if preserve_vertical_center and visible_count > 0:
		var dy := sum / visible_count
		if absf(dy) > 1e-5:
			for k in n:
				if text.is_cluster_visible(k):
					_offsets[k] += dy
