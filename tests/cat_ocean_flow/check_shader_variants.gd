extends SceneTree
## 창 모드 전용: 기능 조합 32개 전부를 화면에 보이는 메쉬에 걸어 렌더해 셰이더를 실제로 컴파일시킨다.
## 헤드리스(더미 렌더러)는 셰이더를 컴파일하지 않으므로 반드시 창 모드로 실행한다.
## 실행: $GODOT --path . -s tests/cat_ocean_flow/check_shader_variants.gd 2>&1 | grep -E "SHADER ERROR|ERROR:"

const FRAMES := 20


func _initialize() -> void:
	if RenderingServer.get_current_rendering_method() == "dummy":
		printerr("더미 렌더러에서는 셰이더가 컴파일되지 않습니다. 창 모드로 실행하세요.")
		quit(1)
		return
	var scene := Node3D.new()
	root.add_child(scene)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 30, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.current = true
	scene.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	scene.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	floor_mesh.position.y = -1.0
	scene.add_child(floor_mesh)

	# 바다 16개 + 강 16개로 32개 조합을 모두 덮는다(마스크 0~31)
	for mask in 32:
		var water: CatOceanFlowBase
		if mask < 16:
			var s := CatOceanFlowSurface.new()
			s.size_x = 5.0
			s.size_z = 5.0
			s.subdiv_x = 4
			s.subdiv_z = 4
			water = s
		else:
			var r := CatOceanFlowRiver.new()
			r.width = 3.0
			water = r
		water.wave_enabled = mask & CatOceanFlowBase.Feature.WAVE_ON != 0
		water.shore_foam_enabled = mask & CatOceanFlowBase.Feature.FOAM_SHORE != 0
		water.cell_foam_enabled = mask & CatOceanFlowBase.Feature.CELL_FOAM != 0
		water.noise_churn_enabled = mask & CatOceanFlowBase.Feature.NOISE_CHURN != 0
		water.highlight_enabled = mask & CatOceanFlowBase.Feature.SPECULAR != 0
		water.position = Vector3((mask % 8) * 6.0 - 21.0, 0.0, (mask / 8) * 6.0 - 9.0 - (8.0 if mask >= 16 else 0.0))
		if mask >= 16:
			water.scale = Vector3.ONE * 0.3
		scene.add_child(water)
	_run.call_deferred(scene)


func _run(scene: Node3D) -> void:
	for i in FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var failed := 0
	var masks := {}
	for child in scene.get_children():
		var water := child as CatOceanFlowBase
		if water == null:
			continue
		var mat := water.get_water_material()
		var mask := water.get_feature_mask()
		masks[mask] = true
		if mat.shader == null or mat.shader != CatOceanFlowBase.get_variant_shader(mask):
			printerr("마스크 %d: 셰이더가 적용되지 않았습니다" % mask)
			failed += 1
		if mat.shader.get_shader_uniform_list().is_empty():
			printerr("마스크 %d: 셰이더 uniform 이 비어 있습니다(컴파일 실패)" % mask)
			failed += 1
	if masks.size() != 32:
		printerr("조합 수가 32가 아닙니다: ", masks.size())
		failed += 1
	print("셰이더 변형 %d개 렌더 완료, 실패 %d" % [masks.size(), failed])
	quit(1 if failed > 0 else 0)
