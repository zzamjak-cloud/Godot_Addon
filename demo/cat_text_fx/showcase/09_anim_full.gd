extends "res://demo/cat_text_fx/showcase/showcase_base.gd"

const DURATION := 8.0

var _anim: CatTextAnimation
var _play_start := -1.0
var _replay_at := -1.0
var _plays := 0


func _build() -> void:
	caption_text = "전체 시퀀스: Appear → Loop → Disappear (블렌드)"
	var ct := make_text("FULL SEQUENCE 전체 시퀀스", 84, 220)
	_anim = CatTextAnimation.new()
	_anim.play_on_ready = false
	_anim.character_delay = 0.05
	_anim.appear_position = Vector2(0, -80)
	_anim.appear_duration = 0.6
	_anim.appear_to_loop_blend = 0.2
	_anim.enable_loop = true
	_anim.loop_count = 1
	_anim.loop_type = CatTextAnimationPreset.LoopType.YOYO
	_anim.loop_position = Vector2(0, -30)
	_anim.loop_scale = Vector2(1.2, 1.2)
	_anim.loop_duration = 0.8
	_anim.loop_to_disappear_blend = 0.2
	_anim.enable_disappear = true
	_anim.disappear_position = Vector2(0, 80)
	_anim.disappear_duration = 0.6
	_anim.animation_finished.connect(_on_finished)
	ct.add_child(_anim)


func _on_finished() -> void:
	_replay_at = t + 0.8


func _step(time: float) -> void:
	if _plays == 0 and time >= 0.3:
		_start()
	elif _replay_at > 0.0 and time >= _replay_at and _plays < 2:
		_replay_at = -1.0
		_start()
	var phase := "대기"
	if _play_start >= 0.0:
		phase = "진행 중 (%.1fs)" % (time - _play_start)
	set_info("appear_to_loop_blend=0.2  loop_count=1 YOYO  loop_to_disappear_blend=0.2   재생 %d회차 %s" % [_plays, phase])


func _start() -> void:
	_plays += 1
	_play_start = t
	_anim.restart()
