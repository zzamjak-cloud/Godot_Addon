@tool
class_name CatTextStylePreset
extends Resource
## CatTextOutline / CatTextGlow 공용 스타일 프리셋. 좌표는 Godot 기준(y 아래 +).

enum EffectType { OUTLINE, GLOW }

const SAVE_DIR := "res://cat_text_presets"

@export var effect_type: EffectType = EffectType.OUTLINE
@export_multiline var description: String = ""

@export_group("Underlay")
@export var underlay_color: Color = Color.BLACK
@export_range(0.0, 1.0) var underlay_dilate: float = 0.15
@export_range(-1.0, 1.0) var underlay_offset_x: float = 0.0
@export_range(-1.0, 1.0) var underlay_offset_y: float = 0.0
@export_range(0.0, 1.0) var underlay_softness: float = 0.0

@export_group("Face")
@export var enable_face: bool = false
@export_range(-1.0, 1.0) var face_dilate: float = 0.0

@export_group("Shadow")
@export var enable_shadow: bool = false
@export var shadow_offset: Vector2 = Vector2(0.1, 0.1)
@export_range(0.0, 1.0) var shadow_alpha: float = 0.5

@export_group("Second Face")
@export var enable_second_face: bool = false
@export var second_face_color: Color = Color.WHITE
@export var use_second_face_gradient: bool = false
@export var second_face_gradient_top_left: Color = Color.WHITE
@export var second_face_gradient_top_right: Color = Color.WHITE
@export var second_face_gradient_bottom_left: Color = Color.WHITE
@export var second_face_gradient_bottom_right: Color = Color.WHITE
@export_range(-1.0, 0.0) var second_face_dilate: float = -0.1
@export_range(-1.0, 1.0) var second_face_offset_x: float = 0.0
@export_range(-1.0, 1.0) var second_face_offset_y: float = 0.0

const _OUTLINE_FIELDS: Array[StringName] = [
	&"underlay_color", &"underlay_dilate", &"underlay_offset_x", &"underlay_offset_y", &"underlay_softness",
	&"enable_face", &"face_dilate", &"enable_shadow", &"shadow_offset", &"shadow_alpha",
	&"enable_second_face", &"second_face_color", &"use_second_face_gradient",
	&"second_face_gradient_top_left", &"second_face_gradient_top_right",
	&"second_face_gradient_bottom_left", &"second_face_gradient_bottom_right",
	&"second_face_dilate", &"second_face_offset_x", &"second_face_offset_y",
]


## CatTextOutline에는 전 필드, CatTextGlow에는 color/dilate/face_dilate만 적용한다(inner_glow_alpha는 저장하지 않음).
func apply_to(node: Node) -> void:
	if node is CatTextOutline:
		for field in _OUTLINE_FIELDS:
			node.set(field, get(field))
	elif node is CatTextGlow:
		var glow := node as CatTextGlow
		glow.glow_color = underlay_color
		glow.glow_range = underlay_dilate
		glow.face_dilate = face_dilate


func copy_from(node: Node) -> void:
	if node is CatTextOutline:
		effect_type = EffectType.OUTLINE
		for field in _OUTLINE_FIELDS:
			set(field, node.get(field))
	elif node is CatTextGlow:
		var glow := node as CatTextGlow
		effect_type = EffectType.GLOW
		underlay_color = glow.glow_color
		underlay_dilate = glow.glow_range
		underlay_softness = 1.0
		underlay_offset_x = 0.0
		underlay_offset_y = 0.0
		enable_face = true
		face_dilate = glow.face_dilate
		enable_shadow = false
		enable_second_face = false
	emit_changed()


static func create_simple_outline() -> CatTextStylePreset:
	var p := CatTextStylePreset.new()
	p.underlay_color = Color.BLACK
	p.underlay_dilate = 0.15
	return p


static func create_drop_shadow() -> CatTextStylePreset:
	var p := CatTextStylePreset.new()
	p.underlay_color = Color(0.0, 0.0, 0.0, 0.5)
	p.underlay_offset_x = 0.1
	p.underlay_offset_y = 0.1
	p.underlay_dilate = 0.1
	return p


static func create_title() -> CatTextStylePreset:
	var p := CatTextStylePreset.new()
	p.underlay_color = Color(0.2, 0.1, 0.0)
	p.underlay_dilate = 0.25
	p.enable_face = true
	p.face_dilate = 0.1
	p.enable_shadow = true
	p.shadow_offset = Vector2(0.15, 0.15)
	p.shadow_alpha = 0.6
	return p


## SAVE_DIR/<file_name>.tres로 저장하고 경로를 반환한다(실패 시 빈 문자열).
static func save_to_project(p: CatTextStylePreset, file_name: String) -> String:
	var err := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if err != OK:
		push_error("CatTextStylePreset: 폴더를 만들 수 없습니다: %s" % SAVE_DIR)
		return ""
	var path := "%s/%s.tres" % [SAVE_DIR, file_name.validate_filename()]
	err = ResourceSaver.save(p, path)
	if err != OK:
		push_error("CatTextStylePreset: 저장 실패(%d): %s" % [err, path])
		return ""
	# 내보낸 게임에는 EditorInterface가 없으므로 이름으로만 접근한다.
	if Engine.is_editor_hint() and Engine.has_singleton(&"EditorInterface"):
		var fs: Object = Engine.get_singleton(&"EditorInterface").call(&"get_resource_filesystem")
		fs.call(&"scan")
	return path
