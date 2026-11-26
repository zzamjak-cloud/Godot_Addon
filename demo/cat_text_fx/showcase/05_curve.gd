extends "res://demo/cat_text_fx/showcase/showcase_base.gd"

const DURATION := 8.0

var _curve: CatTextCurve


func _build() -> void:
	caption_text = "곡선 (Curve)"
	var ct := make_text("ARCH & WAVE 곡선 글자", 90, 220)
	_curve = CatTextCurve.new()
	ct.add_child(_curve)


func _step(time: float) -> void:
	var s := stage("v", [2.0, 4.0, 6.0, 7.0])
	if s.changed:
		match s.index:
			0:
				_curve.set_arch_curve(70.0)
			1:
				_curve.set_wave_curve(18.0, 1.5)
			3:
				_curve.rotate_along_curve = false
			4:
				_curve.rotate_along_curve = true
	if s.index == 2:
		_curve.curve_scale = 22.0 * cos((time - 4.0) * PI)
	match s.index:
		0:
			set_info("set_arch_curve(70)  curve_scale=%.0f" % _curve.curve_scale)
		1:
			set_info("set_wave_curve(18, 1.5)  curve_scale=%.0f" % _curve.curve_scale)
		2:
			set_info("curve_scale 변화  curve_scale=%.0f" % _curve.curve_scale)
		3:
			set_info("rotate_along_curve=false  (글자 회전 없음)")
		4:
			set_info("rotate_along_curve=true  (곡선 기울기를 따라 회전)")
