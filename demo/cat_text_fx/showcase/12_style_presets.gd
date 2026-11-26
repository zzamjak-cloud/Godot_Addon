extends "res://demo/cat_text_fx/showcase/showcase_base.gd"

const DURATION := 8.0
const _PRESETS := ["Desc_Black", "Desc_Black_Shadow", "Title_Extrude_Brown", "Title_Out1_Purple_Shadow", "Title_Out2_Red_Shadow", "Glow_Green"]

var _ct: CatText
var _fx: Node


func _build() -> void:
	caption_text = "스타일 프리셋 (번들 6종)"
	bg_color = Color(0.3, 0.32, 0.38)
	_ct = make_text("STYLE 스타일 프리셋", 100, 220)


func _step(_time: float) -> void:
	var s := stage("v", [1.33, 2.66, 4.0, 5.33, 6.66])
	if not s.changed:
		return
	var name: String = _PRESETS[s.index]
	var p: CatTextStylePreset = load("res://addons/cat_text_fx/presets/style/%s.tres" % name)
	# 효과 종류가 달라지므로 이전 노드를 지우고 새로 붙인다.
	if _fx != null:
		_ct.remove_child(_fx)
		_fx.queue_free()
	if p.effect_type == CatTextStylePreset.EffectType.GLOW:
		_fx = CatTextGlow.new()
	else:
		_fx = CatTextOutline.new()
	_ct.add_child(_fx)
	_fx.apply_preset(p)
	set_info("%s.tres  -  %s" % [name, p.description])
