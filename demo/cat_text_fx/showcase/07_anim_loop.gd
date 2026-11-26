extends "res://demo/cat_text_fx/showcase/showcase_base.gd"

const DURATION := 7.0

var _anims: Array[CatTextAnimation] = []


func _build() -> void:
	caption_text = "루프 애니메이션 (Loop): YOYO vs RESTART"
	var types := [CatTextAnimationPreset.LoopType.YOYO, CatTextAnimationPreset.LoopType.RESTART]
	var names := ["YOYO 왕복 운동", "RESTART 처음부터 반복"]
	for i in 2:
		var ct := make_text(names[i], 76, 150.0 + i * 220.0, 160.0)
		var a := CatTextAnimation.new()
		a.play_on_ready = false
		a.enable_appear = false
		a.enable_loop = true
		a.loop_count = -1
		a.loop_type = types[i]
		a.loop_position = Vector2(0, -40)
		a.loop_scale = Vector2(1.15, 1.15)
		a.loop_duration = 1.0
		a.character_delay = 0.06
		ct.add_child(a)
		_anims.append(a)


func _step(_time: float) -> void:
	var s := stage("v", [0.3])
	if s.changed and s.index == 1:
		for a in _anims:
			a.play()
		set_info("loop_type: YOYO(0→1→0)  /  RESTART(0→1 후 점프)   loop_count=-1  loop_duration=1.0")
