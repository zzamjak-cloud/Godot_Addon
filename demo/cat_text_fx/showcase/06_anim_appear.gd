extends "res://demo/cat_text_fx/showcase/showcase_base.gd"

const DURATION := 7.0

var _anims: Array[CatTextAnimation] = []


func _build() -> void:
	caption_text = "등장 애니메이션 (Appear)"
	var specs := [
		["위에서 바운스", 0, Vector2(0, -120), Vector2(0.5, 0.5), 0.0, CatEase.Type.OUT_BOUNCE],
		["회전하며 확대", 1, Vector2.ZERO, Vector2(0.0, 0.0), -180.0, CatEase.Type.OUT_BACK],
		["옆에서 슬라이드", 2, Vector2(-160, 0), Vector2(1, 1), 0.0, CatEase.Type.OUT_QUAD],
	]
	for sp: Array in specs:
		var ct := make_text(sp[0], 72, 130.0 + sp[1] * 150.0, 140.0)
		var a := CatTextAnimation.new()
		a.play_on_ready = false
		a.character_delay = 0.07
		a.appear_position = sp[2]
		a.appear_scale = sp[3]
		a.appear_rotation = sp[4]
		a.appear_duration = 0.6
		a.appear_ease = sp[5]
		ct.add_child(a)
		_anims.append(a)


func _step(_time: float) -> void:
	var s := stage("v", [0.4, 3.8])
	if s.index == 0 or not s.changed:
		return
	for a in _anims:
		a.restart()
	set_info("appear_position / appear_scale / appear_rotation / appear_ease  (%s 재생)" % ("처음" if s.index == 1 else "재시작"))
