@tool
class_name CatMaskFlow
extends Control
## 마퀴/턴 방식으로 텍스트를 흘려보내는 마스크 컨테이너.
## 첫 번째 텍스트 자식(Label·CatText 등 `text` 속성을 가진 Control)을 템플릿으로 삼아
## 내부 복제본을 만들어 흐르게 한다. 컨테이너 자신이 마스크(clip_contents)다.

## 턴이 한 칸 넘어갈 때(턴 흐름) 또는 시퀀스가 한 주기 돌 때(시퀀스 흐름) 발생한다.
signal turn_changed(index: int)

enum FlowDirection { TOP, BOTTOM, LEFT, RIGHT }

const STATIC_ALIGNMENT_START := -1
const STATIC_ALIGNMENT_CENTER := 0
const STATIC_ALIGNMENT_END := 1

const _EPSILON := 0.00001
const _MAX_TURN_STEPS_PER_ADVANCE := 128
const _CONTENT_NAME := "[CatMaskFlow] Content"
const _PROBE_NAME := "[CatMaskFlow] Probe"

@export_group("재생")
@export var play_on_ready: bool = true
## true면 Engine.time_scale 영향 없이 실제 경과 시간으로 진행한다.
## 트리 일시정지 중에는 process_mode에 따라 멈추며, 재개 시 멈춘 시간은 건너뛴다.
@export var use_unscaled_time: bool = false
@export_range(0.0, 60.0, 0.01, "or_greater") var delay: float = 0.0:
	set(value):
		delay = maxf(0.0, value)

@export_group("흐름")
@export var direction: FlowDirection = FlowDirection.LEFT:
	set(value):
		direction = value
		_request_sync()
## true면 텍스트가 마스크보다 클 때만 흐르고, 맞으면 템플릿을 그대로 보여준다.
@export var static_mode: bool = false:
	set(value):
		static_mode = value
		_request_sync()
@export_range(0.01, 2000.0, 0.01, "or_greater") var velocity: float = 80.0:
	set(value):
		velocity = maxf(0.01, value)
## 한 칸 이동 후 대기 시간. 위/아래(턴 흐름)에서만 쓰인다.
@export_range(0.0, 60.0, 0.01, "or_greater") var interval: float = 0.0:
	set(value):
		interval = maxf(0.0, value)
@export_range(0.0, 2000.0, 1.0, "or_greater") var gap: float = 80.0:
	set(value):
		gap = maxf(0.0, value)
		_request_sync()
## 시퀀스 흐름에서 항목당 복제 주기 수의 상한. 0이면 무제한.
@export_range(0, 64, 1, "or_greater") var max_sequence_copy_count: int = 12:
	set(value):
		max_sequence_copy_count = maxi(0, value)
		_request_sync()

@export_group("텍스트")
## 비어 있으면 템플릿의 text를 쓴다. 항목은 resolver를 거쳐 표시 문자열이 된다.
@export var text_entries: PackedStringArray = PackedStringArray():
	set(value):
		text_entries = value
		_request_sync()

var _template: Control = null
var _template_visible: bool = true
var _template_text: String = ""
# 숨긴 템플릿에서 멈춘 CatTextAnimation 자식의 원래 process_mode(자식 이름 → 모드)
var _template_anim_modes: Dictionary = {}
var _source_text: String = ""
var _probe: Control = null
var _clones: Array[Control] = []
var _resolver: Callable = Callable()

var _sizes: PackedVector2Array = PackedVector2Array()
var _item_offsets: PackedFloat32Array = PackedFloat32Array()
var _sequence_distance: float = 1.0
var _origin_offset: Vector2 = Vector2.ZERO
var _flow_active: bool = false

var _is_playing: bool = false
var _elapsed: float = 0.0
var _turn_elapsed: float = 0.0
var _delay_remaining: float = 0.0
var _turn_index: int = 0
var _last_ticks_usec: int = 0

var _dirty: bool = true
var _flush_queued: bool = false
var _ready_done: bool = false


func _init() -> void:
	clip_contents = true


func _ready() -> void:
	_ready_done = true
	if Engine.is_editor_hint():
		return
	_sync_content()
	if play_on_ready:
		play()
	else:
		_apply_state()


func _enter_tree() -> void:
	if _ready_done:
		_request_sync()


func _exit_tree() -> void:
	_restore_template()
	for clone: Control in _clones:
		clone.queue_free()
	_clones.clear()
	if _probe != null:
		_probe.queue_free()
		_probe = null
	_template = null
	_dirty = true


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED, NOTIFICATION_TRANSLATION_CHANGED:
			_request_sync()
		NOTIFICATION_UNPAUSED:
			_last_ticks_usec = Time.get_ticks_usec()


func _process(delta: float) -> void:
	var dt := delta
	if use_unscaled_time:
		var now := Time.get_ticks_usec()
		dt = float(now - _last_ticks_usec) / 1000000.0
		_last_ticks_usec = now
	advance_flow(dt)


# ───────────── 공개 API ─────────────

var is_playing: bool:
	get:
		return _is_playing


func play() -> void:
	_elapsed = 0.0
	_turn_elapsed = 0.0
	_delay_remaining = delay
	_turn_index = 0
	_is_playing = true
	_last_ticks_usec = Time.get_ticks_usec()
	_sync_content()
	_apply_state()
	_update_process()


## 위치와 표시는 유지한 채 멈춘다.
func stop() -> void:
	_is_playing = false
	_update_process()


func restart() -> void:
	play()


## 템플릿을 다시 복제해 내용을 새로 맞춘다. 템플릿의 폰트·크기를 바꿨거나
## 같은 key에 resolver 결과만 바뀐 경우에 호출한다.
func refresh() -> void:
	_discard_clones()
	_sync_content()
	_apply_state()
	_update_process()


func set_text_entries(entries: Variant, restart_flow: bool = false) -> void:
	text_entries = PackedStringArray(entries)
	if restart_flow:
		play()
	else:
		refresh()


## resolver: `func(key: String) -> String`. null을 돌려주면 key를 그대로 쓴다.
func set_text_resolver(resolver: Callable, refresh_immediately: bool = true) -> void:
	_resolver = resolver
	if refresh_immediately:
		refresh()


## 수동 시간 진행(테스트·에디터 미리보기용). 재생 중이고 흐름이 활성일 때만 동작한다.
func advance_flow(dt: float) -> void:
	if not _is_playing:
		return
	_check_source_dirty()
	if _dirty:
		_sync_content()
		_update_process()
	if not _flow_active:
		return
	_advance_playback(maxf(0.0, dt))
	_apply_state()


func get_turn_index() -> int:
	return _turn_index


func is_flow_active() -> bool:
	return _flow_active


func get_content_count() -> int:
	return _clones.size()


func get_content(index: int) -> Control:
	return _clones[index]


## 마스크 중심 기준 복제본 중심의 현재 오프셋.
func get_item_center(index: int) -> Vector2:
	var c := _clones[index]
	return c.position + c.size * 0.5 - size * 0.5


func get_sequence_distance() -> float:
	return _sequence_distance


func get_flow_origin_offset() -> Vector2:
	return _origin_offset


## 현재 턴의 이동 시간(+턴 흐름이면 interval).
func get_turn_duration() -> float:
	if uses_sequence_flow(direction):
		return _sequence_distance / maxf(0.01, velocity)
	var content := _sizes[0] if _sizes.size() > 0 else Vector2.ONE
	return evaluate_travel_distance(content, direction, gap) / maxf(0.01, velocity) + maxf(0.0, interval)


func get_current_text_key() -> String:
	if text_entries.is_empty():
		return _source_text
	return text_entries[evaluate_text_key_index(_turn_index, text_entries.size())]


# ───────────── 순수 함수(정적) ─────────────

## Godot 좌표(y 아래 +) 기준 이동 방향.
static func get_direction_vector(dir: int) -> Vector2:
	match dir:
		FlowDirection.TOP:
			return Vector2(0.0, -1.0)
		FlowDirection.BOTTOM:
			return Vector2(0.0, 1.0)
		FlowDirection.RIGHT:
			return Vector2(1.0, 0.0)
		_:
			return Vector2(-1.0, 0.0)


static func evaluate_text_extent(content_size: Vector2, dir: int) -> float:
	if dir == FlowDirection.TOP or dir == FlowDirection.BOTTOM:
		return maxf(1.0, content_size.y)
	return maxf(1.0, content_size.x)


## 텍스트 한 장이 완전히 지나가는 거리(텍스트 길이 + 앞뒤 gap/2).
static func evaluate_travel_distance(content_size: Vector2, dir: int, gap_value: float) -> float:
	return evaluate_text_extent(content_size, dir) + maxf(0.0, gap_value) * 0.5 + maxf(0.0, gap_value) * 0.5


static func uses_interval(dir: int) -> bool:
	return dir == FlowDirection.TOP or dir == FlowDirection.BOTTOM


static func uses_sequence_flow(dir: int) -> bool:
	return dir == FlowDirection.LEFT or dir == FlowDirection.RIGHT


## 흐름 방향 축으로 텍스트가 마스크보다 길 때만 true.
static func should_use_static_flow(content_size: Vector2, mask_size: Vector2, dir: int) -> bool:
	if dir == FlowDirection.TOP or dir == FlowDirection.BOTTOM:
		return maxf(0.0, content_size.y) > maxf(0.0, mask_size.y)
	return maxf(0.0, content_size.x) > maxf(0.0, mask_size.x)


## 템플릿 정렬(-1 시작 / 0 가운데 / 1 끝)에 따라 넘치는 텍스트의 시작 변이 마스크 가장자리에 맞는 오프셋.
static func evaluate_static_start_position(content_size: Vector2, mask_size: Vector2, dir: int, alignment: int) -> Vector2:
	var clamped := clampi(alignment, STATIC_ALIGNMENT_START, STATIC_ALIGNMENT_END)
	if clamped == STATIC_ALIGNMENT_CENTER:
		return Vector2.ZERO
	if dir == FlowDirection.LEFT or dir == FlowDirection.RIGHT:
		var aligned_x := (maxf(0.0, content_size.x) - maxf(0.0, mask_size.x)) * 0.5
		return Vector2(aligned_x if clamped == STATIC_ALIGNMENT_START else -aligned_x, 0.0)
	# 텍스트가 더 클 때 위쪽 변을 맞추려면 아래(+y)로 내려야 한다.
	var aligned_y := (maxf(0.0, content_size.y) - maxf(0.0, mask_size.y)) * 0.5
	return Vector2(0.0, aligned_y if clamped == STATIC_ALIGNMENT_START else -aligned_y)


## Label/CatText의 정렬 값(HorizontalAlignment/VerticalAlignment, 0 시작 1 가운데 2 끝)을 정적 정렬로 변환한다.
static func evaluate_static_alignment(alignment_value: int) -> int:
	match alignment_value:
		1:
			return STATIC_ALIGNMENT_CENTER
		2:
			return STATIC_ALIGNMENT_END
		_:
			return STATIC_ALIGNMENT_START


static func evaluate_sequence_distance(content_sizes: PackedVector2Array, dir: int, gap_value: float) -> float:
	if content_sizes.is_empty():
		return evaluate_travel_distance(Vector2.ONE, dir, gap_value)
	var safe_gap := maxf(0.0, gap_value)
	var distance := 0.0
	for content_size: Vector2 in content_sizes:
		distance += evaluate_text_extent(content_size, dir) + safe_gap
	return maxf(1.0, distance)


## 순환 시퀀스 안에서 한 항목의 중심 offset(이동 방향 축, 뒤쪽이 음수).
static func evaluate_sequence_item_offset(content_sizes: PackedVector2Array, item_index: int, sequence_index: int, dir: int, gap_value: float) -> float:
	var sequence_offset := -evaluate_sequence_distance(content_sizes, dir, gap_value) * maxi(0, sequence_index)
	if content_sizes.is_empty():
		return sequence_offset
	var count := content_sizes.size()
	var wrapped := ((item_index % count) + count) % count
	var safe_gap := maxf(0.0, gap_value)
	var offset := sequence_offset
	for i in wrapped:
		offset -= evaluate_text_extent(content_sizes[i], dir) * 0.5 + safe_gap + evaluate_text_extent(content_sizes[i + 1], dir) * 0.5
	return offset


static func evaluate_sequence_item_position(flow_distance: float, item_index: int, sequence_index: int, content_sizes: PackedVector2Array, dir: int, gap_value: float) -> Vector2:
	var sequence_distance := evaluate_sequence_distance(content_sizes, dir, gap_value)
	var phase := fposmod(maxf(0.0, flow_distance), sequence_distance)
	return get_direction_vector(dir) * (evaluate_sequence_item_offset(content_sizes, item_index, sequence_index, dir, gap_value) + phase)


## delay·interval을 반영해 실제로 이동한 누적 거리.
static func evaluate_flow_distance(elapsed_time: float, content_size: Vector2, dir: int, velocity_value: float, delay_value: float, interval_value: float, gap_value: float) -> float:
	var travel := evaluate_travel_distance(content_size, dir, gap_value)
	var safe_velocity := maxf(0.01, velocity_value)
	var move_duration := travel / safe_velocity
	var active_time := maxf(0.0, elapsed_time - maxf(0.0, delay_value))
	var effective_interval := maxf(0.0, interval_value) if uses_interval(dir) else 0.0
	var cycle_duration := move_duration + effective_interval
	var completed := floori(active_time / cycle_duration) if cycle_duration > 0.0 else 0
	var cycle_time := active_time - completed * cycle_duration if cycle_duration > 0.0 else 0.0
	return completed * travel + minf(cycle_time, move_duration) * safe_velocity


## 두 복제본을 번갈아 쓰는 방식에서 한 복제본의 중심 위치.
static func evaluate_flow_position(elapsed_time: float, copy_index: int, content_size: Vector2, dir: int, velocity_value: float, delay_value: float, interval_value: float, gap_value: float) -> Vector2:
	var travel := evaluate_travel_distance(content_size, dir, gap_value)
	var flow_distance := evaluate_flow_distance(elapsed_time, content_size, dir, velocity_value, delay_value, interval_value, gap_value)
	var safe_travel := maxf(1.0, travel)
	var loop_distance := safe_travel * 2.0
	var first_offset := fposmod(maxf(0.0, flow_distance), loop_distance)
	if first_offset > safe_travel:
		first_offset -= loop_distance
	var copy_offset := first_offset
	if absi(copy_index) % 2 != 0:
		copy_offset = first_offset - safe_travel if first_offset >= 0.0 else first_offset + safe_travel
	return get_direction_vector(dir) * copy_offset


static func evaluate_text_key_index(turn_index: int, count: int) -> int:
	if count <= 0:
		return 0
	return absi(turn_index) % count


static func resolve_text_key(key: String, resolver: Callable) -> String:
	if resolver.is_null() or not resolver.is_valid():
		return key
	var resolved: Variant = resolver.call(key)
	if resolved == null:
		return key
	return str(resolved)


static func resolve_text_entry(key: String, preview_text: String, resolver: Callable) -> String:
	if not resolver.is_null() and resolver.is_valid():
		var resolved: Variant = resolver.call(key)
		if resolved != null:
			return str(resolved)
	return key if preview_text.is_empty() else preview_text


## 마스크를 채우는 데 필요한 시퀀스 복제 주기 수.
static func evaluate_copy_count(viewport_extent: float, sequence_distance: float, max_count: int) -> int:
	var count := maxi(2, ceili(maxf(1.0, viewport_extent) / maxf(1.0, sequence_distance)) + 2)
	if max_count > 0:
		count = mini(count, max_count)
	return count


# ───────────── 내부 ─────────────

func _request_sync() -> void:
	_dirty = true
	if not is_inside_tree() or _flush_queued:
		return
	_flush_queued = true
	_flush_dirty.call_deferred()


func _flush_dirty() -> void:
	_flush_queued = false
	_check_source_dirty()
	if not _dirty or not is_inside_tree():
		return
	_sync_content()
	_apply_state()
	_update_process()


func _update_process() -> void:
	var on := _is_playing and _flow_active and not Engine.is_editor_hint()
	if on and not is_processing():
		# 꺼져 있던 동안의 시간이 첫 dt로 들어가지 않게 한다.
		_last_ticks_usec = Time.get_ticks_usec()
	set_process(on)


func _find_template() -> Control:
	for child in get_children():
		if child is Control and "text" in child:
			return child
	return null


func _capture_template(found: Control) -> void:
	if found == _template:
		return
	_restore_template()
	_discard_clones()
	_template = found
	if _template == null:
		return
	_template_visible = _template.visible
	_template_text = str(_template.get("text"))
	_source_text = _template_text
	# 흐름이 멈춘 상태에서도 템플릿 텍스트·폰트·번역 변경을 감지한다.
	_template.minimum_size_changed.connect(_request_sync)
	if _template.has_signal("reshaped"):
		_template.connect("reshaped", _request_sync)


func _restore_template() -> void:
	if _template == null or not is_instance_valid(_template):
		return
	if _template.minimum_size_changed.is_connected(_request_sync):
		_template.minimum_size_changed.disconnect(_request_sync)
	if _template.has_signal("reshaped") and _template.is_connected("reshaped", _request_sync):
		_template.disconnect("reshaped", _request_sync)
	_set_template_hidden(false)
	if not text_entries.is_empty():
		_template.set("text", _template_text)


## 템플릿을 숨기는 동안 그 CatTextAnimation 자식의 처리도 멈추고, 다시 보일 때 원래 process_mode로 돌린다.
func _set_template_hidden(hidden: bool) -> void:
	_template.visible = false if hidden else _template_visible
	if hidden:
		if not _template_anim_modes.is_empty():
			return
		for child in _template.get_children():
			if child is CatTextAnimation:
				_template_anim_modes[child.name] = child.process_mode
				child.process_mode = Node.PROCESS_MODE_DISABLED
		return
	for child_name: StringName in _template_anim_modes:
		var child := _template.get_node_or_null(NodePath(child_name))
		if child != null:
			child.process_mode = _template_anim_modes[child_name]
	_template_anim_modes.clear()


## 템플릿 text가 바뀌었으면(엔트리가 없을 때) 다음 동기화에서 다시 맞춘다.
func _check_source_dirty() -> void:
	if _template == null or not text_entries.is_empty():
		return
	var current: String = _template.get("text")
	if current != _source_text:
		_source_text = current
		_template_text = current
		_dirty = true


func _get_item_count() -> int:
	return maxi(1, text_entries.size())


func _get_display_text(turn: int) -> String:
	if text_entries.is_empty():
		return _source_text
	return resolve_text_entry(text_entries[evaluate_text_key_index(turn, text_entries.size())], "", _resolver)


func _neutralize(node: Control) -> void:
	# 줄바꿈·말줄임은 최소 크기를 1로 만들어 자연 크기 측정을 깨뜨린다.
	if "autowrap_mode" in node:
		node.set("autowrap_mode", TextServer.AUTOWRAP_OFF)
	if "clip_text" in node:
		node.set("clip_text", false)
	if "text_overrun_behavior" in node:
		node.set("text_overrun_behavior", TextServer.OVERRUN_NO_TRIMMING)
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.custom_minimum_size = Vector2.ZERO
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_horizontal = Control.SIZE_FILL
	node.size_flags_vertical = Control.SIZE_FILL


func _make_clone(clone_name: String, is_probe: bool = false) -> Control:
	var clone := _template.duplicate() as Control
	clone.name = clone_name
	# 템플릿 감시 연결이 복제되면 측정용 텍스트 대입마다 동기화가 다시 예약된다.
	if clone.minimum_size_changed.is_connected(_request_sync):
		clone.minimum_size_changed.disconnect(_request_sync)
	if clone.has_signal("reshaped") and clone.is_connected("reshaped", _request_sync):
		clone.disconnect("reshaped", _request_sync)
	for child in clone.get_children():
		if child is CatTextAnimation:
			if is_probe:
				# 측정 전용: 재생하지 않는다.
				child.play_on_ready = false
			elif _template_anim_modes.has(child.name):
				# 숨긴 템플릿에서 멈춘 process_mode가 복제되지 않게 원래 값으로 되돌린다.
				child.process_mode = _template_anim_modes[child.name]
	if is_probe:
		clone.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(clone, false, Node.INTERNAL_MODE_BACK)
	clone.visible = not is_probe
	_neutralize(clone)
	return clone


func _ensure_probe() -> void:
	if _probe != null:
		return
	_probe = _make_clone(_PROBE_NAME, true)


func _discard_clones() -> void:
	for clone: Control in _clones:
		remove_child(clone)
		clone.free()
	_clones.clear()
	if _probe != null:
		remove_child(_probe)
		_probe.free()
		_probe = null


func _ensure_clone_count(count: int) -> void:
	while _clones.size() > count:
		var extra: Control = _clones.pop_back()
		remove_child(extra)
		extra.free()
	while _clones.size() < count:
		_clones.append(_make_clone("%s %d" % [_CONTENT_NAME, _clones.size() + 1]))


func _measure(text: String) -> Vector2:
	_ensure_probe()
	_probe.set("text", text)
	if _probe.has_method("get_natural_size"):
		return _probe.call("get_natural_size")
	return _probe.get_minimum_size()


## 흐름용 컨텐츠 크기: 폭은 텍스트 그대로, 높이는 최소 마스크 높이.
func _content_size(text: String) -> Vector2:
	var preferred := _measure(text)
	return Vector2(maxf(1.0, preferred.x), maxf(maxf(1.0, size.y), preferred.y))


func _get_static_alignment() -> int:
	var prop := "horizontal_alignment" if uses_sequence_flow(direction) else "vertical_alignment"
	if not prop in _template:
		return STATIC_ALIGNMENT_START
	return evaluate_static_alignment(int(_template.get(prop)))


func _sync_content() -> void:
	_dirty = false
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	_capture_template(_find_template())
	if _template == null:
		_flow_active = false
		_ensure_clone_count(0)
		return

	_origin_offset = Vector2.ZERO
	if static_mode:
		var display := _get_display_text(_turn_index)
		var source_size := _measure(display)
		source_size = Vector2(maxf(1.0, source_size.x), maxf(1.0, source_size.y))
		if not should_use_static_flow(source_size, size, direction):
			_flow_active = false
			if not text_entries.is_empty():
				_template.set("text", display)
			_set_template_hidden(false)
			_ensure_clone_count(0)
			return
		_origin_offset = evaluate_static_start_position(source_size, size, direction, _get_static_alignment())

	_flow_active = true
	_set_template_hidden(true)
	if uses_sequence_flow(direction):
		_sync_sequence_content()
	else:
		_sync_turn_content()


func _sync_sequence_content() -> void:
	var item_count := _get_item_count()
	_sizes.resize(item_count)
	for i in item_count:
		_sizes[i] = _content_size(_get_display_text(i))
	_sequence_distance = evaluate_sequence_distance(_sizes, direction, gap)
	_item_offsets.resize(item_count)
	for i in item_count:
		_item_offsets[i] = evaluate_sequence_item_offset(_sizes, i, 0, direction, gap)
	var copy_count := evaluate_copy_count(evaluate_text_extent(size, direction), _sequence_distance, max_sequence_copy_count)
	_ensure_clone_count(maxi(2, item_count * copy_count))
	for i in _clones.size():
		var entry := i % item_count
		_clones[i].set("text", _get_display_text(entry))
		_clones[i].size = _sizes[entry]


func _sync_turn_content() -> void:
	_ensure_clone_count(2)
	_sizes.resize(1)
	# 턴이 넘어가면 대기하던 복제본(1)이 이미 현재 텍스트를 들고 있으므로, 텍스트를 다시 넣지 않고
	# 순서만 바꾼다. 도착한 텍스트의 CatTextAnimation이 재시작되지 않는다.
	var current := _get_display_text(_turn_index)
	if str(_clones[0].get("text")) != current and str(_clones[1].get("text")) == current:
		var arrived := _clones[1]
		_clones[1] = _clones[0]
		_clones[0] = arrived
	for i in 2:
		var content := _content_size(_get_display_text(_turn_index + i))
		_clones[i].set("text", _get_display_text(_turn_index + i))
		_clones[i].size = content
		if i == 0:
			_sizes[0] = content


func _place(clone: Control, center_offset: Vector2) -> void:
	clone.position = size * 0.5 + _origin_offset + center_offset - clone.size * 0.5


func _apply_state() -> void:
	if not _flow_active or _clones.is_empty():
		return
	var dir_vec := get_direction_vector(direction)
	var speed := maxf(0.01, velocity)
	if uses_sequence_flow(direction):
		var move_duration := _sequence_distance / speed
		var progress := clampf(_turn_elapsed / move_duration, 0.0, 1.0) if move_duration > 0.0 else 1.0
		var phase := fposmod(maxf(0.0, _sequence_distance * progress), _sequence_distance)
		var item_count := _item_offsets.size()
		for i in _clones.size():
			var offset := _item_offsets[i % item_count] - _sequence_distance * (i / item_count) + phase
			_place(_clones[i], dir_vec * offset)
		return
	var travel := evaluate_travel_distance(_sizes[0], direction, gap)
	var turn_move_duration := travel / speed
	var turn_progress := clampf(_turn_elapsed / turn_move_duration, 0.0, 1.0) if turn_move_duration > 0.0 else 1.0
	var flow_distance := travel * turn_progress
	_place(_clones[0], dir_vec * flow_distance)
	_place(_clones[1], dir_vec * (flow_distance - travel))


func _advance_playback(dt: float) -> void:
	_elapsed += dt
	var remaining := dt
	if _delay_remaining > 0.0:
		var consumed := minf(_delay_remaining, remaining)
		_delay_remaining -= consumed
		remaining -= consumed
		if remaining <= _EPSILON:
			return
	var guard := 0
	while remaining > _EPSILON and guard < _MAX_TURN_STEPS_PER_ADVANCE and _flow_active:
		var turn_duration := get_turn_duration()
		var remaining_turn := maxf(0.0, turn_duration - _turn_elapsed)
		if remaining < remaining_turn:
			_turn_elapsed += remaining
			return
		_turn_elapsed = turn_duration
		remaining -= remaining_turn
		_advance_turn()
		guard += 1


func _advance_turn() -> void:
	_turn_index += 1
	_turn_elapsed = 0.0
	# 시퀀스 흐름은 배치가 주기적이라 static 판정이 필요할 때만 다시 맞춘다.
	if not uses_sequence_flow(direction) or static_mode:
		_sync_content()
		_update_process()
	turn_changed.emit(_turn_index)
