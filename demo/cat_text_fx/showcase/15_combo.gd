extends "res://demo/cat_text_fx/showcase/showcase_base.gd"

const DURATION := 8.0

var _anim: CatTextAnimation
var _curve: CatTextCurve
var _ol: CatTextOutline
var _next_impact := 2.2
var _count := 0


func _build() -> void:
	caption_text = "조합: 외곽선 + 곡선 + 애니메이션 + 임팩트"
	var ct := make_text("COMBO 고양이 텍스트!", 100, 220)
	_ol = CatTextOutline.new()
	_ol.set_outline_with_shadow(Color("b3261e"), 0.22, 0.6, Vector2(0.06, 0.1))
	_ol.enable_second_face = true
	_ol.second_face_color = Color("ffd23f")
	_ol.second_face_dilate = -0.08
	ct.add_child(_ol)
	_curve = CatTextCurve.new()
	_curve.set_arch_curve(60.0)
	ct.add_child(_curve)
	_anim = CatTextAnimation.new()
	_anim.play_on_ready = false
	_anim.appear_position = Vector2(0, -90)
	_anim.appear_duration = 0.6
	_anim.appear_ease = CatEase.Type.OUT_BOUNCE
	_anim.enable_loop = true
	_anim.loop_count = -1
	_anim.loop_position = Vector2(0, -14)
	_anim.loop_duration = 1.1
	_anim.enable_impact = true
	_anim.impact_scale = Vector2(1.5, 1.5)
	_anim.impact_rotation = 6.0
	_anim.impact_duration = 0.3
	ct.add_child(_anim)


func _step(time: float) -> void:
	var s := stage("v", [0.3, 5.0])
	if s.changed:
		if s.index == 1:
			_anim.play()
		elif s.index == 2:
			_ol.underlay_color = Color("1b3a8f")
			_ol.second_face_color = Color("7fe8ff")
	if time >= 1.0:
		_curve.curve_scale = 60.0 * cos((time - 1.0) * 1.2)
	if time >= _next_impact:
		_next_impact += 1.4
		_count += 1
		_anim.trigger_impact()
	set_info("outline+shadow+second face  curve_scale=%.0f  loop 진행 중  trigger_impact() x%d" % [_curve.curve_scale, _count])
