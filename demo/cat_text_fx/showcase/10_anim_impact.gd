extends "res://demo/cat_text_fx/showcase/showcase_base.gd"

const DURATION := 8.0

var _anim: CatTextAnimation
var _next_impact := 1.6
var _count := 0


func _build() -> void:
	caption_text = "임팩트 (Impact)"
	var ct := make_text("IMPACT 임팩트!", 120, 220)
	var ol := CatTextOutline.new()
	ol.set_outline(Color("b3261e"), 0.2)
	ct.add_child(ol)
	_anim = CatTextAnimation.new()
	_anim.play_on_ready = false
	_anim.appear_position = Vector2(0, -60)
	_anim.appear_duration = 0.5
	_anim.enable_loop = true
	_anim.loop_count = -1
	_anim.loop_position = Vector2(0, -12)
	_anim.loop_duration = 1.2
	_anim.enable_impact = true
	_anim.impact_scale = Vector2(1.6, 1.6)
	_anim.impact_rotation = 8.0
	_anim.impact_duration = 0.3
	_anim.impact_character_delay = 0.03
	ct.add_child(_anim)


func _step(time: float) -> void:
	if stage("p", [0.3]).changed and time >= 0.3:
		_anim.play()
	if time >= _next_impact:
		_next_impact += 1.5
		_count += 1
		_anim.trigger_impact()
	set_info("루프 중 trigger_impact() x%d   impact_scale=(1.6, 1.6)  impact_rotation=8  impact_duration=0.30" % _count)
