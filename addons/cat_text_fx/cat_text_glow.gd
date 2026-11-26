@tool
class_name CatTextGlow
extends CatTextModifier
## 글자 바깥 번짐(Glow)과 안쪽 광택(Inner Glow). 본문 글자 RGB는 glow_color RGB로 그려진다(알파는 font_color 유지).

## 지정하면 즉시 apply_to로 값을 덮어쓴다.
@export var preset: CatTextStylePreset:
	set(value):
		preset = value
		if preset != null:
			preset.apply_to(self)

@export_group("Glow")
@export var glow_color: Color = Color(1.0, 0.8, 0.0, 0.5):
	set(value):
		glow_color = value
		_notify_changed()
## 번짐 반경 배율(1.0 = CatText.GLOW_EM em).
@export_range(0.0, 1.0) var glow_range: float = 0.3:
	set(value):
		glow_range = clampf(value, 0.0, 1.0)
		_notify_changed()
@export_range(0.0, 1.0) var inner_glow_alpha: float = 1.0:
	set(value):
		inner_glow_alpha = clampf(value, 0.0, 1.0)
		_notify_changed()
## 음수(안쪽 축소)는 지원하지 않아 0으로 그린다.
@export_range(-1.0, 1.0) var face_dilate: float = 0.0:
	set(value):
		face_dilate = clampf(value, -1.0, 1.0)
		_notify_changed()

@export_group("Preset")
@export_tool_button("새 프리셋으로 저장") var save_as_new_preset_button: Callable = save_as_new_preset


func apply_preset(new_preset: CatTextStylePreset) -> void:
	preset = new_preset


func set_glow(color: Color, glow_range_value: float) -> void:
	glow_color = color
	glow_range = glow_range_value


func reset_effect() -> void:
	glow_color = Color(1.0, 0.8, 0.0, 0.5)
	glow_range = 0.3
	inner_glow_alpha = 1.0
	face_dilate = 0.0


## 현재 값을 res://cat_text_presets/<노드 이름>.tres로 저장한다. 저장한 경로를 반환(실패 시 빈 문자열).
func save_as_new_preset() -> String:
	var p := CatTextStylePreset.new()
	p.copy_from(self)
	return CatTextStylePreset.save_to_project(p, name)
