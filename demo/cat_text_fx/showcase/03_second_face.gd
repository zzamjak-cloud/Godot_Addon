extends "res://demo/cat_text_fx/showcase/showcase_base.gd"

const DURATION := 6.0

var _ol: CatTextOutline


func _build() -> void:
	caption_text = "세컨드 페이스 (Second Face)"
	var ct := make_text("SECOND FACE", 130, 220)
	_ol = CatTextOutline.new()
	_ol.set_outline(Color("1b2a6b"), 0.2)
	_ol.enable_second_face = true
	_ol.second_face_dilate = -0.1
	ct.add_child(_ol)


func _step(_time: float) -> void:
	var s := stage("v", [3.0])
	if not s.changed:
		return
	if s.index == 0:
		_ol.use_second_face_gradient = false
		_ol.second_face_color = Color("ffd23f")
		set_info("단색  second_face_color=%s  second_face_dilate=%.2f" % [hex(_ol.second_face_color), _ol.second_face_dilate])
	else:
		_ol.use_second_face_gradient = true
		_ol.second_face_gradient_top_left = Color("ff3b6b")
		_ol.second_face_gradient_top_right = Color("ffb13b")
		_ol.second_face_gradient_bottom_left = Color("7a3bff")
		_ol.second_face_gradient_bottom_right = Color("37e6ff")
		set_info("그라디언트  use_second_face_gradient=true  4코너 색  second_face_dilate=%.2f" % _ol.second_face_dilate)
