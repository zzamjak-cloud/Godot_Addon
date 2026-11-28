extends Node3D
## 쇼케이스 씬 공통 베이스. 데모 씬을 불러와 캡션·값 표시줄을 올리고, 시간(t)에 따라 _step을 호출한다.
## DURATION은 각 씬 스크립트의 const이며 tools/record_cat_ocean_flow.sh가 녹화 길이로 읽는다.

var caption_text := ""
var scene_path := "res://demo/cat_ocean_flow/ocean_demo.tscn"
var t := 0.0
var cam: Camera3D
var sun: DirectionalLight3D
var ocean: CatOceanFlowSurface
var river: CatOceanFlowRiver
var _info: Label
var _stage_cache := {}


func _ready() -> void:
	var inst := (load(scene_path) as PackedScene).instantiate()
	add_child(inst)
	cam = inst.get_node("Camera3D")
	sun = inst.get_node("Sun")
	ocean = inst.get_node_or_null("Ocean")
	river = inst.get_node_or_null("River")
	_build()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Apple SD Gothic Neo", "Noto Sans CJK KR", "Malgun Gothic"])
	font.font_weight = 700
	var layer := CanvasLayer.new()
	add_child(layer)
	var caption := _make_label(font, 44, Color(1, 1, 1), 28.0)
	caption.text = caption_text
	layer.add_child(caption)
	_info = _make_label(font, 26, Color(1, 0.95, 0.7), 650.0)
	layer.add_child(_info)
	_step(0.0)


## 서브클래스가 오버라이드한다. 데모 씬을 불러온 직후 한 번 호출된다.
func _build() -> void:
	pass


func _step(_time: float) -> void:
	pass


func _process(delta: float) -> void:
	t += delta
	_step(t)


func set_info(s: String) -> void:
	_info.text = s


## 시간 t가 경계 목록 중 어느 구간인지(0부터). 구간이 바뀐 첫 호출에서만 changed가 true.
func stage(key: String, bounds: Array) -> Dictionary:
	var idx := 0
	for b: float in bounds:
		if t >= b:
			idx += 1
	var changed: bool = _stage_cache.get(key, -1) != idx
	_stage_cache[key] = idx
	return {"index": idx, "changed": changed}


## 카메라를 from에 두고 at을 바라보게 한다.
func aim(from: Vector3, at: Vector3) -> void:
	cam.position = from
	cam.look_at(at)


## 0~1로 자른 구간 진행도(a초~b초).
func prog(a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


func _make_label(font: Font, font_size: int, color: Color, y: float) -> Label:
	var l := Label.new()
	l.add_theme_font_override(&"font", font)
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color(0.04, 0.1, 0.2, 0.9))
	l.add_theme_constant_override(&"outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(1280, 50)
	return l
