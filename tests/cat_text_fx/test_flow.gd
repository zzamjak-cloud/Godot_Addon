extends SceneTree
## CatMaskFlow / CatLayoutLimiter 검증. 실행: godot --headless --path . -s tests/cat_text_fx/test_flow.gd

const Flow := preload("res://addons/cat_text_fx/cat_mask_flow.gd")
const Limiter := preload("res://addons/cat_text_fx/cat_layout_limiter.gd")

var _failures: int = 0
var _turn_signals: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	# _initialize 시점의 root는 아직 트리에 완전히 들어가기 전이다.
	await process_frame
	_test_static_formulas()
	_test_text_resolution()
	await _test_sequence_flow()
	_test_turn_flow()
	_test_static_mode()
	_test_resolver_and_entries()
	_test_limiter_sync()
	await _test_limiter_signal()
	print("실패 %d건" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _near(a: float, b: float, msg: String) -> void:
	_check(absf(a - b) < 0.01, "%s (기대 %s, 실제 %s)" % [msg, b, a])


func _near_v(a: Vector2, b: Vector2, msg: String) -> void:
	_check(a.distance_to(b) < 0.01, "%s (기대 %s, 실제 %s)" % [msg, b, a])


# ───────────── 정적 공식 (원본 TMPMaskFlowTests 대응, y 아래 + 기준) ─────────────

func _test_static_formulas() -> void:
	var L := Flow.FlowDirection.LEFT
	var R := Flow.FlowDirection.RIGHT
	var T := Flow.FlowDirection.TOP
	var B := Flow.FlowDirection.BOTTOM
	_near(Flow.evaluate_travel_distance(Vector2(120, 30), L, 40.0), 160.0, "travel Left")
	_near(Flow.evaluate_travel_distance(Vector2(120, 30), T, 40.0), 70.0, "travel Top")
	_near_v(Flow.get_direction_vector(T), Vector2(0, -1), "dir Top")
	_near_v(Flow.get_direction_vector(B), Vector2(0, 1), "dir Bottom")
	_near_v(Flow.get_direction_vector(L), Vector2(-1, 0), "dir Left")
	_near_v(Flow.get_direction_vector(R), Vector2(1, 0), "dir Right")

	var sizes := PackedVector2Array([Vector2(120, 30), Vector2(240, 30), Vector2(60, 30)])
	_near(Flow.evaluate_sequence_distance(sizes, L, 40.0), 540.0, "sequence distance")
	_near(Flow.evaluate_sequence_item_offset(sizes, 0, 0, L, 40.0), 0.0, "offset 0")
	_near(Flow.evaluate_sequence_item_offset(sizes, 1, 0, L, 40.0), -220.0, "offset 1")
	_near(Flow.evaluate_sequence_item_offset(sizes, 2, 0, L, 40.0), -410.0, "offset 2")
	_near(Flow.evaluate_sequence_item_offset(sizes, 0, 1, L, 40.0), -540.0, "offset next seq")
	_near(Flow.evaluate_sequence_item_position(520.0, 0, 0, sizes, L, 40.0).x, -520.0, "seq pos first")
	_near(Flow.evaluate_sequence_item_position(520.0, 0, 1, sizes, L, 40.0).x, 20.0, "seq pos wrapped")

	_near(Flow.evaluate_flow_position(0.75, 0, Vector2(120, 30), L, 80.0, 1.0, 0.0, 40.0).x, 0.0, "delay copy0")
	_near(Flow.evaluate_flow_position(0.75, 1, Vector2(120, 30), L, 80.0, 1.0, 0.0, 40.0).x, 160.0, "delay copy1")
	_near(Flow.evaluate_flow_position(1.0, 1, Vector2(120, 30), T, 80.0, 0.0, 1.5, 40.0).y, 0.0, "interval pause")
	var without_interval := Flow.evaluate_flow_distance(2.25, Vector2(120, 30), L, 80.0, 0.0, 0.0, 40.0)
	var with_interval := Flow.evaluate_flow_distance(2.25, Vector2(120, 30), L, 80.0, 0.0, 1.5, 40.0)
	_near(with_interval, without_interval, "가로는 interval 무시")
	_near(with_interval, 180.0, "flow distance 180")
	_near(Flow.evaluate_flow_position(2.0, 1, Vector2(120, 30), L, 80.0, 0.0, 1.5, 40.0).x, 0.0, "두 복제본 교대 1")
	_near(Flow.evaluate_flow_position(4.0, 0, Vector2(120, 30), L, 80.0, 0.0, 1.5, 40.0).x, 0.0, "두 복제본 교대 2")
	_near_v(Flow.evaluate_flow_position(0.5, 0, Vector2(120, 30), T, 40.0, 0.0, 0.0, 40.0), Vector2(0, -20), "Top 방향 벡터")

	_check(Flow.uses_interval(T) and Flow.uses_interval(B) and not Flow.uses_interval(L) and not Flow.uses_interval(R), "uses_interval")
	_check(Flow.uses_sequence_flow(L) and Flow.uses_sequence_flow(R) and not Flow.uses_sequence_flow(T) and not Flow.uses_sequence_flow(B), "uses_sequence_flow")

	_check(Flow.should_use_static_flow(Vector2(101, 20), Vector2(100, 40), L), "static overflow L")
	_check(not Flow.should_use_static_flow(Vector2(99, 50), Vector2(100, 40), L), "static fit L")
	_check(Flow.should_use_static_flow(Vector2(99, 41), Vector2(100, 40), T), "static overflow T")
	_check(not Flow.should_use_static_flow(Vector2(120, 39), Vector2(100, 40), T), "static fit T")

	var content := Vector2(200, 40)
	var mask := Vector2(100, 80)
	_near_v(Flow.evaluate_static_start_position(content, mask, L, Flow.STATIC_ALIGNMENT_START), Vector2(50, 0), "static start L")
	_near_v(Flow.evaluate_static_start_position(content, mask, L, Flow.STATIC_ALIGNMENT_END), Vector2(-50, 0), "static end L")
	_near_v(Flow.evaluate_static_start_position(content, mask, L, Flow.STATIC_ALIGNMENT_CENTER), Vector2.ZERO, "static center")
	# 원본 (0, +20) → y 아래 + 기준에서는 (0, -20)
	_near_v(Flow.evaluate_static_start_position(content, mask, T, Flow.STATIC_ALIGNMENT_START), Vector2(0, -20), "static start T")
	# 텍스트가 더 큰 실제 overflow: 위쪽 변이 마스크 위쪽 변에 맞도록 아래로 이동
	_near_v(Flow.evaluate_static_start_position(Vector2(50, 100), Vector2(50, 40), T, Flow.STATIC_ALIGNMENT_START), Vector2(0, 30), "static start T overflow")

	_check(Flow.evaluate_copy_count(200.0, 540.0, 0) == 3, "copy count")
	_check(Flow.evaluate_copy_count(200.0, 540.0, 2) == 2, "copy count 제한")
	_check(Flow.evaluate_copy_count(1000.0, 100.0, 0) == 12, "copy count 큰 마스크")


func _test_text_resolution() -> void:
	_check(Flow.evaluate_text_key_index(0, 3) == 0 and Flow.evaluate_text_key_index(1, 3) == 1, "key index")
	_check(Flow.evaluate_text_key_index(3, 3) == 0 and Flow.evaluate_text_key_index(5, 3) == 2, "key index wrap")
	_check(Flow.evaluate_text_key_index(10, 0) == 0, "key index empty")
	var resolver := func(key: String) -> Variant: return "localized:" + key
	var null_resolver := func(_key: String) -> Variant: return null
	_check(Flow.resolve_text_key("ui.ready", resolver) == "localized:ui.ready", "resolve key")
	_check(Flow.resolve_text_key("ui.ready", null_resolver) == "ui.ready", "resolve key null")
	_check(Flow.resolve_text_key("ui.ready", Callable()) == "ui.ready", "resolve key 없음")
	_check(Flow.resolve_text_entry("k", "Ready", Callable()) == "Ready", "entry preview")
	_check(Flow.resolve_text_entry("k", "", Callable()) == "k", "entry key")
	_check(Flow.resolve_text_entry("k", "Ready", resolver) == "localized:k", "entry resolver 우선")
	_check(Flow.resolve_text_entry("k", "Ready", null_resolver) == "Ready", "entry null → preview")


# ───────────── 인스턴스 동작 ─────────────

func _make_flow(dir: int, entries: PackedStringArray, mask_size: Vector2, template_text: String = "Hello") -> Control:
	var flow: Control = Flow.new()
	flow.play_on_ready = false
	flow.direction = dir
	flow.text_entries = entries
	flow.size = mask_size
	var label := Label.new()
	label.text = template_text
	flow.add_child(label)
	root.add_child(flow)
	return flow


func _dispose(flow: Control) -> void:
	root.remove_child(flow)
	flow.free()


func _test_sequence_flow() -> void:
	var flow := _make_flow(Flow.FlowDirection.LEFT, PackedStringArray(["AAAA", "BB", "CCCCCC"]), Vector2(200, 40))
	flow.gap = 40.0
	flow.velocity = 100.0
	flow.delay = 0.5
	_turn_signals = 0
	flow.turn_changed.connect(func(_i: int) -> void: _turn_signals += 1)
	flow.play()

	var template: Label = flow.get_child(0)
	_check(not template.visible, "시퀀스 흐름 중 템플릿 숨김")
	var dist: float = flow.get_sequence_distance()
	var w0: float = flow.get_content(0).size.x
	var w1: float = flow.get_content(1).size.x
	var w2: float = flow.get_content(2).size.x
	_near(dist, w0 + w1 + w2 + 120.0, "시퀀스 거리 = 폭 합 + gap*3")
	_check(flow.get_content_count() == 9, "복제 수 = 항목 3 * 주기 3 (실제 %d)" % flow.get_content_count())
	_check(flow.get_content(1).get("text") == "BB", "복제본 텍스트")
	_near_v(flow.get_item_center(0), Vector2.ZERO, "시작 시 0번 항목은 마스크 중앙")

	flow.advance_flow(0.5)
	_near_v(flow.get_item_center(0), Vector2.ZERO, "delay 동안 정지")
	flow.advance_flow(1.5)
	_near(flow.get_item_center(0).x, -150.0, "1.5초 이동")
	_near(flow.get_item_center(1).x, -(-(w0 * 0.5 + 40.0 + w1 * 0.5) + 150.0), "항목1 위치")
	_near(flow.get_item_center(3).x, dist - 150.0, "다음 주기 항목0 위치")

	flow.advance_flow(dist / 100.0)
	_check(flow.get_turn_index() == 1 and _turn_signals == 1, "한 주기 후 turn_index 증가 및 시그널")
	_near(flow.get_turn_duration(), dist / 100.0, "시퀀스 턴 시간은 interval 무시")

	flow.stop()
	var before: Vector2 = flow.get_item_center(0)
	flow.advance_flow(1.0)
	_near_v(flow.get_item_center(0), before, "stop 후 정지")

	flow.max_sequence_copy_count = 2
	flow.refresh()
	_check(flow.get_content_count() == 6, "복제 수 제한 (실제 %d)" % flow.get_content_count())

	root.remove_child(flow)
	_check(template.visible, "제거 후 템플릿 복원")
	await process_frame
	_check(flow.get_child_count(true) == 1, "제거 후 내부 복제본 정리")
	flow.free()

	var single := _make_flow(Flow.FlowDirection.RIGHT, PackedStringArray(), Vector2(200, 40), "Solo")
	single.play()
	_check(single.get_content(0).get("text") == "Solo", "엔트리 없으면 템플릿 텍스트")
	_check(single.get_current_text_key() == "Solo", "현재 키 = 소스 텍스트")
	single.advance_flow(0.5)
	_near(single.get_item_center(0).x, 40.0, "Right 방향은 +x로 이동")
	_dispose(single)


func _test_turn_flow() -> void:
	var flow := _make_flow(Flow.FlowDirection.TOP, PackedStringArray(["One", "Two", "Three"]), Vector2(200, 30))
	flow.gap = 40.0
	flow.velocity = 70.0
	flow.interval = 1.5
	flow.play()
	_check(flow.get_content_count() == 2, "턴 흐름 복제본 2개")
	var h0: float = flow.get_content(0).size.y
	var travel := h0 + 40.0
	var move_duration := travel / 70.0
	_near(flow.get_turn_duration(), move_duration + 1.5, "턴 시간 = 이동 + interval")
	_near_v(flow.get_item_center(0), Vector2.ZERO, "턴 시작 위치")
	_near(flow.get_item_center(1).y, travel, "다음 텍스트는 아래에서 대기")

	flow.advance_flow(0.5)
	_near(flow.get_item_center(0).y, -35.0, "Top: 위로 이동")
	_near(flow.get_item_center(1).y, -35.0 + travel, "다음 텍스트 진입")

	flow.advance_flow(move_duration)
	_near(flow.get_item_center(0).y, -travel, "interval 중 정지")
	_near(flow.get_item_center(1).y, 0.0, "다음 텍스트가 중앙")
	_check(flow.get_turn_index() == 0, "interval 동안 턴 유지")

	var arriving: Control = flow.get_content(1)
	flow.advance_flow(1.5)
	_check(flow.get_turn_index() == 1, "턴 증가")
	_check(flow.get_content(0) == arriving, "턴 전환은 텍스트 재대입 대신 복제본 순서 교체")
	_check(flow.get_content(0).get("text") == "Two" and flow.get_content(1).get("text") == "Three", "텍스트 순환 이동")
	_check(flow.get_current_text_key() == "Two", "현재 키")

	flow.advance_flow(flow.get_turn_duration() * 2.0 + 0.01)
	_check(flow.get_turn_index() == 3, "3턴")
	_check(flow.get_content(0).get("text") == "One", "엔트리 순환")

	flow.direction = Flow.FlowDirection.BOTTOM
	flow.refresh()
	flow.play()
	flow.advance_flow(0.5)
	_near(flow.get_item_center(0).y, 35.0, "Bottom: 아래로 이동")
	_dispose(flow)


func _test_static_mode() -> void:
	var flow := _make_flow(Flow.FlowDirection.LEFT, PackedStringArray(), Vector2(400, 40), "Hi")
	flow.static_mode = true
	flow.play()
	var template: Label = flow.get_child(0)
	_check(not flow.is_flow_active(), "맞으면 정지")
	_check(template.visible and flow.get_content_count() == 0, "맞으면 템플릿 표시, 복제 없음")

	template.text = "W".repeat(120)
	template.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	flow.advance_flow(0.0)
	_check(flow.is_flow_active(), "넘치면 흐름 전환")
	_check(not template.visible and flow.get_content_count() > 0, "넘치면 템플릿 숨김, 복제 생성")
	var width: float = flow.get_content(0).size.x
	_check(width > 400.0, "긴 텍스트 폭 > 마스크")
	_near(flow.get_flow_origin_offset().x, (width - 400.0) * 0.5, "Start 정렬 시작 오프셋")
	_near(flow.get_item_center(0).x, (width - 400.0) * 0.5, "시작 위치: 텍스트 왼쪽 변이 마스크 왼쪽 변")

	template.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	flow.refresh()
	_near(flow.get_flow_origin_offset().x, -(width - 400.0) * 0.5, "End 정렬 시작 오프셋")

	template.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flow.refresh()
	_near_v(flow.get_flow_origin_offset(), Vector2.ZERO, "Center 정렬 오프셋 0")

	template.text = "Hi"
	flow.advance_flow(0.0)
	_check(not flow.is_flow_active() and template.visible, "다시 맞으면 정지·템플릿 표시")
	_dispose(flow)


func _test_resolver_and_entries() -> void:
	var flow := _make_flow(Flow.FlowDirection.TOP, PackedStringArray(["a", "skip"]), Vector2(200, 30))
	flow.play()
	var resolver := func(key: String) -> Variant: return null if key == "skip" else "L:" + key
	flow.set_text_resolver(resolver)
	_check(flow.get_content(0).get("text") == "L:a", "resolver 적용")
	_check(flow.get_content(1).get("text") == "skip", "resolver null → key")

	flow.set_text_entries(["x", "y", "z"], true)
	_check(flow.get_content(0).get("text") == "L:x" and flow.get_turn_index() == 0, "엔트리 교체 + 재시작")
	_dispose(flow)


# ───────────── LayoutLimiter ─────────────

func _make_limited(text: String, width: float, height: float = 0.0) -> Array:
	var label := Label.new()
	label.text = text
	var limiter: Node = Limiter.new()
	limiter.max_width = width
	limiter.max_height = height
	label.add_child(limiter)
	root.add_child(label)
	return [label, limiter]


func _test_limiter_sync() -> void:
	var pair := _make_limited("Short", 300.0)
	var label: Label = pair[0]
	var limiter: Node = pair[1]
	limiter.refresh()
	_check(label.autowrap_mode == TextServer.AUTOWRAP_OFF and label.custom_minimum_size.x == 0.0, "짧은 텍스트는 그대로")

	label.text = "This is a very long line of text that should exceed the three hundred pixel limit for sure, really."
	limiter.refresh()
	_check(label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "긴 텍스트는 autowrap")
	_near(label.custom_minimum_size.x, 300.0, "긴 텍스트 최소 폭")

	label.text = "Short"
	limiter.refresh()
	_check(label.autowrap_mode == TextServer.AUTOWRAP_OFF and label.custom_minimum_size.x == 0.0, "짧아지면 복원")

	limiter.max_height = 20.0
	label.text = "This is a very long line of text that should exceed the three hundred pixel limit for sure, really."
	limiter.refresh()
	_near(label.custom_minimum_size.y, 20.0, "래핑 높이 >= max_height → 최소 높이 고정")
	_check(label.clip_text, "높이 제한 시 clip_text")

	limiter.max_height = 0.0
	limiter.refresh()
	_check(label.custom_minimum_size.y == 0.0 and not label.clip_text, "높이 제한 해제")

	limiter.refresh()
	label.remove_child(limiter)
	_check(label.autowrap_mode == TextServer.AUTOWRAP_OFF and label.custom_minimum_size == Vector2.ZERO and not label.clip_text, "노드 제거 시 복구")
	limiter.free()

	var pair2 := _make_limited("This is a very long line of text that should exceed the three hundred pixel limit for sure, really.", 300.0)
	var label2: Label = pair2[0]
	pair2[1].refresh()
	_check(label2.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "초기 긴 텍스트")
	pair2[1].free()
	_check(label2.autowrap_mode == TextServer.AUTOWRAP_OFF and label2.custom_minimum_size.x == 0.0, "free 시 복구")
	root.remove_child(label2)
	label2.free()
	root.remove_child(label)
	label.free()


func _test_limiter_signal() -> void:
	var pair := _make_limited("Short", 300.0)
	var label: Label = pair[0]
	await process_frame
	label.text = "This is a very long line of text that should exceed the three hundred pixel limit for sure, really."
	await process_frame
	await process_frame
	_check(label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "텍스트 변경 신호로 자동 갱신")
	label.text = "Short"
	await process_frame
	await process_frame
	_check(label.autowrap_mode == TextServer.AUTOWRAP_OFF, "자동 복원")
	root.remove_child(label)
	label.free()
