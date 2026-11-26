@tool
class_name CatTextAnimation
extends CatTextModifier
## CatText 글자별 Appear / Loop / Disappear / Impact 애니메이션. 부모 CatText의 자식으로 붙인다.
## 좌표는 Godot 기준(y 아래 +, 회전 양수 = 시계 방향). 계산 자체는 CatTextTimeline이 한다.

signal animation_finished
signal impact_finished

@export var preset: CatTextAnimationPreset:
	set(value):
		preset = value
		if value != null:
			apply_preset(value)
## 씬 시작(첫 셰이핑 직후)에 자동 재생. 에디터에서는 자동 재생하지 않는다.
@export var play_on_ready: bool = true
## true면 Unity 원본처럼 보간 계수를 [0,1]로 잘라 OutBack 등의 오버슈트를 없앤다.
@export var clamp_overshoot: bool = false

@export_group("Timing")
@export_range(0.0, 0.5, 0.001) var character_delay: float = 0.05
@export_range(0.0, 5.0, 0.01) var initial_delay: float = 0.0
## X: 글자 좌변~우변, Y: 베이스라인~ascent 상단
@export var pivot: Vector2 = Vector2(0.5, 0.0)

@export_group("Appear")
@export var enable_appear: bool = true
@export var appear_relative: bool = true
@export var appear_position: Vector2 = Vector2(0, -50)
@export var appear_scale: Vector2 = Vector2(0.5, 0.5)
@export var appear_rotation: float = 0.0
@export_range(0.0, 1.0, 0.01) var appear_alpha: float = 0.0
@export var appear_duration: float = 0.5
@export var appear_ease: CatEase.Type = CatEase.Type.OUT_BACK
## 지정하면 appear_ease보다 우선
@export var appear_curve: Curve
@export_range(0.0, 0.5, 0.01) var appear_to_loop_blend: float = 0.0
@export var appear_use_position_curve: bool = false
@export var appear_position_curve_offset: Vector2 = Vector2.ZERO

@export_group("Loop")
@export var enable_loop: bool = false
@export var loop_relative: bool = true
@export var loop_position: Vector2 = Vector2(0, -20)
@export var loop_scale: Vector2 = Vector2.ONE
@export var loop_rotation: float = 0.0
@export var loop_duration: float = 1.0
@export var loop_ease: CatEase.Type = CatEase.Type.IN_OUT_SINE
@export var loop_curve: Curve
## 0 = 비활성, N = N회, -1 = 무한(무한이면 Disappear는 무시)
@export var loop_count: int = 1
@export var loop_type: CatTextAnimationPreset.LoopType = CatTextAnimationPreset.LoopType.YOYO
@export_range(0.0, 0.5, 0.01) var loop_to_disappear_blend: float = 0.0
@export var loop_use_position_curve: bool = false
@export var loop_position_curve_offset: Vector2 = Vector2.ZERO

@export_group("Disappear")
@export var enable_disappear: bool = false
@export var disappear_relative: bool = true
@export var disappear_position: Vector2 = Vector2(0, 50)
@export var disappear_scale: Vector2 = Vector2(0.5, 0.5)
@export var disappear_rotation: float = 0.0
@export_range(0.0, 1.0, 0.01) var disappear_alpha: float = 0.0
@export var disappear_duration: float = 0.5
@export var disappear_ease: CatEase.Type = CatEase.Type.IN_BACK
@export var disappear_curve: Curve
@export var disappear_use_position_curve: bool = false
@export var disappear_position_curve_offset: Vector2 = Vector2.ZERO

@export_group("Impact")
@export var enable_impact: bool = false
@export var impact_scale: Vector2 = Vector2(1.2, 1.2)
@export var impact_position: Vector2 = Vector2.ZERO
@export var impact_rotation: float = 0.0
@export_range(0.05, 1.0, 0.01) var impact_duration: float = 0.15
@export var impact_ease: CatEase.Type = CatEase.Type.OUT_QUAD
@export var impact_curve: Curve
@export_range(0.0, 0.1, 0.001) var impact_character_delay: float = 0.02

@export_group("Editor Preview")
@export_tool_button("미리보기 재생") var _preview_play: Callable = restart
@export_tool_button("미리보기 정지") var _preview_stop: Callable = stop
@export_tool_button("Impact") var _preview_impact: Callable = trigger_impact

var is_playing: bool:
	get:
		return _is_playing
var is_impact_playing: bool:
	get:
		return _timeline != null and _timeline.impact_playing

var _timeline: CatTextTimeline
var _cfg: CatTextAnimationPreset
var _is_playing: bool = false
var _paused: bool = false
var _started: bool = false
var _connected_text: CatText
var _played_text: String = ""
var _has_played: bool = false


func _ready() -> void:
	set_process(false)
	_connect_text()
	_started = true
	if play_on_ready and not Engine.is_editor_hint():
		_play_when_ready.call_deferred()


func _enter_tree() -> void:
	# 재부모 시 _ready는 다시 불리지 않으므로 여기서 새 부모에 연결한다.
	_connect_text()


func _exit_tree() -> void:
	_disconnect_text()


func _process(delta: float) -> void:
	advance(delta)


## 현재 설정으로 처음부터 재생한다. 텍스트가 비어 있거나 공백뿐이면 animation_finished만 (지연) 발생한다.
func play() -> void:
	var text := get_text()
	if text == null:
		return
	var count := text.get_cluster_count()
	if count == 0:
		stop()
		_played_text = text.get_display_text()
		_has_played = true
		animation_finished.emit.call_deferred()
		return
	if _cfg == null:
		_cfg = CatTextAnimationPreset.new()
	_cfg.copy_from(self)
	_played_text = text.get_display_text()
	_has_played = true
	if _timeline == null:
		_timeline = CatTextTimeline.new()
	_timeline.cfg = _cfg
	_timeline.clamp_overshoot = clamp_overshoot
	var indices := PackedInt32Array()
	var visible := PackedByteArray()
	var centers := PackedVector2Array()
	indices.resize(count)
	visible.resize(count)
	centers.resize(count)
	for k in count:
		indices[k] = text.get_cluster_char_index(k)
		visible[k] = 1 if text.is_cluster_visible(k) else 0
		var r := text.get_cluster_rect(k)
		centers[k] = Vector2(lerpf(r.position.x, r.end.x, pivot.x),
				lerpf(text.get_cluster_baseline(k), r.position.y, pivot.y))
	_timeline.begin(indices, visible, centers)
	_is_playing = _timeline.main_active
	_paused = false
	set_process(_is_playing)
	_notify_changed()
	if not _is_playing:
		animation_finished.emit.call_deferred()


## 재생을 멈추고 원본 표시로 되돌린다.
func stop() -> void:
	_timeline = null
	_is_playing = false
	_paused = false
	set_process(false)
	_notify_changed()


func pause() -> void:
	if _timeline == null:
		return
	_paused = true
	set_process(false)


func resume() -> void:
	if _timeline == null:
		return
	_paused = false
	set_process(_is_playing)


func restart() -> void:
	stop()
	play()


## Impact를 한 번 재생한다(재생 중이면 무시). play()로 타임라인이 만들어진 뒤에만 동작한다.
func trigger_impact() -> void:
	if _timeline == null:
		return
	# 재생 후 바꾼 impact 설정도 반영한다(나머지 단계 설정은 재생 시점 스냅샷 유지).
	for f in CatTextAnimationPreset.FIELDS:
		if f.begins_with("impact_") or f == "enable_impact":
			_cfg.set(f, get(f))
	_timeline.cfg = _cfg
	if _timeline.trigger_impact():
		_is_playing = true
		set_process(not _paused)


func apply_preset(p: CatTextAnimationPreset) -> void:
	if p == null:
		return
	p.apply_to(self)
	if _is_playing:
		restart()


## 한 프레임 진행. 수동 구동이나 테스트용으로 공개한다.
func advance(dt: float) -> void:
	if _timeline == null:
		return
	var was_main := _timeline.main_active
	var was_impact := _timeline.impact_playing
	var any := _timeline.advance(dt)
	_notify_changed()
	if was_impact and not _timeline.impact_playing:
		impact_finished.emit()
	if was_main and not _timeline.main_active:
		animation_finished.emit()
	if not any:
		_is_playing = false
		set_process(false)


## CatText._draw에서 호출된다. 상태를 채웠으면 true. 재생 전(타임라인 없음)이면 false.
## 타임라인 출력 배열을 참조로 넘긴다(Packed 배열은 참조 전달이라 복사가 없다). CatText는 이 배열을 수정하지 않는다.
func fill_states(text: CatText) -> bool:
	if _timeline == null or _timeline.get_count() != text.get_cluster_count():
		return false
	text.anim_pivot = pivot
	text.anim_pos = _timeline.out_pos
	text.anim_scale = _timeline.out_scale
	text.anim_rot = _timeline.out_rot
	text.anim_alpha = _timeline.out_alpha
	return true


func _connect_text() -> void:
	var text := get_text()
	if text == _connected_text:
		return
	_disconnect_text()
	if text == null:
		return
	_connected_text = text
	if not text.reshaped.is_connected(_on_reshaped):
		text.reshaped.connect(_on_reshaped)


func _disconnect_text() -> void:
	if _connected_text != null and is_instance_valid(_connected_text) and _connected_text.reshaped.is_connected(_on_reshaped):
		_connected_text.reshaped.disconnect(_on_reshaped)
	_connected_text = null


func _play_when_ready() -> void:
	var text := get_text()
	if text != null and text.get_cluster_count() > 0 and not _is_playing:
		play()


func _on_reshaped() -> void:
	var text := get_text()
	if text == null:
		return
	# 리사이즈·같은 번역·테마 변경처럼 표시 문자열이 그대로인 재셰이핑에는 다시 재생하지 않는다.
	if _has_played and text.get_display_text() == _played_text:
		if not _is_playing or text.get_cluster_count() == _timeline.get_count():
			text.queue_redraw()
			return
	if _is_playing:
		var was_paused := _paused
		restart()
		if was_paused:
			pause()
	elif play_on_ready and _started and not Engine.is_editor_hint():
		play()
	elif _timeline != null:
		# 끝난 재생의 최종 포즈(alpha 0 등)가 새 텍스트에 남지 않게 버린다.
		stop()
