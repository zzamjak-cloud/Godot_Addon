extends SceneTree
## CatText 셰이핑·Curve 오프셋·StylePreset·변환 합성 검증. 실패 시 quit(1).
## 실행: $GODOT --headless --path . -s tests/cat_text_fx/test_text.gd

var _failures := 0
var _nodes: Array[Node] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		_failures += 1
		printerr("  FAIL ", label)


func _make_text(t: String, fs: int = 32) -> CatText:
	var ct := CatText.new()
	ct.font = ThemeDB.fallback_font
	ct.font_size = fs
	ct.text = t
	root.add_child(ct)
	_nodes.append(ct)
	return ct


func _run() -> void:
	_test_shaping()
	_test_alignment()
	_test_autowrap()
	_test_transform()
	_test_curve()
	_test_preset()
	await _test_draw_smoke()
	await _test_anim_runtime()
	await _test_anim_regressions()
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	print("test_text: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)


func _test_shaping() -> void:
	print("[shaping]")
	var ct := _make_text("Ab c\nde")
	var n := ct.get_cluster_count()
	var vis_idx := PackedInt32Array()
	for k in n:
		if ct.is_cluster_visible(k):
			vis_idx.append(ct.get_cluster_char_index(k))
	_check(vis_idx == PackedInt32Array([0, 1, 3, 5, 6]), "가시 클러스터 char_index = 원문 인덱스 [0,1,3,5,6] (got %s)" % vis_idx)
	_check(n >= 6, "공백 포함 클러스터 수 >= 6 (got %d)" % n)
	var space_found := false
	for k in n:
		if ct.get_cluster_char_index(k) == 2:
			space_found = not ct.is_cluster_visible(k)
	_check(space_found, "공백 클러스터는 비가시")
	# 2번째 줄 글자는 첫 줄보다 아래 베이스라인
	var b0 := 0.0
	var b1 := 0.0
	for k in n:
		if ct.get_cluster_char_index(k) == 0:
			b0 = ct.get_cluster_baseline(k)
		if ct.get_cluster_char_index(k) == 5:
			b1 = ct.get_cluster_baseline(k)
	_check(b1 > b0, "2번째 줄 베이스라인이 더 아래 (%.1f > %.1f)" % [b1, b0])
	var r := ct.get_cluster_rect(0)
	_check(is_equal_approx(r.position.y, ct.get_cluster_baseline(0) - r.size.y) and r.size.x > 0.0, "cluster rect = (left, baseline-ascent, advance, ascent)")
	var bounds := ct.get_text_bounds()
	_check(bounds.size.x > 0.0 and bounds.size.y > r.size.y, "text bounds는 두 줄을 포함")
	# 다국어(폴백 폰트)
	var ko := _make_text("가나 다")
	var ko_vis := 0
	for k in ko.get_cluster_count():
		if ko.is_cluster_visible(k):
			ko_vis += 1
	_check(ko_vis == 3, "한글 가시 클러스터 3개 (got %d)" % ko_vis)
	# 대문자 옵션
	var up := _make_text("abc")
	up.uppercase = true
	_check(up.get_display_text() == "ABC", "uppercase 표시 문자열")


func _test_alignment() -> void:
	print("[alignment]")
	var ct := _make_text("Hello")
	var natural := ct.get_natural_size()
	ct.size = Vector2(400.0, 200.0)
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var x_left := ct.get_cluster_rect(0).position.x
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var x_center := ct.get_cluster_rect(0).position.x
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var x_right := ct.get_cluster_rect(0).position.x
	_check(is_zero_approx(x_left), "왼쪽 정렬 x=0 (got %.2f)" % x_left)
	_check(absf(x_center - floorf((400.0 - natural.x) * 0.5)) <= 1.0, "가운데 정렬 x=(w-line)/2 (got %.2f, natural %.2f)" % [x_center, natural.x])
	_check(absf(x_right - (400.0 - natural.x)) <= 1.0, "오른쪽 정렬 x=w-line (got %.2f)" % x_right)
	ct.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var top := ct.get_cluster_rect(0).position.y
	ct.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var bottom_base := ct.get_cluster_baseline(0)
	_check(top <= 1.0 and bottom_base > 150.0, "수직 정렬 top/bottom (top %.1f, bottom baseline %.1f)" % [top, bottom_base])


func _test_autowrap() -> void:
	print("[autowrap]")
	var ct := _make_text("alpha beta gamma delta epsilon")
	var natural := ct.get_natural_size()
	var min_off := ct.get_minimum_size()
	_check(natural.x > 100.0 and min_off.is_equal_approx(natural), "autowrap OFF: 최소 크기 = 자연 크기 (%s)" % min_off)
	ct.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ct.size = Vector2(120.0, 10.0)
	var min_on := ct.get_minimum_size()
	_check(is_zero_approx(min_on.x), "autowrap ON: 최소 너비 0")
	_check(min_on.y > natural.y * 2.0, "autowrap ON: 래핑 높이 > 2줄 (%.1f vs 한 줄 %.1f)" % [min_on.y, natural.y])
	_check(ct.get_natural_size().is_equal_approx(natural), "autowrap ON이어도 get_natural_size는 줄바꿈 없는 크기")
	# 여러 줄: 자연 너비 = 가장 긴 줄
	var ml := _make_text("Ab c\nde")
	var max_end := 0.0
	for k in ml.get_cluster_count():
		max_end = maxf(max_end, ml.get_cluster_rect(k).end.x)
	_check(is_equal_approx(ml.get_minimum_size().x, max_end), "여러 줄 자연 너비 = 가장 긴 줄 (%.1f vs %.1f)" % [ml.get_minimum_size().x, max_end])
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD
	ml.size = Vector2(1000.0, 10.0)
	_check(is_equal_approx(ml.get_natural_size().x, max_end), "autowrap ON 여러 줄 자연 너비")
	# 폴백 폰트(한글) 높이가 최소 크기에 반영되어 아래 정렬 시 위로 넘치지 않음
	var fb := _make_text("Ab 가나")
	fb.size = fb.get_minimum_size()
	fb.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_check(fb.get_cluster_rect(0).position.y >= -0.5, "폴백 폰트 높이 포함 (top %.2f)" % fb.get_cluster_rect(0).position.y)


func _test_transform() -> void:
	print("[transform]")
	var c := Vector2(10.0, 20.0)
	var p := Vector2(3.0, -4.0)
	var s := Vector2(2.0, 0.5)
	var rot := 30.0
	var cc := Vector2(12.0, 22.0)
	var cy := -5.0
	var ca := -15.0
	var xf := CatText.compose_cluster_transform(c, p, s, rot, cc, cy, ca)
	var v := Vector2(14.0, 8.0)
	# 애니메이션: v' = S·R·(v-c) + c + p  (회전 먼저, 스케일 다음)
	var a := (v - c).rotated(deg_to_rad(rot))
	a = Vector2(a.x * s.x, a.y * s.y) + c + p
	# 곡선: v'' = R_c·(v'-cc) + cc + (0, cy)
	var expected := (a - cc).rotated(deg_to_rad(ca)) + cc + Vector2(0.0, cy)
	_check((xf * v).is_equal_approx(expected), "final = Xc * X 합성 순서 (got %s, expected %s)" % [xf * v, expected])
	# 스케일 먼저(R·S)였다면 다른 결과가 나와야 한다.
	var rs_first := Vector2((v - c).x * s.x, (v - c).y * s.y).rotated(deg_to_rad(rot)) + c + p
	var anim_only := CatText.compose_cluster_transform(c, p, s, rot, cc, 0.0, 0.0) * v
	_check(anim_only.is_equal_approx(a) and not anim_only.is_equal_approx(rs_first), "비균등 스케일: 회전 먼저·스케일 다음")
	# 회전 양수 = 화면상 시계 방향(y 아래 +): (1,0) → (0,1)
	var cw := CatText.compose_cluster_transform(Vector2.ZERO, Vector2.ZERO, Vector2.ONE, 90.0, Vector2.ZERO, 0.0, 0.0)
	_check((cw * Vector2(1.0, 0.0)).is_equal_approx(Vector2(0.0, 1.0)), "rot +90 = 시계 방향")


func _test_curve() -> void:
	print("[curve]")
	var ct := _make_text("ABCDEFGHI", 36)
	ct.size = Vector2(600.0, 100.0)
	var cv := CatTextCurve.new()
	ct.add_child(cv)
	cv.set_arch_curve(40.0)
	cv.fill_offsets(ct)
	var n := ct.get_cluster_count()
	_check(n == 9 and ct.curve_offset_y.size() == 9, "오프셋 배열 크기 = 클러스터 수")
	var min_k := 0
	var sum := 0.0
	for k in n:
		sum += ct.curve_offset_y[k]
		if ct.curve_offset_y[k] < ct.curve_offset_y[min_k]:
			min_k = k
	_check(min_k == 4, "아치 커브: 가운데 글자(4)가 가장 위 (got %d)" % min_k)
	_check(absf(sum / n) < 1e-3, "수직 중심 보정 후 평균 ≈ 0 (got %f)" % (sum / n))
	_check(ct.curve_angle[0] < 0.0 and ct.curve_angle[8] > 0.0, "왼쪽 글자 각도 음수(반시계), 오른쪽 양수 (%.2f, %.2f)" % [ct.curve_angle[0], ct.curve_angle[8]])
	_check(ct.curve_offset_y[0] > ct.curve_offset_y[4], "양 끝 글자가 가운데보다 아래")
	# 동적 스케일: 9글자, 36pt, rect 보정 없음 → 40 * 9/10 * 36/36
	var eff := cv.get_effective_curve_scale(ct)
	_check(is_equal_approx(eff, 40.0 * 0.9), "동적 스케일 = scale*chars/ref*font/ref (got %f)" % eff)
	_check(is_equal_approx(CatTextCurve.compute_effective_scale(50.0, true, 20, 10.0, 36.0, 72.0, Vector2(200, 100), Vector2(100, 50)), 50.0 * 2.0 * 2.0 * 2.0), "rect 보정 sqrt(면적비)")
	_check(is_equal_approx(CatTextCurve.compute_effective_scale(50.0, true, 10, 10.0, 36.0, 36.0, Vector2(300, 100), Vector2(150, 0)), 100.0), "rect 보정 너비비")
	_check(is_equal_approx(CatTextCurve.compute_effective_scale(50.0, false, 3, 10.0, 36.0, 72.0, Vector2.ZERO, Vector2.ZERO), 50.0), "동적 보정 OFF = curve_scale")
	# 수직 중심 보정 끔: 가운데 글자 오프셋 = -curve(0.5)*eff 근사
	cv.preserve_vertical_center = false
	cv.rotate_along_curve = false
	cv.fill_offsets(ct)
	_check(ct.curve_offset_y[0] > -0.5 * eff and ct.curve_offset_y[4] < -0.8 * eff, "보정 끔: 위쪽 = 음수 y (mid %.2f)" % ct.curve_offset_y[4])
	_check(ct.curve_angle[0] == 0.0, "rotate_along_curve 끔 → 각도 0")
	# 캐시: 같은 조건이면 배열 객체를 다시 계산하지 않고, 커브 변경 시 다시 계산
	var before := ct.curve_offset_y[4]
	cv.curve.set_point_value(1, 0.5)
	cv.fill_offsets(ct)
	_check(not is_equal_approx(before, ct.curve_offset_y[4]), "Curve.changed → 재계산")
	cv.reset_curve()
	cv.fill_offsets(ct)
	_check(is_zero_approx(ct.curve_offset_y[4]), "reset_curve → 오프셋 0")
	cv.set_wave_curve(20.0, 1.0)
	_check(cv.curve.get_point_count() == 5 and is_equal_approx(cv.curve.sample(0.25), 1.0), "set_wave_curve 키 5개, t=0.25에서 1")


func _test_preset() -> void:
	print("[preset]")
	var p := load("res://addons/cat_text_fx/presets/style/Title_Out2_Red_Shadow.tres") as CatTextStylePreset
	_check(p != null, "번들 프리셋 로드")
	if p == null:
		return
	var ol := CatTextOutline.new()
	_nodes.append(ol)
	ol.preset = p
	_check(is_equal_approx(ol.underlay_dilate, 0.657) and ol.enable_second_face and is_equal_approx(ol.second_face_offset_y, -0.05), "preset setter → apply_to")
	var copy := CatTextStylePreset.new()
	copy.copy_from(ol)
	var same := true
	for field in CatTextStylePreset._OUTLINE_FIELDS:
		if copy.get(field) != p.get(field):
			same = false
			printerr("    mismatch ", field)
	_check(same and copy.effect_type == CatTextStylePreset.EffectType.OUTLINE, "Outline apply → copy 왕복 동일")
	var g := CatTextGlow.new()
	_nodes.append(g)
	var gp := load("res://addons/cat_text_fx/presets/style/Glow_Green.tres") as CatTextStylePreset
	g.apply_preset(gp)
	_check(g.glow_color.is_equal_approx(gp.underlay_color) and is_equal_approx(g.face_dilate, 0.03), "Glow apply_to")
	var gcopy := CatTextStylePreset.new()
	gcopy.copy_from(g)
	_check(gcopy.effect_type == CatTextStylePreset.EffectType.GLOW and gcopy.underlay_softness == 1.0 and gcopy.enable_face and gcopy.underlay_color.is_equal_approx(gp.underlay_color), "Glow copy_from")
	var title := CatTextStylePreset.create_title()
	_check(title.enable_shadow and is_equal_approx(title.shadow_offset.y, 0.15), "create_title 그림자 y 아래 +")
	ol.set_outline_with_shadow(Color.RED, 0.3, 0.7, Vector2(0.0, 0.1))
	_check(ol.enable_shadow and is_equal_approx(ol.underlay_dilate, 0.3) and is_zero_approx(ol.underlay_offset_x), "set_outline_with_shadow")
	ol.underlay_dilate = 5.0
	ol.second_face_dilate = 0.5
	_check(ol.underlay_dilate == 1.0 and ol.second_face_dilate == 0.0, "범위 clamp")


func _test_draw_smoke() -> void:
	print("[draw smoke]")
	var ct := _make_text("효과 Text", 40)
	ct.size = Vector2(400.0, 80.0)
	var ol := CatTextOutline.new()
	ol.preset = load("res://addons/cat_text_fx/presets/style/Title_Out2_Red_Shadow.tres")
	ol.use_second_face_gradient = true
	ct.add_child(ol)
	var gl := CatTextGlow.new()
	ct.add_child(gl)
	var cv := CatTextCurve.new()
	ct.add_child(cv)
	ct.queue_redraw()
	await process_frame
	await process_frame
	_check(ct.curve_offset_y.size() == ct.get_cluster_count(), "그리기 후 상태 배열 크기 일치")
	_check(ct.anim_alpha.size() == ct.get_cluster_count() and ct.anim_alpha[0] == 1.0, "상태 초기화(alpha 1)")
	ct.remove_child(cv)
	cv.free()
	ct.queue_redraw()
	await process_frame
	_check(ct.curve_offset_y.size() == ct.get_cluster_count() and ct.curve_offset_y[0] == 0.0, "곡선 제거 후 오프셋 0")


func _make_anim(ct: CatText, play_on_ready: bool) -> CatTextAnimation:
	var an := CatTextAnimation.new()
	an.play_on_ready = play_on_ready
	an.character_delay = 0.0
	an.appear_ease = CatEase.Type.LINEAR
	ct.add_child(an)
	return an


# 씬 실행 후 실제 프레임(_process → _draw)을 거쳐 글자 상태와 화면 변환이 바뀌는지 확인한다.
# 타임라인 출력 배열이 CatText에 참조로 넘어간 뒤 _draw의 초기화(fill)로 0이 되던 회귀를 잡는다.
func _test_anim_runtime() -> void:
	print("[anim runtime]")
	var ct := _make_text("Move", 40)
	ct.size = Vector2(300.0, 80.0)
	var an := _make_anim(ct, true)
	an.appear_duration = 5.0
	an.appear_position = Vector2(0.0, -50.0)
	an.appear_alpha = 0.0
	for i in 10:
		await process_frame
	_check(an.is_playing and an.is_processing(), "play_on_ready로 재생·process 켜짐")
	var k := 0
	_check(ct.anim_pos.size() == ct.get_cluster_count() and ct.anim_pos[k].y < -1.0, "프레임 진행 후 anim_pos 적용 (got %s)" % [ct.anim_pos[k] if ct.anim_pos.size() > 0 else null])
	_check(an._timeline.out_pos[k].is_equal_approx(ct.anim_pos[k]) and an._timeline.out_pos[k] != Vector2.ZERO, "타임라인 출력이 _draw에서 초기화되지 않음")
	_check(ct._xf[k] != Transform2D.IDENTITY and ct._xf[k].origin.y < -1.0, "화면 변환에 애니메이션 반영 (got %s)" % ct._xf[k])
	var y0 := ct.anim_pos[k].y
	await process_frame
	await process_frame
	_check(ct.anim_pos[k].y > y0, "다음 프레임에 원위치 쪽으로 이동 (%f → %f)" % [y0, ct.anim_pos[k].y])


func _test_anim_regressions() -> void:
	print("[anim regressions]")
	# 1. 재생이 끝난 뒤 같은 문자열 재셰이핑(테마·리사이즈)에는 다시 재생하지 않는다.
	var ct := _make_text("Hello", 32)
	ct.size = Vector2(300.0, 60.0)
	var an := _make_anim(ct, true)
	an.appear_duration = 0.1
	await process_frame
	await process_frame
	an.advance(10.0)
	_check(not an.is_playing, "재생 종료")
	ct.notification(Control.NOTIFICATION_THEME_CHANGED)
	ct.get_cluster_count()
	await process_frame
	_check(not an.is_playing, "끝난 뒤 테마 변경으로 Appear 반복 안 함")

	# 2. 재부모 시 reshaped 연결이 새 부모로 옮겨진다.
	var ct2 := _make_text("Other", 32)
	ct.remove_child(an)
	ct2.add_child(an)
	_check(not ct.reshaped.is_connected(an._on_reshaped) and ct2.reshaped.is_connected(an._on_reshaped), "재부모 후 새 부모 reshaped에 연결")
	ct2.text = "Changed"
	ct2.get_cluster_count()
	_check(an.is_playing, "새 부모 텍스트 변경으로 재생")

	# 16. 일시정지 중 텍스트 변경 재시작은 일시정지를 유지한다.
	an.pause()
	ct2.text = "Paused text"
	ct2.get_cluster_count()
	_check(an.is_playing and an._paused and not an.is_processing(), "일시정지 유지(_paused=%s, processing=%s)" % [an._paused, an.is_processing()])
	an.resume()

	# 15. trigger_impact는 트리거 시점의 impact 설정을 쓴다.
	an.enable_impact = true
	an.restart()
	an.advance(10.0)
	an.impact_scale = Vector2(3.0, 3.0)
	an.impact_ease = CatEase.Type.LINEAR
	an.impact_character_delay = 0.0
	an.impact_duration = 0.2
	an.trigger_impact()
	an.advance(0.1)
	var vis := 0
	while vis < ct2.get_cluster_count() and not ct2.is_cluster_visible(vis):
		vis += 1
	_check(an._timeline.out_scale[vis].is_equal_approx(Vector2(3.0, 3.0)), "impact 정점 scale = 트리거 직전 설정 (got %s)" % an._timeline.out_scale[vis])

	# 9. play_on_ready=false: 끝난 재생의 최종 포즈(alpha 0)가 새 텍스트에 남지 않는다.
	var ct3 := _make_text("Bye!", 32)
	var an3 := _make_anim(ct3, false)
	an3.enable_appear = false
	an3.enable_disappear = true
	an3.disappear_alpha = 0.0
	an3.disappear_duration = 0.1
	an3.play()
	an3.advance(10.0)
	ct3.queue_redraw()
	await process_frame
	_check(ct3.anim_alpha[0] == 0.0, "disappear 종료 alpha 0")
	ct3.text = "Hi!!"
	await process_frame
	_check(ct3.anim_alpha.size() > 0 and ct3.anim_alpha[0] == 1.0, "텍스트 변경 후 이전 최종 포즈 미적용 (alpha %s)" % [ct3.anim_alpha[0] if ct3.anim_alpha.size() > 0 else null])

	# 12. 빈 텍스트·공백만 play()해도 animation_finished가 (지연) 발생한다.
	var finished := [0]
	an3.animation_finished.connect(func() -> void: finished[0] += 1)
	ct3.text = ""
	an3.play()
	ct3.text = "   "
	an3.play()
	_check(finished[0] == 0, "animation_finished는 지연 발생")
	await process_frame
	_check(finished[0] == 2, "빈/공백 play → animation_finished 2회 (got %d)" % finished[0])
