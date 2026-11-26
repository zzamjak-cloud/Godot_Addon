extends "res://demo/cat_text_fx/showcase/showcase_base.gd"

const DURATION := 7.0

var _glow: CatTextGlow


func _build() -> void:
	caption_text = "글로우 (Glow)"
	var ct := make_text("GLOW 글로우", 130, 220)
	_glow = CatTextGlow.new()
	ct.add_child(_glow)


func _step(time: float) -> void:
	if time < 4.0:
		# 색만 바꾼다(범위는 고정)
		_glow.glow_color = Color.from_hsv(fmod(time * 0.25, 1.0), 0.75, 1.0, 0.6)
		_glow.glow_range = 0.3
		_glow.inner_glow_alpha = 1.0
		set_info("glow_color=%s  glow_range=0.30  (색 변화)" % hex(_glow.glow_color))
		return
	var s := stage("v", [5.5])
	if s.changed:
		_glow.glow_color = Color(0.2, 0.9, 1.0, 0.6)
		_glow.glow_range = 0.3
		_glow.inner_glow_alpha = 0.0 if s.index == 0 else 1.0
		_glow.face_dilate = 0.0 if s.index == 0 else 0.05
		set_info("inner_glow_alpha=%.1f  face_dilate=%.2f  glow_range=0.30" % [_glow.inner_glow_alpha, _glow.face_dilate])
