extends SceneTree
## CatOceanFlow 헤드리스 검증. 원본 FlowChannelTests·OceanFlowPathTests 핵심과 메쉬·동기화·복제를 확인한다.
## 실행: $GODOT --headless --path . -s tests/cat_ocean_flow/test_ocean_flow.gd  (실패 시 종료 코드 1)

var _failures := 0
var _checks := 0


func _initialize() -> void:
	_test_flow_channel()
	_test_churn()
	_test_grid()
	_test_path()
	_test_ribbon()
	await _test_far_sync()
	await _test_river_chain()
	await _test_duplicate_independence()
	_test_scene_storage()
	print("검사 %d개, 실패 %d개" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("실패: ", msg)


func _near(a: float, b: float, eps: float, msg: String) -> void:
	_check(absf(a - b) <= eps, "%s (기대 %f, 실제 %f)" % [msg, b, a])


#region 흐름 채널

func _loop(ease_type: int = CatEase.Type.LINEAR) -> CatFlowChannel:
	var ch := CatFlowChannel.create_default(Vector2(1, 0), 0.5)
	ch.ease = ease_type
	return ch


func _ping_pong(ease_type: int = CatEase.Type.LINEAR) -> CatFlowChannel:
	var ch := CatFlowChannel.create_default(Vector2(0, 1), 2.0)
	ch.mode = CatFlowChannel.Mode.PING_PONG
	ch.range = 0.25
	ch.ease = ease_type
	return ch


func _test_flow_channel() -> void:
	var ch := _loop()
	var prev := -INF
	var monotonic := true
	for i in 201:
		var v := CatFlowChannel.evaluate(ch, i * 0.05).x
		if v < prev - 1e-5:
			monotonic = false
		prev = v
	_check(monotonic, "Loop 은 단조 증가해야 한다")

	ch = _loop(CatEase.Type.IN_OUT_CUBIC)
	_near(CatFlowChannel.evaluate(ch, 2.0 - 1e-4).x, CatFlowChannel.evaluate(ch, 2.0 + 1e-4).x, 1e-2, "Loop 사이클 경계 연속")

	ch = _loop()
	_near(CatFlowChannel.evaluate(ch, 2.0).x - CatFlowChannel.evaluate(ch, 0.0).x, 1.0, 1e-4, "Loop 한 사이클 = 1 UV")

	ch = _ping_pong()
	var inside := true
	for i in 401:
		var v := CatFlowChannel.evaluate(ch, i * 0.02).y
		if v < -1e-5 or v > ch.range + 1e-5:
			inside = false
	_check(inside, "PingPong 은 range 안에 머문다")
	_near(CatFlowChannel.evaluate(ch, 1.0).y, ch.range, 1e-4, "PingPong 절반 주기에서 최대")
	_near(CatFlowChannel.evaluate(ch, 0.0).y, 0.0, 1e-4, "PingPong 시작 0")
	_near(CatFlowChannel.evaluate(ch, 2.0).y, 0.0, 1e-4, "PingPong 한 주기 후 0")

	ch = _ping_pong(CatEase.Type.OUT_BACK)
	var max_v := 0.0
	for i in 401:
		max_v = maxf(max_v, CatFlowChannel.evaluate(ch, i * 0.02).y)
	_check(max_v > ch.range, "OutBack 은 PingPong 범위를 넘는 오버슈트가 있다")

	ch = _loop()
	ch.speed = 0.0
	_check(CatFlowChannel.evaluate(ch, 5.0) == Vector2.ZERO, "speed 0 이면 오프셋 0")
	ch.speed = -3.0
	_check(CatFlowChannel.evaluate(ch, 5.0) == Vector2.ZERO, "speed 음수면 오프셋 0")
	ch = _loop()
	ch.direction = Vector2.ZERO
	_check(CatFlowChannel.evaluate(ch, 5.0) == Vector2.ZERO, "영벡터 방향이면 오프셋 0")

	var a := _loop()
	var b := _loop()
	b.direction = Vector2(100, 0)
	_near(CatFlowChannel.evaluate(a, 1.3).x, CatFlowChannel.evaluate(b, 1.3).x, 1e-5, "방향 길이는 무시된다")
	ch = _loop(CatEase.Type.OUT_ELASTIC)
	_check(CatFlowChannel.evaluate(ch, 3.7) == CatFlowChannel.evaluate(ch, 3.7), "같은 시간 → 같은 결과")

	# Custom: 곡선이 있으면 곡선, 없으면 선형. Custom 이 아니면 곡선을 무시한다(원본 규칙)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.5, 0.9))
	curve.add_point(Vector2(1, 1))
	ch = _loop(CatFlowChannel.EASE_CUSTOM)
	ch.custom_curve = curve
	_near(CatFlowChannel.evaluate(ch, 1.0).x, curve.sample(0.5), 1e-5, "Custom 은 곡선을 쓴다")
	ch.custom_curve = null
	_near(CatFlowChannel.evaluate(ch, 1.0).x, 0.5, 1e-5, "Custom 곡선이 없으면 선형")
	ch = _loop(CatEase.Type.LINEAR)
	ch.custom_curve = curve
	_near(CatFlowChannel.evaluate(ch, 1.0).x, 0.5, 1e-5, "Custom 이 아니면 곡선 무시")
	_near(CatFlowChannel.evaluate_ease(CatEase.Type.OUT_BACK, 1.5, null), 1.0, 1e-5, "이징 입력은 [0,1]로 잘린다")

#endregion


#region 난류

func _test_churn() -> void:
	var speed := 0.12
	# 위상 A 의 사이클 인덱스가 바뀌는 순간 A 가중치(1 - weight_b)는 0, 직전·직후 값이 연속
	var t_a := 3.0 / speed
	var before := CatOceanFlowBase.compute_churn_phase(t_a - 1e-3, speed, 0.5, 0.6, 0.0)
	var after := CatOceanFlowBase.compute_churn_phase(t_a + 1e-3, speed, 0.5, 0.6, 0.0)
	_check(before.index_a != after.index_a, "A 인덱스가 실제로 바뀌는 시각이어야 한다")
	_near(1.0 - before.weight_b, 0.0, 1e-3, "A 인덱스 전환 직전 A 가중치 0")
	_near(1.0 - after.weight_b, 0.0, 1e-3, "A 인덱스 전환 직후 A 가중치 0")
	# 위상 B 의 인덱스가 바뀌는 순간 B 가중치는 0
	var t_b := 3.5 / speed
	before = CatOceanFlowBase.compute_churn_phase(t_b - 1e-3, speed, 0.5, 0.6, 0.0)
	after = CatOceanFlowBase.compute_churn_phase(t_b + 1e-3, speed, 0.5, 0.6, 0.0)
	_check(before.index_b != after.index_b, "B 인덱스가 실제로 바뀌는 시각이어야 한다")
	_near(before.weight_b, 0.0, 1e-3, "B 인덱스 전환 직전 B 가중치 0")
	_near(after.weight_b, 0.0, 1e-3, "B 인덱스 전환 직후 B 가중치 0")
	# 채널1 은 0.37 사이클 어긋난다
	var p1 := CatOceanFlowBase.compute_churn_phase(10.0, speed, 0.5, 0.6, CatOceanFlowBase.CHANNEL1_CHURN_PHASE)
	var p0 := CatOceanFlowBase.compute_churn_phase(10.0 + 0.37 / speed, speed, 0.5, 0.6, 0.0)
	_near(p1.weight_b, p0.weight_b, 1e-4, "채널1 위상 0.37 어긋남(가중치)")
	_check(p1.phase_a.is_equal_approx(p0.phase_a), "채널1 위상 0.37 어긋남(오프셋·회전)")
	# 해시는 [0,1), 결정적이고 64 주기로 접힌다
	var h := CatOceanFlowBase.churn_hash(5.0)
	_check(h.x >= 0.0 and h.x < 1.0 and h.y >= 0.0 and h.y < 1.0, "해시는 [0,1)")
	_check(h == CatOceanFlowBase.churn_hash(5.0) and h.is_equal_approx(CatOceanFlowBase.churn_hash(69.0)), "해시는 결정적이고 64 로 접힌다")
	# 회전은 단위 벡터, 재배치 오프셋은 jitter 배율
	var ph: Vector4 = p0.phase_a
	_near(Vector2(ph.z, ph.w).length(), 1.0, 1e-5, "회전 cos/sin 은 단위 벡터")
	var zero := CatOceanFlowBase.compute_churn_phase(10.0, speed, 0.0, 0.0, 0.0)
	_check(zero.phase_a == Vector4(0, 0, 1, 0), "jitter·회전 0 이면 단순 스크롤과 같다")

#endregion


#region 그리드

func _tri_count(arrays: Array) -> int:
	return (arrays[2] as PackedInt32Array).size() / 3


func _test_grid() -> void:
	var g := CatOceanFlowSurface.build_grid_arrays(10, 10, 10, 10, Vector2.ONE)
	_check((g[0] as PackedVector3Array).size() == 121, "구멍 없는 그리드 정점 (10+1)²")
	_check(_tri_count(g) == 200, "구멍 없는 그리드 삼각형 200")
	# 셀 경계에 맞는 구멍: 선을 끼우지 않고 가운데 4x4 셀이 빠진다
	g = CatOceanFlowSurface.build_grid_arrays(10, 10, 10, 10, Vector2.ONE, Vector2(4, 4))
	_check((g[0] as PackedVector3Array).size() == 121, "셀 경계 구멍은 정점을 늘리지 않는다")
	_check(_tri_count(g) == (100 - 16) * 2, "셀 경계 구멍 삼각형 168")
	# 셀 경계와 어긋난 구멍: 축마다 선 2개를 끼워 지정 크기 그대로 뚫는다
	g = CatOceanFlowSurface.build_grid_arrays(10, 10, 10, 10, Vector2.ONE, Vector2(3.5, 3.5))
	_check((g[0] as PackedVector3Array).size() == 13 * 13, "어긋난 구멍은 축마다 선 2개 추가")
	var min_x := INF
	for v: Vector3 in g[0]:
		if v.x > -1.76 and v.x < -1.74:
			min_x = v.x
	_near(min_x, -1.75, 1e-5, "구멍 경계 선이 정확히 -1.75")
	_check(_tri_count(g) == (12 * 12 - 4 * 4) * 2, "어긋난 구멍 삼각형 수(가운데 4x4 셀 제거)")
	# 구멍이 표면 이상이면 비어 있다
	g = CatOceanFlowSurface.build_grid_arrays(10, 10, 4, 4, Vector2.ONE, Vector2(20, 20))
	_check(_tri_count(g) == 0, "구멍이 표면 이상이면 삼각형 0")
	# UV 는 타일링을 따른다
	g = CatOceanFlowSurface.build_grid_arrays(10, 10, 2, 2, Vector2(3, 5))
	_check((g[1] as PackedVector2Array)[8].is_equal_approx(Vector2(3, 5)), "UV 끝 = 타일링")
	# 앞면이 위를 향한다(Godot 은 시계 방향이 앞면 → 위에서 본 외적의 y 가 음수)
	var verts: PackedVector3Array = g[0]
	var ids: PackedInt32Array = g[2]
	var n := (verts[ids[1]] - verts[ids[0]]).cross(verts[ids[2]] - verts[ids[0]])
	_check(n.y < 0.0, "그리드 감는 순서가 Godot 앞면(위)")
	var s := CatOceanFlowSurface.new()
	s.size_x = 80
	s.size_z = 40
	s.subdiv_x = 80
	s.subdiv_z = 20
	_check(s.estimated_vertex_count == 81 * 21, "estimated_vertex_count")
	_near(s.vertex_spacing, 2.0, 1e-6, "vertex_spacing 은 큰 쪽")
	_near(s.effective_snap, 2.0, 1e-6, "snap 0 이면 정점 간격")
	s.free()

#endregion


#region 경로

func _straight(count: int, spacing: float) -> Curve3D:
	var c := Curve3D.new()
	for i in count:
		c.add_point(Vector3(i * spacing, 0, 0), Vector3(-spacing / 3.0, 0, 0), Vector3(spacing / 3.0, 0, 0))
	return c


func _curved() -> Curve3D:
	var c := Curve3D.new()
	c.add_point(Vector3(0, 0, 0), Vector3(-2, 0, 0), Vector3(2, 0, 0))
	c.add_point(Vector3(5, 0, 5), Vector3(-2, 0, -2), Vector3(2, 0, 2))
	c.add_point(Vector3(10, 0, 0), Vector3(-2, 0, 2), Vector3(2, 0, -2))
	return c


func _square(side: float) -> Curve3D:
	var h := side / 3.0
	var c := Curve3D.new()
	c.add_point(Vector3(0, 0, 0), Vector3(0, 0, h), Vector3(h, 0, 0))
	c.add_point(Vector3(side, 0, 0), Vector3(-h, 0, 0), Vector3(0, 0, h))
	c.add_point(Vector3(side, 0, side), Vector3(0, 0, -h), Vector3(-h, 0, 0))
	c.add_point(Vector3(0, 0, side), Vector3(h, 0, 0), Vector3(0, 0, -h))
	return c


func _step_ratio(pos: PackedVector3Array, include_wrap: bool) -> float:
	var mn := INF
	var mx := 0.0
	for i in range(1, pos.size()):
		var d := pos[i].distance_to(pos[i - 1])
		mn = minf(mn, d)
		mx = maxf(mx, d)
	if include_wrap:
		var w := pos[pos.size() - 1].distance_to(pos[0])
		mn = minf(mn, w)
		mx = maxf(mx, w)
	return mx / mn


func _test_path() -> void:
	var p0 := Vector3(0, 0, 0)
	var c0 := Vector3(1, 2, 0)
	var c1 := Vector3(3, 2, 0)
	var p1 := Vector3(4, 0, 0)
	_check(CatOceanFlowRiver.evaluate_cubic(p0, c0, c1, p1, 0.0) == p0, "베지어 시작점")
	_check(CatOceanFlowRiver.evaluate_cubic(p0, c0, c1, p1, 1.0) == p1, "베지어 끝점")
	var t := CatOceanFlowRiver.evaluate_tangent(Vector3.ZERO, Vector3(1, 0, 0), Vector3(3, 0, 1), Vector3(4, 0, 1), 0.0).normalized()
	_near(t.dot(Vector3.RIGHT), 1.0, 1e-4, "시작 접선은 첫 핸들 방향")

	var s := CatOceanFlowRiver.resample(_straight(4, 3.0), false, 19)
	var pos: PackedVector3Array = s.positions
	_check(pos.size() == 19, "직선 재샘플 개수")
	var uniform := true
	for i in range(1, 19):
		if absf(pos[i].distance_to(pos[i - 1]) - 9.0 / 18.0) > 1e-2:
			uniform = false
	_check(uniform, "직선 재샘플 균등 간격")

	s = CatOceanFlowRiver.resample(_curved(), false, 64)
	_check(_step_ratio(s.positions, false) < 1.15, "곡선 재샘플 간격 편차 < 1.15")
	s = CatOceanFlowRiver.resample(_curved(), false, 32)
	var dist: PackedFloat32Array = s.distances
	var increasing := dist[0] == 0.0
	for i in range(1, 32):
		if dist[i] <= dist[i - 1]:
			increasing = false
	_check(increasing, "누적 거리는 0 에서 단조 증가")
	var total := CatOceanFlowRiver.measure_length(_curved(), false)
	_near(dist[31], total, total * 0.01, "누적 거리 끝 = 경로 길이")
	var unit := true
	for tv: Vector3 in s.tangents:
		if absf(tv.length() - 1.0) > 1e-3:
			unit = false
	_check(unit, "접선은 단위 벡터")

	_check((CatOceanFlowRiver.resample(null, false, 8).positions as PackedVector3Array).is_empty(), "곡선 없음 → 빈 결과")
	_check((CatOceanFlowRiver.resample(Curve3D.new(), false, 8).positions as PackedVector3Array).is_empty(), "점 0개 → 빈 결과")
	_check((CatOceanFlowRiver.resample(_straight(1, 1.0), false, 8).positions as PackedVector3Array).is_empty(), "점 1개 → 빈 결과")

	var sq := _square(12.0)
	s = CatOceanFlowRiver.resample(sq, true, 40)
	pos = s.positions
	var loop_total := CatOceanFlowRiver.measure_length(sq, true)
	_near(pos[0].distance_to(pos[39]), loop_total / 40.0, 0.05, "루프 마지막 샘플은 시작점과 한 스텝 떨어진다")
	_check((s.distances as PackedFloat32Array)[39] < loop_total, "루프 마지막 누적 거리 < 전체 길이")
	s = CatOceanFlowRiver.resample(sq, true, 64)
	_check(_step_ratio(s.positions, true) < 1.15, "루프 경로 간격(이음매 포함)이 고르다")

#endregion


#region 리본

func _test_ribbon() -> void:
	var s := CatOceanFlowRiver.resample(_straight(3, 5.0), false, 11)
	var r := CatOceanFlowRiver.build_ribbon_arrays(s.positions, s.tangents, s.distances, 4.0, null, 4, 5.0, 2.0)
	_check((r[0] as PackedVector3Array).size() == 11 * 5, "리본 정점 = 샘플 × (폭 분할 + 1)")
	_check(_tri_count(r) == 10 * 4 * 2, "리본 삼각형 수")
	var uvs: PackedVector2Array = r[1]
	_near(uvs[0].y, 2.0, 1e-5, "리본 시작 v = uv_start_v")
	_near(uvs[uvs.size() - 1].y, 2.0 + 10.0 / 5.0, 1e-4, "리본 끝 v = 시작 + 길이 / 스케일")
	var verts: PackedVector3Array = r[0]
	_near(verts[0].distance_to(verts[4]), 4.0, 1e-4, "리본 폭")
	var ids: PackedInt32Array = r[2]
	var n := (verts[ids[1]] - verts[ids[0]]).cross(verts[ids[2]] - verts[ids[0]])
	_check(n.y < 0.0, "리본 감는 순서가 Godot 앞면(위)")

	var river := CatOceanFlowRiver.new()
	_near(river.wave_a.z, 0.03, 1e-6, "새 강은 강 전용 파동 기본값")
	_check(river.curve != null and river.curve.point_count == 3, "새 강은 기본 S자 경로")
	river.rebuild_mesh()
	_check(river.estimated_vertex_count == 64 * 5, "강 estimated_vertex_count")
	_check(river.mesh.get_surface_count() == 1, "강 메쉬 생성")
	_near(river.extra_cull_margin, river.get_bounds_padding(), 1e-6, "extra_cull_margin = 진폭 합")
	var end := river.get_path_end()
	_check(end.ok and end.position == Vector3(0, 0, 16) and end.direction.is_equal_approx(Vector3(0, 0, 1)), "경로 끝 위치·방향")
	river.loop_path = true
	_check(not river.get_path_end().ok, "닫힌 물길은 끝이 없다")
	river.free()

#endregion


#region 동기화

func _test_far_sync() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var near := CatOceanFlowSurface.new()
	near.size_x = 80
	near.size_z = 80
	near.uv_tiling = Vector2(1, 1)
	near.follow_camera = true
	near.foam_color = Color.RED
	near.channel0.speed = 0.3
	var far := CatOceanFlowSurface.new()
	far.size_x = 400
	far.size_z = 400
	far.wave_enabled = false
	holder.add_child(near)
	holder.add_child(far)
	near.far_surface = far
	await process_frame
	await process_frame
	_check(far.uv_tiling.is_equal_approx(Vector2(5, 5)), "먼 바다 타일링 = 크기 비율")
	_check(far.hole_size == Vector2(80, 80), "먼 바다 구멍 = 근거리 크기")
	_check(far.follow_camera and far.follow_snap == near.effective_snap, "추적·스냅 동기화")
	_check(far.foam_color == Color.RED, "외형 값 복사")
	_near(far.channel0.speed, 0.3, 1e-6, "채널 값 복사")
	_check(far.channel0 != near.channel0, "채널은 공유하지 않고 복사")
	_check(not far.wave_enabled and near.wave_enabled, "기능 토글은 동기화하지 않는다")
	_check(far.is_driven(), "먼 바다는 구동 표시")
	# 동기화가 한 번에 가라앉아 매 프레임 다시 돌지 않는다
	await process_frame
	_check(not near._sync_dirty and not far._sync_dirty and not far._props_dirty, "동기화가 가라앉는다")
	# 먼 바다 크기를 바꾸면 근거리 패치가 다시 유도한다
	far.size_x = 800
	await process_frame
	await process_frame
	_near(far.uv_tiling.x, 10.0, 1e-5, "먼 바다 크기 변경 시 타일링 재계산")
	# 추적 중 두 바다의 노이즈 UV 가 같은 월드 점에서 같아야 이음매에서 무늬가 이어진다(반 크기 차가 비정수배여도)
	var p := Vector3(13.0, 0.0, -7.0)
	var w := 41.3
	var near_u := (w - p.x + near.size_x * 0.5) / near.size_x * near.uv_tiling.x + near.build_uv_world_offset(p).x
	var far_u := (w - p.x + far.size_x * 0.5) / far.size_x * far.uv_tiling.x + far.build_uv_world_offset(p).x
	_near(near_u, far_u, 1e-4, "근거리/먼 바다 이음매에서 월드 UV 일치")
	# 세트 생성
	var ocean_set := CatOceanFlowSurface.create_ocean_set()
	holder.add_child(ocean_set)
	var set_near := ocean_set.get_child(0) as CatOceanFlowSurface
	var set_far := ocean_set.get_child(1) as CatOceanFlowSurface
	_check(set_near.far_surface == set_far and set_far.hole_size == Vector2(80, 80), "바다 세트 연결")
	_near(set_near.vertex_spacing, 1.0, 1e-6, "바다 세트 근거리 정점 간격 1 m")
	_check(not set_far.wave_enabled and not set_far.highlight_enabled, "바다 세트 먼 바다 파도·하이라이트 끔")
	holder.queue_free()
	await process_frame


func _test_river_chain() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var a := CatOceanFlowRiver.new()
	var b := CatOceanFlowRiver.new()
	var c := CatOceanFlowRiver.new()
	holder.add_child(a)
	holder.add_child(b)
	holder.add_child(c)
	a.uv_length_scale = 4.0
	a.width = 6.0
	a.next_river = b
	b.next_river = c
	await process_frame
	await process_frame
	_near(b.uv_start_v, a.uv_end_v, 1e-5, "B 시작 v = A 끝 v")
	_near(c.uv_start_v, b.uv_end_v, 1e-5, "C 시작 v = B 끝 v (사슬 전파)")
	_near(c.width, 6.0, 1e-6, "폭이 사슬 끝까지 전파")
	_near(c.uv_length_scale, 4.0, 1e-6, "v 밀도 전파")
	_check(b.width_curve != a.width_curve, "폭 곡선은 공유하지 않고 복제")
	# A 경로가 길어지면 C 시작 v 까지 다시 계산된다
	var old_c := c.uv_start_v
	a.curve.set_point_position(2, Vector3(0, 0, 40))
	await process_frame
	await process_frame
	_check(c.uv_start_v > old_c + 0.5, "A 경로 변경 → C 시작 v 재계산")
	_near(c.uv_start_v, b.uv_end_v, 1e-5, "변경 후에도 C 시작 v = B 끝 v")
	await process_frame
	_check(not a._sync_dirty and not b._sync_dirty and not c._sync_dirty, "강 동기화가 가라앉는다")
	# 순환 연결은 시작점으로 되돌아오기 전에 멈춘다: A 는 구동되지 않고 시작 v 도 그대로
	var a_start_v := a.uv_start_v
	c.next_river = a
	a.sync_next_river()
	_check(not a.is_driven(), "순환 A→B→C→A: 시작점 A 에 값을 되써 넣지 않는다")
	_near(a.uv_start_v, a_start_v, 1e-6, "순환 A→B→C→A: A 시작 v 그대로")
	# 시작점으로 돌아오지 않는 순환(A→B→C→B)은 깊이 제한으로 멈춘다
	c.next_river = b
	a.sync_next_river()
	_check(not a.is_driven(), "순환 A→B→C→B: 깊이 제한으로 끝난다")
	c.next_river = null
	await process_frame
	# 세트 생성: 뒤 구간이 앞 구간 끝에 놓인다
	var river_set := CatOceanFlowRiver.create_river_set()
	holder.add_child(river_set)
	var first := river_set.get_child(0) as CatOceanFlowRiver
	var second := river_set.get_child(1) as CatOceanFlowRiver
	_check(first.next_river == second and second.position == Vector3(0, 0, 16), "강 세트 연결·배치")
	_near(second.uv_start_v, first.uv_end_v, 1e-5, "강 세트 시작 v")
	holder.queue_free()
	await process_frame


func _test_duplicate_independence() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var river := CatOceanFlowRiver.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(1, 1))
	river.channel0.ease = CatFlowChannel.EASE_CUSTOM
	river.channel0.custom_curve = curve
	holder.add_child(river)
	await process_frame
	var copy := river.duplicate() as CatOceanFlowRiver
	holder.add_child(copy)
	await process_frame
	_check(copy.channel0 != river.channel0, "복제 시 channel0 독립")
	_check(copy.channel1 != river.channel1, "복제 시 channel1 독립")
	_check(copy.channel0.custom_curve != river.channel0.custom_curve, "복제 시 custom_curve 독립")
	_check(copy.width_curve != river.width_curve, "복제 시 width_curve 독립")
	_check(copy.curve != river.curve, "복제 시 경로 독립")
	_check(copy.mesh != river.mesh and copy.material_override != river.material_override, "복제 시 메쉬·머티리얼 독립")
	copy.channel0.speed = 9.0
	_check(river.channel0.speed != 9.0, "복제본 수정이 원본에 번지지 않는다")
	holder.queue_free()
	await process_frame

#endregion


#region 저장

func _test_scene_storage() -> void:
	var holder := Node3D.new()
	var s := CatOceanFlowSurface.new()
	var r := CatOceanFlowRiver.new()
	holder.add_child(s)
	holder.add_child(r)
	s.owner = holder
	r.owner = holder
	s.rebuild_mesh()
	r.rebuild_mesh()
	var packed := PackedScene.new()
	packed.pack(holder)
	var path := "user://cat_ocean_flow_storage_test.tscn"
	ResourceSaver.save(packed, path)
	var text := FileAccess.get_file_as_string(path)
	_check(not text.contains("ArrayMesh") and not text.contains("ShaderMaterial"), "생성 메쉬·머티리얼은 씬에 저장되지 않는다")
	_check(text.contains("Curve3D"), "경로는 씬에 저장된다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	holder.free()

#endregion
