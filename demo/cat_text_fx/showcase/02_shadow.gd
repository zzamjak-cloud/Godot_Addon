extends "res://demo/cat_text_fx/showcase/showcase_base.gd"

const DURATION := 7.0

var _ol: CatTextOutline


func _build() -> void:
	caption_text = "그림자 (Shadow)"
	var ct := make_text("SHADOW 그림자", 120, 220)
	_ol = CatTextOutline.new()
	ct.add_child(_ol)


func _step(_time: float) -> void:
	var s := stage("v", [2.3, 4.6])
	if not s.changed:
		return
	match s.index:
		0:
			_ol.reset_effect()
			_ol.set_drop_shadow(Color(0, 0, 0, 0.85), 0.35, 0.45, 0.1)
			set_info("Underlay 드롭섀도  underlay_offset=(%.2f, %.2f)  underlay_dilate=0.10" % [_ol.underlay_offset_x, _ol.underlay_offset_y])
		1:
			_ol.reset_effect()
			_ol.underlay_dilate = 0.0
			_ol.enable_shadow = true
			_ol.shadow_alpha = 0.7
			_ol.shadow_offset = Vector2(0.08, 0.1)
			set_info("CPU shadow  enable_shadow=true  shadow_offset=(0.08, 0.10)  shadow_alpha=0.70")
		2:
			_ol.set_outline_with_shadow(Color("1b2a6b"), 0.2, 0.7, Vector2(0.1, 0.12))
			set_info("외곽선 + CPU shadow  underlay_dilate=0.20  shadow_offset=(0.10, 0.12)  shadow_alpha=0.70")
