@tool
class_name CatTextTimeline
extends RefCounted
## CatTextAnimation의 글자별 타임라인 계산(Appear/Loop/Disappear/Impact). CatText에 의존하지 않는
## 순수 로직이라 헤드리스 테스트가 가능하다. 결과는 out_* 배열(클러스터 인덱스 기준)에 쓴다.

class Pose extends RefCounted:
	var pos: Vector2 = Vector2.ZERO
	var scale: Vector2 = Vector2.ONE
	var rot: float = 0.0
	var alpha: float = 1.0

	func set_values(p: Vector2, s: Vector2, r: float, a: float) -> void:
		pos = p
		scale = s
		rot = r
		alpha = a

	func copy(o: Pose) -> void:
		pos = o.pos
		scale = o.scale
		rot = o.rot
		alpha = o.alpha


class CharState extends RefCounted:
	var visible: bool = false
	var active: bool = false
	var char_index: int = 0
	var delay: float = 0.0
	var appear_start: float = 0.0
	var appear_end: float = 0.0
	var loop_enabled: bool = false
	var loop_start: float = 0.0
	var infinite: bool = false
	var appear_blend_active: bool = false
	var disappear_enabled: bool = false
	var disappear_start: float = 0.0
	var disappear_end: float = 0.0
	var disappear_blend_active: bool = false
	var has_loop_captured: bool = false
	var has_disappear_captured: bool = false
	var appear_from: Pose = Pose.new()
	var appear_to: Pose = Pose.new()
	var loop_from: Pose = Pose.new()
	var loop_to: Pose = Pose.new()
	var disappear_from: Pose = Pose.new()
	var disappear_to: Pose = Pose.new()
	# Impact 합성 전 기본 값. 블렌드의 "직전 프레임 출력"으로도 쓰인다.
	var cur: Pose = Pose.new()
	var impact_active: bool = false
	var impact_delay: float = 0.0

## 설정 스냅샷. begin() 전에 지정한다.
var cfg: CatTextAnimationPreset
## true면 Unity 원본처럼 보간 계수를 [0,1]로 잘라 오버슈트를 없앤다.
var clamp_overshoot: bool = false

var out_pos: PackedVector2Array = PackedVector2Array()
var out_scale: PackedVector2Array = PackedVector2Array()
var out_rot: PackedFloat32Array = PackedFloat32Array()
var out_alpha: PackedFloat32Array = PackedFloat32Array()
## 메인(Appear/Loop/Disappear) 진행 중 여부
var main_active: bool = false
var impact_playing: bool = false

var _count: int = 0
var _states: Array[CharState] = []
var _elapsed: float = 0.0
var _impact_elapsed: float = 0.0


func get_count() -> int:
	return _count


## char_indices: 클러스터별 원문 인덱스(글자 지연 계산용), visible: 0/1, centers: 피벗 반영 글자 중심.
func begin(char_indices: PackedInt32Array, visible: PackedByteArray, centers: PackedVector2Array) -> void:
	_count = char_indices.size()
	_elapsed = 0.0
	_impact_elapsed = 0.0
	impact_playing = false
	main_active = false
	_states.clear()
	out_pos.resize(_count)
	out_scale.resize(_count)
	out_rot.resize(_count)
	out_alpha.resize(_count)
	for i in _count:
		var s := CharState.new()
		s.visible = visible[i] != 0
		s.char_index = char_indices[i]
		_states.append(s)
		if s.visible:
			_init_character(s, centers[i])
			s.active = true
			main_active = true
			if cfg.enable_appear:
				s.cur.copy(s.appear_from)
		_compose(i, s)


## dt만큼 진행하고 아직 진행 중인 것이 있으면 true.
func advance(dt: float) -> bool:
	if _count == 0:
		return false
	_elapsed += dt
	if impact_playing:
		_impact_elapsed += dt
	var any_main := false
	var any_impact := false
	for i in _count:
		var s := _states[i]
		if not s.visible:
			continue
		if s.active:
			_evaluate_character(s, _elapsed - s.delay)
		if s.impact_active and _impact_elapsed - s.impact_delay >= cfg.impact_duration:
			s.impact_active = false
		any_main = any_main or s.active
		any_impact = any_impact or s.impact_active
		_compose(i, s)
	main_active = any_main
	impact_playing = any_impact
	return any_main or any_impact


## Impact를 시작한다. 비활성이거나 이미 재생 중이면 false(무시).
func trigger_impact() -> bool:
	if _count == 0 or not cfg.enable_impact or impact_playing:
		return false
	_impact_elapsed = 0.0
	impact_playing = true
	for s in _states:
		if s.visible:
			s.impact_active = true
			s.impact_delay = s.char_index * cfg.impact_character_delay
	return true


func _init_character(s: CharState, center: Vector2) -> void:
	s.delay = cfg.initial_delay + s.char_index * cfg.character_delay
	var t := 0.0
	if cfg.enable_appear:
		s.appear_start = t
		s.appear_end = t + cfg.appear_duration
		_from_to(true, cfg.appear_relative, cfg.appear_position, cfg.appear_scale,
				cfg.appear_rotation, cfg.appear_alpha, center, s.appear_from, s.appear_to)
		t += cfg.appear_duration - cfg.appear_duration * cfg.appear_to_loop_blend
		t = maxf(t, 0.0)

	s.loop_enabled = cfg.enable_loop and cfg.loop_count != 0
	s.loop_start = t
	if s.loop_enabled:
		_from_to(false, cfg.loop_relative, cfg.loop_position, cfg.loop_scale,
				cfg.loop_rotation, 1.0, center, s.loop_from, s.loop_to)
		s.appear_blend_active = cfg.enable_appear and cfg.appear_to_loop_blend > 0.0
		s.infinite = cfg.loop_count == -1
		if s.infinite:
			s.disappear_enabled = false
			return
		t += _cycle_duration() * cfg.loop_count
		t -= cfg.loop_duration * cfg.loop_to_disappear_blend
		t = maxf(t, 0.0)

	s.disappear_enabled = cfg.enable_disappear
	s.disappear_start = t
	s.disappear_end = t + cfg.disappear_duration
	_from_to(false, cfg.disappear_relative, cfg.disappear_position, cfg.disappear_scale,
			cfg.disappear_rotation, cfg.disappear_alpha, center, s.disappear_from, s.disappear_to)
	s.disappear_blend_active = (s.loop_enabled and cfg.loop_to_disappear_blend > 0.0) \
			or (cfg.enable_appear and not s.loop_enabled and cfg.appear_to_loop_blend > 0.0)


func _cycle_duration() -> float:
	if cfg.loop_type == CatTextAnimationPreset.LoopType.YOYO:
		return cfg.loop_duration * 2.0
	return cfg.loop_duration


# 위치는 "글자 기준 오프셋"(0 = 원위치). 절대 모드는 입력 좌표에서 글자 중심을 뺀다.
func _from_to(is_from: bool, relative: bool, pos: Vector2, scl: Vector2, rot: float, alpha: float,
		center: Vector2, from: Pose, to: Pose) -> void:
	var p := pos if relative else pos - center
	if is_from:
		from.set_values(p, scl, rot, alpha)
		to.set_values(Vector2.ZERO, Vector2.ONE, 0.0, 1.0)
	else:
		from.set_values(Vector2.ZERO, Vector2.ONE, 0.0, 1.0)
		to.set_values(p, scl, rot, alpha)


func _evaluate_character(s: CharState, time: float) -> void:
	if time < 0.0:
		if s.appear_end > 0.0:
			s.cur.copy(s.appear_from)
		return
	if s.appear_end > 0.0 and time < s.appear_end:
		if time >= s.appear_start:
			var dur := s.appear_end - s.appear_start
			var raw := clampf((time - s.appear_start) / dur, 0.0, 1.0) if dur > 0.0 else 1.0
			var eased := CatEase.sample(cfg.appear_ease, cfg.appear_curve, raw)
			_interpolate(s, s.appear_from, s.appear_to, eased,
					cfg.appear_use_position_curve, cfg.appear_position_curve_offset, false)
		else:
			s.cur.copy(s.appear_from)
		# 원본 동작: 블렌드 구간에서는 Loop가 Appear 결과를 덮어쓴다.
		if s.loop_enabled and s.appear_blend_active and time >= s.loop_start:
			_evaluate_loop(s, time)
		return
	if s.loop_enabled and time >= s.loop_start:
		if not s.has_loop_captured and s.appear_blend_active:
			s.loop_from.copy(s.cur)
			s.has_loop_captured = true
		if s.disappear_enabled and time >= s.disappear_start:
			_evaluate_disappear(s, time)
			return
		_evaluate_loop(s, time)
		if not s.infinite and not s.disappear_enabled:
			var loop_end := s.loop_start + _cycle_duration() * cfg.loop_count
			if time >= loop_end:
				if cfg.loop_type == CatTextAnimationPreset.LoopType.YOYO:
					s.cur.copy(s.loop_from)
				else:
					s.cur.copy(s.loop_to)
				s.active = false
		return
	if s.disappear_enabled and time >= s.disappear_start:
		_evaluate_disappear(s, time)
		return
	if not s.infinite:
		# 원본은 마지막 프레임 값을 그대로 두지만, 여기서는 to 상태를 확정한다.
		s.cur.copy(s.appear_to)
		s.active = false


func _evaluate_loop(s: CharState, time: float) -> void:
	var loop_time := time - s.loop_start
	var single := cfg.loop_duration
	if loop_time < 0.0 or single <= 0.0:
		return
	var yoyo := cfg.loop_type == CatTextAnimationPreset.LoopType.YOYO
	var cycle := single * 2.0 if yoyo else single
	if not s.infinite and cfg.loop_count > 0:
		var total := cycle * cfg.loop_count
		if loop_time >= total:
			loop_time = total - 0.0001
	var cycle_time := fmod(loop_time, cycle)
	var from := s.loop_from
	var to := s.loop_to
	var raw := cycle_time / single
	if yoyo and cycle_time >= single:
		raw = (cycle_time - single) / single
		from = s.loop_to
		to = s.loop_from
	var eased := CatEase.sample(cfg.loop_ease, cfg.loop_curve, clampf(raw, 0.0, 1.0))
	var first_forward := loop_time < single and s.appear_blend_active and s.has_loop_captured
	_interpolate(s, from, to, eased, cfg.loop_use_position_curve, cfg.loop_position_curve_offset, first_forward)


func _evaluate_disappear(s: CharState, time: float) -> void:
	if not s.has_disappear_captured and s.disappear_blend_active:
		s.disappear_from.copy(s.cur)
		s.has_disappear_captured = true
	if time >= s.disappear_end:
		s.cur.copy(s.disappear_to)
		s.active = false
		return
	var dur := s.disappear_end - s.disappear_start
	var raw := clampf((time - s.disappear_start) / dur, 0.0, 1.0) if dur > 0.0 else 1.0
	var eased := CatEase.sample(cfg.disappear_ease, cfg.disappear_curve, raw)
	var use_blend := s.disappear_blend_active and s.has_disappear_captured
	_interpolate(s, s.disappear_from, s.disappear_to, eased,
			cfg.disappear_use_position_curve, cfg.disappear_position_curve_offset, use_blend)


func _interpolate(s: CharState, from: Pose, to: Pose, t: float, use_pos_curve: bool,
		curve_offset: Vector2, use_cur_as_from: bool) -> void:
	var fp := from.pos
	var fs := from.scale
	var fr := from.rot
	var fa := from.alpha
	if use_cur_as_from:
		fp = s.cur.pos
		fs = s.cur.scale
		fr = s.cur.rot
		fa = s.cur.alpha
	var lt := clampf(t, 0.0, 1.0) if clamp_overshoot else t
	if use_pos_curve:
		# 2차 베지어. 원본처럼 t는 잘라내지 않는다.
		var mid := (fp + to.pos) * 0.5 + curve_offset
		var u := 1.0 - t
		s.cur.pos = u * u * fp + 2.0 * u * t * mid + t * t * to.pos
	else:
		s.cur.pos = fp + (to.pos - fp) * lt
	s.cur.scale = fs + (to.scale - fs) * lt
	s.cur.rot = fr + (to.rot - fr) * lt
	s.cur.alpha = clampf(fa + (to.alpha - fa) * lt, 0.0, 1.0)


# Impact는 scale 곱, pos/rot 덧셈. alpha는 건드리지 않는다.
func _compose(i: int, s: CharState) -> void:
	var pos := s.cur.pos
	var scl := s.cur.scale
	var rot := s.cur.rot
	if s.impact_active:
		var t := 0.0
		if cfg.impact_duration > 0.0:
			t = clampf((_impact_elapsed - s.impact_delay) / cfg.impact_duration, 0.0, 1.0)
		var mirrored := t * 2.0 if t <= 0.5 else (1.0 - t) * 2.0
		var k := CatEase.sample(cfg.impact_ease, cfg.impact_curve, mirrored)
		var lk := clampf(k, 0.0, 1.0) if clamp_overshoot else k
		scl *= Vector2.ONE + (cfg.impact_scale - Vector2.ONE) * lk
		pos += cfg.impact_position * k
		rot += cfg.impact_rotation * k
	out_pos[i] = pos
	out_scale[i] = scl
	out_rot[i] = rot
	out_alpha[i] = s.cur.alpha
