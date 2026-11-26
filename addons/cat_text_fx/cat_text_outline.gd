@tool
class_name CatTextOutline
extends CatTextModifier
## 외곽선(Underlay)·그림자·Face Dilate·Second Face. 부모 CatText의 자식으로 붙인다.
## 좌표는 Godot 기준(y 아래 +). 두께는 CatText.DILATE_EM, 오프셋은 CatText.UNDERLAY_OFFSET_EM 배율.

## 지정하면 즉시 apply_to로 값을 덮어쓴다.
@export var preset: CatTextStylePreset:
	set(value):
		preset = value
		if preset != null:
			preset.apply_to(self)

@export_group("Underlay")
@export var underlay_color: Color = Color.BLACK:
	set(value):
		underlay_color = value
		_notify_changed()
@export_range(0.0, 1.0) var underlay_dilate: float = 0.15:
	set(value):
		underlay_dilate = clampf(value, 0.0, 1.0)
		_notify_changed()
@export_range(-1.0, 1.0) var underlay_offset_x: float = 0.0:
	set(value):
		underlay_offset_x = clampf(value, -1.0, 1.0)
		_notify_changed()
@export_range(-1.0, 1.0) var underlay_offset_y: float = 0.0:
	set(value):
		underlay_offset_y = clampf(value, -1.0, 1.0)
		_notify_changed()
@export_range(0.0, 1.0) var underlay_softness: float = 0.0:
	set(value):
		underlay_softness = clampf(value, 0.0, 1.0)
		_notify_changed()

@export_group("Face")
## 인스펙터 표시용 토글. face_dilate는 원본처럼 이 값과 무관하게 항상 적용된다.
@export var enable_face: bool = false:
	set(value):
		enable_face = value
		_notify_changed()
## 음수(안쪽 축소)는 지원하지 않아 0으로 그린다.
@export_range(-1.0, 1.0) var face_dilate: float = 0.0:
	set(value):
		face_dilate = clampf(value, -1.0, 1.0)
		_notify_changed()

@export_group("Shadow")
@export var enable_shadow: bool = false:
	set(value):
		enable_shadow = value
		_notify_changed()
## font_size 배율(px = 값 * font_size).
@export var shadow_offset: Vector2 = Vector2(0.1, 0.1):
	set(value):
		shadow_offset = value
		_notify_changed()
@export_range(0.0, 1.0) var shadow_alpha: float = 0.5:
	set(value):
		shadow_alpha = clampf(value, 0.0, 1.0)
		_notify_changed()

@export_group("Second Face")
@export var enable_second_face: bool = false:
	set(value):
		enable_second_face = value
		_notify_changed()
@export var second_face_color: Color = Color.WHITE:
	set(value):
		second_face_color = value
		_notify_changed()
## 텍스트 블록 전체 기준 4색 보간.
@export var use_second_face_gradient: bool = false:
	set(value):
		use_second_face_gradient = value
		_notify_changed()
@export var second_face_gradient_top_left: Color = Color.WHITE:
	set(value):
		second_face_gradient_top_left = value
		_notify_changed()
@export var second_face_gradient_top_right: Color = Color.WHITE:
	set(value):
		second_face_gradient_top_right = value
		_notify_changed()
@export var second_face_gradient_bottom_left: Color = Color.WHITE:
	set(value):
		second_face_gradient_bottom_left = value
		_notify_changed()
@export var second_face_gradient_bottom_right: Color = Color.WHITE:
	set(value):
		second_face_gradient_bottom_right = value
		_notify_changed()
@export_range(-1.0, 0.0) var second_face_dilate: float = -0.1:
	set(value):
		second_face_dilate = clampf(value, -1.0, 0.0)
		_notify_changed()
@export_range(-1.0, 1.0) var second_face_offset_x: float = 0.0:
	set(value):
		second_face_offset_x = clampf(value, -1.0, 1.0)
		_notify_changed()
@export_range(-1.0, 1.0) var second_face_offset_y: float = 0.0:
	set(value):
		second_face_offset_y = clampf(value, -1.0, 1.0)
		_notify_changed()

@export_group("Preset")
@export_tool_button("새 프리셋으로 저장") var save_as_new_preset_button: Callable = save_as_new_preset


func apply_preset(new_preset: CatTextStylePreset) -> void:
	preset = new_preset


func set_outline(color: Color, width: float, softness: float = 0.0) -> void:
	underlay_color = color
	underlay_dilate = width
	underlay_offset_x = 0.0
	underlay_offset_y = 0.0
	underlay_softness = softness
	enable_shadow = false


func set_drop_shadow(color: Color, offset_x: float, offset_y: float, dilate: float = 0.1) -> void:
	underlay_color = color
	underlay_offset_x = offset_x
	underlay_offset_y = offset_y
	underlay_dilate = dilate
	underlay_softness = 0.0
	enable_shadow = false


func set_outline_with_shadow(outline_color: Color, outline_width: float, alpha: float, offset: Vector2) -> void:
	set_outline(outline_color, outline_width, 0.0)
	enable_shadow = true
	shadow_alpha = alpha
	shadow_offset = offset


func reset_effect() -> void:
	underlay_color = Color.BLACK
	underlay_dilate = 0.0
	underlay_offset_x = 0.0
	underlay_offset_y = 0.0
	underlay_softness = 0.0
	face_dilate = 0.0
	enable_shadow = false
	shadow_offset = Vector2.ZERO
	shadow_alpha = 0.0


## 현재 값을 res://cat_text_presets/<노드 이름>.tres로 저장한다. 저장한 경로를 반환(실패 시 빈 문자열).
func save_as_new_preset() -> String:
	var p := CatTextStylePreset.new()
	p.copy_from(self)
	return CatTextStylePreset.save_to_project(p, name)
