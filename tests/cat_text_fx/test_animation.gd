extends SceneTree
## CatEase / CatTextTimeline / CatTextAnimationPreset 헤드리스 검증. 실패가 있으면 종료 코드 1.

const EPS := 0.0001

var _fails: int = 0


func _initialize() -> void:
	_test_ease_bounds()
	_test_ease_values()
	_test_appear()
	_test_loop()
	_test_disappear_and_phases()
	_test_blend()
	_test_infinite_loop()
	_test_impact()
	_test_clamp_overshoot()
	_test_preset()
	_test_integration()
	if _fails == 0:
		print("test_animation: OK")
	else:
		printerr("test_animation: %d건 실패" % _fails)
	quit(1 if _fails > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: " + msg)


func _near(a: float, b: float, msg: String, eps: float = EPS) -> void:
	_check(absf(a - b) <= eps, "%s (기대 %f, 실제 %f)" % [msg, b, a])


# 단일 글자 타임라인을 만든다. 글자 0개 지연은 character_delay로 결정.
func _make(cfg: CatTextAnimationPreset, chars: int = 1, clamp_overshoot: bool = false) -> CatTextTimeline:
	var tl := CatTextTimeline.new()
	tl.cfg = cfg
	tl.clamp_overshoot = clamp_overshoot
	var idx := PackedInt32Array()
	var vis := PackedByteArray()
	var ctr := PackedVector2Array()
	for i in chars:
		idx.append(i)
		vis.append(1)
		ctr.append(Vector2(i * 10.0, 0))
	tl.begin(idx, vis, ctr)
	return tl


# 0.01초씩 steps번 진행(누적 오차 방지를 위해 정수 단계 사용).
func _run(tl: CatTextTimeline, steps: int) -> void:
	for i in steps:
		tl.advance(0.01)


func _base_cfg() -> CatTextAnimationPreset:
	var c := CatTextAnimationPreset.new()
	c.enable_appear = false
	c.enable_loop = false
	c.enable_disappear = false
	c.enable_impact = false
	c.character_delay = 0.0
	c.appear_ease = CatEase.Type.LINEAR
	c.loop_ease = CatEase.Type.LINEAR
	c.disappear_ease = CatEase.Type.LINEAR
	c.impact_ease = CatEase.Type.LINEAR
	return c


func _test_ease_bounds() -> void:
	for type in range(CatEase.Type.LINEAR, CatEase.Type.IN_OUT_BOUNCE + 1):
		_near(CatEase.evaluate(type, 0.0), 0.0, "ease %d t=0" % type)
		_near(CatEase.evaluate(type, 1.0), 1.0, "ease %d t=1" % type)
	_check(CatEase.Type.IN_OUT_BOUNCE == 31, "enum 마지막 값 31")
	_near(CatEase.evaluate(9999, 0.37), 0.37, "알 수 없는 type은 LINEAR")


func _test_ease_values() -> void:
	_near(CatEase.evaluate(CatEase.Type.OUT_BOUNCE, 0.5), 0.765625, "OutBounce 0.5")
	_near(CatEase.evaluate(CatEase.Type.OUT_BOUNCE, 0.9), 0.988125, "OutBounce 0.9")
	_near(CatEase.evaluate(CatEase.Type.OUT_BACK, 0.2), 0.70580224, "OutBack 0.2")
	_check(CatEase.evaluate(CatEase.Type.OUT_BACK, 0.6) > 1.09, "OutBack 오버슈트")
	_near(CatEase.evaluate(CatEase.Type.IN_OUT_ELASTIC, 0.25), 0.011969444, "InOutElastic 0.25")
	_near(CatEase.evaluate(CatEase.Type.IN_OUT_ELASTIC, 0.5), 0.5, "InOutElastic 0.5")
	_near(CatEase.evaluate(CatEase.Type.IN_OUT_ELASTIC, 0.75), 0.988030556, "InOutElastic 0.75")
	_near(CatEase.evaluate(CatEase.Type.IN_QUAD, 0.5), 0.25, "InQuad")
	_near(CatEase.evaluate(CatEase.Type.IN_OUT_CUBIC, 0.75), 0.9375, "InOutCubic")
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(1, 0.5))
	_near(CatEase.sample(CatEase.Type.OUT_BACK, curve, 1.0), 0.5, "curve가 ease보다 우선")
	_near(CatEase.sample(CatEase.Type.IN_QUAD, null, 0.5), 0.25, "curve null이면 ease")


func _test_appear() -> void:
	var c := _base_cfg()
	c.enable_appear = true
	c.appear_position = Vector2(0, -50)
	c.appear_scale = Vector2(0.5, 0.5)
	c.appear_alpha = 0.0
	c.appear_duration = 0.5
	c.character_delay = 0.1
	var tl := _make(c, 3)
	_near(tl.out_pos[0].y, -50.0, "appear 시작 전 from 상태")
	_near(tl.out_alpha[2], 0.0, "시작 전 alpha")
	_run(tl, 25)
	_near(tl.out_pos[0].y, -25.0, "글자0 appear 중간 pos")
	_near(tl.out_scale[0].x, 0.75, "글자0 appear 중간 scale")
	_near(tl.out_alpha[0], 0.5, "글자0 appear 중간 alpha")
	_near(tl.out_pos[1].y, -35.0, "글자1은 0.1초 늦게 시작")
	_near(tl.out_pos[2].y, -45.0, "글자2는 0.2초 늦게 시작")
	_run(tl, 55)
	_check(not tl.main_active, "appear만 있으면 종료")
	for i in 3:
		_near(tl.out_pos[i].y, 0.0, "종료 시 to 상태 pos %d" % i)
		_near(tl.out_scale[i].x, 1.0, "종료 시 to 상태 scale %d" % i)
		_near(tl.out_alpha[i], 1.0, "종료 시 to 상태 alpha %d" % i)
	_check(not tl.advance(0.01), "종료 후 advance는 false")


func _test_loop() -> void:
	var c := _base_cfg()
	c.enable_loop = true
	c.loop_position = Vector2(0, -20)
	c.loop_duration = 1.0
	c.loop_count = 2
	c.loop_type = CatTextAnimationPreset.LoopType.YOYO
	var tl := _make(c)
	_run(tl, 50)
	_near(tl.out_pos[0].y, -10.0, "yoyo 0.5s")
	_run(tl, 50)
	_near(tl.out_pos[0].y, -20.0, "yoyo 1.0s 정점")
	_run(tl, 50)
	_near(tl.out_pos[0].y, -10.0, "yoyo 1.5s 복귀 중")
	_run(tl, 150)
	_near(tl.out_pos[0].y, -20.0, "yoyo 3.0s 두 번째 정점")
	_run(tl, 110)
	_check(not tl.main_active, "유한 loop 종료")
	_near(tl.out_pos[0].y, 0.0, "yoyo 종료는 from 상태")

	c.loop_type = CatTextAnimationPreset.LoopType.RESTART
	tl = _make(c)
	_run(tl, 50)
	_near(tl.out_pos[0].y, -10.0, "restart 0.5s")
	_run(tl, 75)
	_near(tl.out_pos[0].y, -5.0, "restart 1.25s는 사이클 경계 뒤 다시 0에서")
	_run(tl, 100)
	_check(not tl.main_active, "restart 종료")
	_near(tl.out_pos[0].y, -20.0, "restart 종료는 to 상태")


func _test_disappear_and_phases() -> void:
	var c := _base_cfg()
	c.enable_appear = true
	c.appear_position = Vector2(0, -50)
	c.appear_duration = 0.5
	c.enable_loop = true
	c.loop_position = Vector2(0, -20)
	c.loop_duration = 1.0
	c.loop_count = 1
	c.enable_disappear = true
	c.disappear_position = Vector2(0, 50)
	c.disappear_scale = Vector2(0.5, 0.5)
	c.disappear_alpha = 0.0
	c.disappear_duration = 0.5
	var tl := _make(c)
	_run(tl, 25)
	_near(tl.out_pos[0].y, -25.0, "appear 구간(0~0.5)")
	_run(tl, 50)
	_near(tl.out_pos[0].y, -5.0, "loop는 0.5초에 시작(0.75s에서 raw=0.25)")
	_run(tl, 200)
	_near(tl.out_pos[0].y, 25.0, "disappear는 2.5초에 시작(2.75s)")
	_near(tl.out_alpha[0], 0.5, "disappear 중간 alpha")
	_run(tl, 35)
	_check(not tl.main_active, "disappear 종료")
	_near(tl.out_alpha[0], 0.0, "disappear 종료 alpha")
	_near(tl.out_pos[0].y, 50.0, "disappear 종료 pos")


func _test_blend() -> void:
	var c := _base_cfg()
	c.enable_appear = true
	c.appear_position = Vector2(0, -50)
	c.appear_duration = 0.5
	c.enable_loop = true
	c.loop_position = Vector2(0, -20)
	c.loop_duration = 1.0
	c.loop_count = 1
	var tl := _make(c)
	_run(tl, 45)
	_near(tl.out_pos[0].y, -5.0, "블렌드 없음: 0.45s는 아직 appear")
	c.appear_to_loop_blend = 0.2
	tl = _make(c)
	_run(tl, 45)
	_near(tl.out_pos[0].y, -1.0, "블렌드 0.2: loop 시작이 0.4s로 당겨짐")

	var d := _base_cfg()
	d.enable_loop = true
	d.loop_position = Vector2(0, -20)
	d.loop_duration = 1.0
	d.loop_count = 1
	d.enable_disappear = true
	d.disappear_duration = 0.5
	d.disappear_alpha = 0.0
	tl = _make(d)
	_run(tl, 195)
	_near(tl.out_alpha[0], 1.0, "블렌드 없음: 1.95s alpha는 1")
	d.loop_to_disappear_blend = 0.1
	tl = _make(d)
	_run(tl, 185)
	_near(tl.out_alpha[0], 1.0, "블렌드 0.1: 1.85s는 아직 loop")
	_run(tl, 10)
	_check(tl.out_alpha[0] < 1.0, "블렌드 0.1: 1.95s는 disappear 진행 중")
	_run(tl, 60)
	_check(not tl.main_active, "블렌드 disappear 종료")
	_near(tl.out_alpha[0], 0.0, "블렌드 disappear 종료 alpha")


func _test_infinite_loop() -> void:
	var c := _base_cfg()
	c.enable_loop = true
	c.loop_count = -1
	c.loop_position = Vector2(0, -20)
	c.enable_disappear = true
	c.disappear_alpha = 0.0
	c.disappear_duration = 0.1
	var tl := _make(c)
	_run(tl, 1500)
	_check(tl.main_active, "loop_count -1은 계속 진행")
	_near(tl.out_alpha[0], 1.0, "loop_count -1은 disappear 무시")


func _test_impact() -> void:
	var c := _base_cfg()
	c.enable_appear = true
	c.appear_position = Vector2(10, 0)
	c.appear_scale = Vector2(2, 2)
	c.appear_alpha = 1.0
	c.appear_duration = 100.0
	c.enable_impact = true
	c.impact_scale = Vector2(1.5, 1.5)
	c.impact_position = Vector2(0, -10)
	c.impact_rotation = 30.0
	c.impact_duration = 0.2
	c.impact_character_delay = 0.0
	var tl := _make(c)
	tl.advance(0.0)
	_check(tl.trigger_impact(), "impact 시작")
	_check(not tl.trigger_impact(), "impact 재생 중 재호출 무시")
	_run(tl, 5)
	_near(tl.out_pos[0].y, -5.0, "impact 상승 중간(k=0.5)", 0.01)
	_run(tl, 5)
	var base_scale := tl.out_scale[0].x / 1.5
	_check(absf(base_scale - 2.0) < 0.05, "impact scale은 곱셈(기본 scale 유지): %f" % base_scale)
	_near(tl.out_pos[0].y, -10.0, "impact 정점 pos 덧셈", 0.01)
	_near(tl.out_pos[0].x, 10.0, "impact는 기본 pos.x를 유지", 0.05)
	_near(tl.out_rot[0], 30.0, "impact 정점 rot", 0.1)
	_near(tl.out_alpha[0], 1.0, "impact는 alpha 미지원")
	_run(tl, 5)
	_near(tl.out_pos[0].y, -5.0, "impact 하강 중간(0->1->0 미러)", 0.01)
	_run(tl, 10)
	_check(not tl.impact_playing, "impact 종료")
	_near(tl.out_pos[0].y, 0.0, "impact 종료 후 오프셋 0", 0.01)
	_near(tl.out_rot[0], 0.0, "impact 종료 후 rot 0")
	# 글자 지연: 두 번째 글자는 늦게 시작
	c.impact_character_delay = 0.05
	tl = _make(c, 2)
	tl.advance(0.0)
	tl.trigger_impact()
	_run(tl, 5)
	_near(tl.out_pos[0].y, -5.0, "글자0 impact 진행", 0.01)
	_near(tl.out_pos[1].y, 0.0, "글자1은 0.05초 지연", 0.01)
	c.enable_impact = false
	tl = _make(c)
	_check(not tl.trigger_impact(), "enable_impact=false면 무시")


func _test_clamp_overshoot() -> void:
	var c := _base_cfg()
	c.enable_appear = true
	c.appear_position = Vector2(0, -100)
	c.appear_scale = Vector2.ONE
	c.appear_alpha = 1.0
	c.appear_duration = 1.0
	c.appear_ease = CatEase.Type.OUT_BACK
	var tl := _make(c, 1, false)
	_run(tl, 60)
	_check(tl.out_pos[0].y > 5.0, "clamp off: OutBack 오버슈트(y=%f)" % tl.out_pos[0].y)
	tl = _make(c, 1, true)
	_run(tl, 60)
	_near(tl.out_pos[0].y, 0.0, "clamp on: 오버슈트 제거")


func _test_preset() -> void:
	var a := CatTextAnimationPreset.new()
	var curve := Curve.new()
	a.description = "테스트"
	a.character_delay = 0.2
	a.initial_delay = 1.5
	a.pivot = Vector2(0.5, 0.5)
	a.appear_position = Vector2(3, 4)
	a.appear_rotation = 12.0
	a.appear_ease = CatEase.Type.IN_BOUNCE
	a.appear_curve = curve
	a.enable_loop = true
	a.loop_count = -1
	a.loop_type = CatTextAnimationPreset.LoopType.RESTART
	a.loop_position_curve_offset = Vector2(7, 8)
	a.enable_disappear = true
	a.disappear_alpha = 0.3
	a.enable_impact = true
	a.impact_scale = Vector2(2, 3)
	a.impact_character_delay = 0.07
	var holder := CatTextAnimationPreset.new()
	a.apply_to(holder)
	var b := CatTextAnimationPreset.new()
	b.copy_from(holder)
	for f in CatTextAnimationPreset.FIELDS:
		_check(a.get(f) == b.get(f), "프리셋 왕복 필드 " + f)
	_check(b.appear_curve == curve, "curve 참조 유지")
	# 팩토리
	_check(CatTextAnimationPreset.create_bounce_appear().appear_ease == CatEase.Type.OUT_BOUNCE, "bounce 팩토리")
	var wave := CatTextAnimationPreset.create_wave_loop()
	_check(wave.enable_loop and not wave.enable_appear and wave.loop_count == -1, "wave 팩토리")
	_check(CatTextAnimationPreset.create_scale_disappear().enable_disappear, "scale_disappear 팩토리")
	_check(CatTextAnimationPreset.create_rotate_appear().appear_rotation != 0.0, "rotate_appear 팩토리")
	_check(CatTextAnimationPreset.create_fade_in_out().enable_disappear, "fade_in_out 팩토리")
	# 번들 프리셋
	var dir := DirAccess.open("res://addons/cat_text_fx/presets/animation")
	_check(dir != null, "번들 프리셋 폴더")
	var n := 0
	if dir != null:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				var r := load("res://addons/cat_text_fx/presets/animation/" + file) as CatTextAnimationPreset
				_check(r != null, "번들 프리셋 로드 " + file)
				n += 1
	_check(n == 4, "번들 프리셋 4종(%d)" % n)
	var pa := load("res://addons/cat_text_fx/presets/animation/Preset_A.tres") as CatTextAnimationPreset
	if pa != null:
		var tl := _make(pa)
		_run(tl, 30)
		_check(tl.main_active, "Preset_A 타임라인 구동")


# CatText/CatTextModifier가 있으면 노드 필드와 프리셋 필드 이름이 일치하는지 확인한다.
func _test_integration() -> void:
	if not FileAccess.file_exists("res://addons/cat_text_fx/cat_text_modifier.gd") \
			or not FileAccess.file_exists("res://addons/cat_text_fx/cat_text.gd"):
		print("integration 생략: CatText 없음")
		return
	var anim_script: GDScript = load("res://addons/cat_text_fx/cat_text_animation.gd")
	_check(anim_script != null, "cat_text_animation.gd 로드")
	if anim_script == null:
		return
	var anim: Node = anim_script.new()
	var names := {}
	for p in anim.get_property_list():
		names[p["name"]] = true
	for f in CatTextAnimationPreset.FIELDS:
		_check(names.has(f), "CatTextAnimation에 속성 " + f)
	var src := CatTextAnimationPreset.create_bounce_appear()
	src.apply_to(anim)
	var back := CatTextAnimationPreset.new()
	back.copy_from(anim)
	for f in CatTextAnimationPreset.FIELDS:
		_check(src.get(f) == back.get(f), "노드 왕복 " + f)
	anim.free()
