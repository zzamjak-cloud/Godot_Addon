extends "res://demo/cat_text_fx/showcase/showcase_base.gd"

const DURATION := 8.0
const _BUNDLED := ["Appear_RB_Loop_1", "Description_Loop", "Preset_A", "Title_Notice_Red"]
const _FACTORIES := ["create_bounce_appear", "create_wave_loop", "create_scale_disappear", "create_rotate_appear", "create_fade_in_out"]

var _anims: Array[CatTextAnimation] = []
var _names: Array[String] = []
var _started := 0


func _build() -> void:
	caption_text = "애니메이션 프리셋 (번들 4종 + 팩토리 5종)"
	var presets: Array[CatTextAnimationPreset] = []
	for n: String in _BUNDLED:
		presets.append(load("res://addons/cat_text_fx/presets/animation/%s.tres" % n))
		_names.append(n)
	var made: Array[CatTextAnimationPreset] = [
		CatTextAnimationPreset.create_bounce_appear(),
		CatTextAnimationPreset.create_wave_loop(),
		CatTextAnimationPreset.create_scale_disappear(),
		CatTextAnimationPreset.create_rotate_appear(),
		CatTextAnimationPreset.create_fade_in_out(),
	]
	for i in made.size():
		presets.append(made[i])
		_names.append(_FACTORIES[i])
	for i in presets.size():
		var ct := make_text(_names[i].replace("create_", ""), 34, 120.0 + (i / 3) * 170.0, 110.0)
		ct.size = Vector2(400, 110)
		ct.position.x = 40.0 + (i % 3) * 410.0
		var a := CatTextAnimation.new()
		a.play_on_ready = false
		ct.add_child(a)
		a.apply_preset(presets[i])
		_anims.append(a)


func _step(time: float) -> void:
	# 0.5초 간격으로 프리셋을 하나씩 시작한다.
	var idx := int((time - 0.3) / 0.55)
	while _started <= idx and _started < _anims.size():
		_anims[_started].play()
		_started += 1
	if _started > 0:
		set_info("재생 중: %s  (%d/%d)" % [_names[_started - 1], _started, _anims.size()])
