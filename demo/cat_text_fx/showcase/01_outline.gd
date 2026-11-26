extends "res://demo/cat_text_fx/showcase/showcase_base.gd"

const DURATION := 7.0
# 색·두께·소프트니스 변형(단계 전환만, 프레임마다 바꾸지 않는다)
const _VARIANTS := [
	[Color("37e6ff"), 0.12, 0.0],
	[Color("37e6ff"), 0.30, 0.0],
	[Color("ff4fd8"), 0.22, 0.7],
	[Color("ffd23f"), 0.18, 0.0],
]

var _ol: CatTextOutline


func _build() -> void:
	caption_text = "외곽선 (Outline)"
	var ct := make_text("OUTLINE 외곽선", 120, 220)
	_ol = CatTextOutline.new()
	ct.add_child(_ol)


func _step(_time: float) -> void:
	var s := stage("v", [1.75, 3.5, 5.25])
	if s.changed:
		var v: Array = _VARIANTS[s.index]
		_ol.set_outline(v[0], v[1], v[2])
		set_info("underlay_dilate=%.2f   underlay_softness=%.1f   underlay_color=%s" % [v[1], v[2], hex(v[0])])
