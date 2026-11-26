@tool
class_name CatLayoutLimiter
extends Node
## 부모 텍스트 노드(Label·CatText)의 폭/높이를 제한한다.
## 자연 크기가 한도에 "도달"하면 줄바꿈을 켜고 최소 크기를 고정하고, 미만이면 원래 상태로 되돌린다.
## 에디터에서는 동작하지 않는다(부모 속성을 바꾸면 그 값이 씬에 저장되므로). 실행 중에만 적용된다.

@export_group("제한")
## 0이면 폭 제한 없음.
@export_range(0.0, 4000.0, 1.0, "or_greater") var max_width: float = 300.0:
	set(value):
		max_width = maxf(0.0, value)
		_request_refresh()
## 0이면 높이 제한 없음.
@export_range(0.0, 4000.0, 1.0, "or_greater") var max_height: float = 0.0:
	set(value):
		max_height = maxf(0.0, value)
		_request_refresh()

var _target: Control = null
var _orig_autowrap: int = TextServer.AUTOWRAP_OFF
var _orig_min_size: Vector2 = Vector2.ZERO
var _orig_clip_text: bool = false
var _refresh_queued: bool = false


func _get_configuration_warnings() -> PackedStringArray:
	var parent := get_parent()
	if parent is Control and "text" in parent:
		return PackedStringArray()
	return PackedStringArray(["부모가 text 속성을 가진 Control(Label, CatText 등)이어야 합니다."])


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	var parent := get_parent()
	if not (parent is Control and "text" in parent):
		return
	_target = parent
	if "autowrap_mode" in _target:
		_orig_autowrap = int(_target.get("autowrap_mode"))
	_orig_min_size = _target.custom_minimum_size
	if "clip_text" in _target:
		_orig_clip_text = bool(_target.get("clip_text"))
	_target.minimum_size_changed.connect(_request_refresh)
	if _target.has_signal("reshaped"):
		_target.connect("reshaped", _request_refresh)
	_request_refresh()


func _exit_tree() -> void:
	if _target == null or not is_instance_valid(_target):
		_target = null
		return
	_target.minimum_size_changed.disconnect(_request_refresh)
	if _target.has_signal("reshaped"):
		_target.disconnect("reshaped", _request_refresh)
	_restore()
	_target = null


## 텍스트·폰트를 바꾼 직후 즉시 다시 계산하고 싶을 때 호출한다.
func refresh() -> void:
	_refresh_queued = false
	if _target == null or not is_instance_valid(_target):
		return
	var natural := _get_natural_size()
	var limit_width := max_width > 0.0 and natural.x >= max_width

	if limit_width:
		_set_autowrap(TextServer.AUTOWRAP_WORD_SMART)
	else:
		_set_autowrap(_orig_autowrap)
	var min_size := _orig_min_size
	if limit_width:
		min_size.x = max_width

	var limit_height := false
	if max_height > 0.0:
		var wrap_width := max_width if limit_width else -1.0
		limit_height = _get_wrapped_height(wrap_width, natural) >= max_height
	if limit_height:
		min_size.y = max_height
	if "clip_text" in _target:
		_target.set("clip_text", true if limit_height else _orig_clip_text)
	_target.custom_minimum_size = min_size


func _request_refresh() -> void:
	if _refresh_queued or _target == null:
		return
	_refresh_queued = true
	refresh.call_deferred()


func _restore() -> void:
	_set_autowrap(_orig_autowrap)
	if "clip_text" in _target:
		_target.set("clip_text", _orig_clip_text)
	_target.custom_minimum_size = _orig_min_size


func _set_autowrap(mode: int) -> void:
	if "autowrap_mode" in _target and int(_target.get("autowrap_mode")) != mode:
		_target.set("autowrap_mode", mode)


## 줄바꿈 없는 자연 크기(번역·대문자 반영).
func _get_natural_size() -> Vector2:
	if _target.has_method("get_natural_size"):
		return _target.call("get_natural_size")
	return _measure(-1.0)


## 실제 표시 문자열. CatText는 자체 결과를, Label은 같은 규칙(atr + uppercase)으로 만든다.
func _display_text() -> String:
	if _target.has_method("get_display_text"):
		return _target.call("get_display_text")
	var t := _target.atr(str(_target.get("text")))
	if "uppercase" in _target and bool(_target.get("uppercase")):
		t = t.to_upper()
	return t


## width <= 0이면 줄바꿈 없이, 아니면 해당 폭으로 줄바꿈한 높이.
func _get_wrapped_height(width: float, natural: Vector2) -> float:
	if width <= 0.0:
		return natural.y
	return _measure(width).y


func _measure(width: float) -> Vector2:
	var para := TextParagraph.new()
	para.break_flags = TextServer.BREAK_MANDATORY
	if width > 0.0:
		para.break_flags |= TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	para.width = width
	para.line_spacing = _resolve_line_spacing()
	var text := _display_text()
	var font := _resolve_font()
	var font_size := _resolve_font_size()
	if text.is_empty() or font == null:
		return Vector2(0.0, font.get_height(font_size) if font != null else 0.0)
	para.add_string(text, font, font_size)
	return para.get_size()


func _resolve_line_spacing() -> float:
	if "line_spacing" in _target:
		return float(_target.get("line_spacing"))
	if "label_settings" in _target:
		var settings: LabelSettings = _target.get("label_settings")
		if settings != null:
			return settings.line_spacing
	return float(_target.get_theme_constant("line_spacing", "Label"))


func _resolve_font() -> Font:
	var font: Font = null
	if "font" in _target:
		font = _target.get("font")
	# Label은 label_settings가 있으면 그 폰트가 테마보다 우선한다.
	if font == null and "label_settings" in _target:
		var settings: LabelSettings = _target.get("label_settings")
		if settings != null:
			font = settings.font
	if font == null:
		font = _target.get_theme_font("font", "Label")
	return font


func _resolve_font_size() -> int:
	var font_size := 0
	if "font_size" in _target:
		font_size = int(_target.get("font_size"))
	if font_size <= 0 and "label_settings" in _target:
		var settings: LabelSettings = _target.get("label_settings")
		if settings != null:
			font_size = settings.font_size
	if font_size <= 0:
		font_size = _target.get_theme_font_size("font_size", "Label")
	return font_size
