extends "res://demo/cat_text_fx/showcase/showcase_base.gd"

const DURATION := 7.0

var _anims: Array[CatTextAnimation] = []


func _build() -> void:
	caption_text = "퇴장 애니메이션 (Disappear)"
	var specs := [
		["아래로 떨어지며 사라짐", 0, Vector2(0, 120), Vector2(1, 1), 0.0, CatEase.Type.IN_BACK],
		["축소되며 사라짐", 1, Vector2.ZERO, Vector2(0, 0), 0.0, CatEase.Type.IN_BACK],
		["회전하며 사라짐", 2, Vector2(0, -40), Vector2(0.6, 0.6), 180.0, CatEase.Type.IN_QUAD],
	]
	for sp: Array in specs:
		var ct := make_text(sp[0], 72, 130.0 + sp[1] * 150.0, 140.0)
		var a := CatTextAnimation.new()
		a.play_on_ready = false
		a.enable_appear = false
		a.enable_disappear = true
		a.character_delay = 0.06
		a.disappear_position = sp[2]
		a.disappear_scale = sp[3]
		a.disappear_rotation = sp[4]
		a.disappear_alpha = 0.0
		a.disappear_duration = 0.6
		a.disappear_ease = sp[5]
		ct.add_child(a)
		_anims.append(a)


func _step(_time: float) -> void:
	var s := stage("v", [1.0, 3.8, 4.6])
	if not s.changed:
		return
	match s.index:
		1:
			for a in _anims:
				a.play()
			set_info("disappear_position / disappear_scale / disappear_rotation / disappear_alpha=0  (재생)")
		2:
			for a in _anims:
				a.stop()
			set_info("stop()  원래 표시로 복귀")
		3:
			for a in _anims:
				a.play()
			set_info("play()  다시 재생")
