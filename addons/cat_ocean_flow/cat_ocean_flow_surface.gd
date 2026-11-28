@tool
@icon("res://addons/cat_ocean_flow/icons/cat_ocean_flow_surface.svg")
class_name CatOceanFlowSurface
extends CatOceanFlowBase
## 바다·호수용 물 표면(Unity OceanFlowSurface). XZ 평면 그리드 메쉬를 만든다.
## 큰 바다는 카메라를 따라다니는 근거리 패치 + 그 자리에 구멍을 낸 먼 바다 두 장으로 덮는다.

const GROUP := &"cat_ocean_flow_surface"

@export_group("형상")
## X 방향 크기 (월드 단위)
@export_range(0.01, 10000.0, 0.01, "or_greater") var size_x: float = 20.0:
	set(v):
		v = maxf(0.01, v)
		if size_x != v:
			size_x = v
			_changed(true)
## Z 방향 크기 (월드 단위)
@export_range(0.01, 10000.0, 0.01, "or_greater") var size_z: float = 20.0:
	set(v):
		v = maxf(0.01, v)
		if size_z != v:
			size_z = v
			_changed(true)
## X 방향 분할 수. 클수록 파도가 부드러워지고 정점이 늘어난다
@export_range(1, 256) var subdiv_x: int = 24:
	set(v):
		v = clampi(v, 1, 256)
		if subdiv_x != v:
			subdiv_x = v
			_changed(true)
## Z 방향 분할 수
@export_range(1, 256) var subdiv_z: int = 24:
	set(v):
		v = clampi(v, 1, 256)
		if subdiv_z != v:
			subdiv_z = v
			_changed(true)
## 메쉬 UV 타일링. 흐름 채널 타일링과 곱해진다
@export var uv_tiling: Vector2 = Vector2.ONE:
	set(v):
		if uv_tiling != v:
			uv_tiling = v
			_changed(true)
## 가운데 비워 둘 직사각형 (월드 단위). 0 이면 없음. 근거리 패치 자리를 먼 바다에서 뺄 때 쓴다
@export var hole_size: Vector2 = Vector2.ZERO:
	set(v):
		v = v.max(Vector2.ZERO)
		if hole_size != v:
			hole_size = v
			_changed(true)
## 켜면 실행 중 카메라 아래를 따라다닌다. 노이즈 UV 는 월드에 고정되어 미끄러지지 않는다
@export var follow_camera: bool = false:
	set(v):
		if follow_camera != v:
			follow_camera = v
			_changed(false, true)
## 따라갈 카메라. 비우면 뷰포트의 현재 카메라
@export var follow_target: Camera3D:
	set(v):
		if follow_target != v:
			follow_target = v
			_changed()
## 카메라 위치 대신 카메라 중심 시선이 수면과 만나는 점을 따라간다
@export var follow_look_at: bool = true:
	set(v):
		if follow_look_at != v:
			follow_look_at = v
			_changed()
## 위치를 이 간격으로 스냅한다. 0 이면 정점 간격. 근거리 패치와 먼 바다에 같은 값을 줘야 구멍이 맞물린다
@export_range(0.0, 100.0, 0.01, "or_greater") var follow_snap: float = 0.0:
	set(v):
		v = maxf(0.0, v)
		if follow_snap != v:
			follow_snap = v
			_changed()
## 패치 가장자리에서 파도 진폭을 0 으로 줄이는 폭 (패치 크기 비율). 0 이면 끔
@export_range(0.0, 0.5) var wave_edge_fade: float = 0.0:
	set(v):
		v = clampf(v, 0.0, 0.5)
		if wave_edge_fade != v:
			wave_edge_fade = v
			_changed()

@export_group("먼 바다 동기화")
## 먼 바다용 CatOceanFlowSurface. 연결하면 이 바다의 외형 값이 복사되고
## 타일링·구멍 크기·스냅은 두 바다의 크기 비율로 계산된다. 먼 바다에서는 크기와 분할 수만 정한다
@export var far_surface: CatOceanFlowSurface:
	set(v):
		if far_surface == v:
			return
		if far_surface != null and is_instance_valid(far_surface) and far_surface._driver == self:
			far_surface._set_driver(null)
		far_surface = v
		_changed()

## 동기화가 실제로 동작하는 상태인지. 자기 자신을 참조하면 false.
var has_far_surface: bool:
	get:
		return far_surface != null and is_instance_valid(far_surface) and far_surface != self

## 먼 바다에 적용될 UV 타일링. 참조가 없으면 ZERO. 크기 비율만큼 키워 월드 무늬 크기를 맞춘다.
var synced_far_uv_tiling: Vector2:
	get:
		if not has_far_surface:
			return Vector2.ZERO
		return Vector2(uv_tiling.x * far_surface.size_x / size_x, uv_tiling.y * far_surface.size_z / size_z)

## 현재 설정으로 만들어질 정점 수(구멍 경계선 제외).
var estimated_vertex_count: int:
	get:
		return (subdiv_x + 1) * (subdiv_z + 1)

## 정점 간격 중 큰 쪽.
var vertex_spacing: float:
	get:
		return maxf(size_x / maxi(1, subdiv_x), size_z / maxi(1, subdiv_z))

## 실제로 쓰이는 스냅 간격.
var effective_snap: float:
	get:
		return follow_snap if follow_snap > 0.0 else vertex_spacing


func _init() -> void:
	super()
	# 카메라를 움직이는 스크립트(기본 우선순위 0)보다 뒤에 따라가도록 한다
	process_priority = 100


func _enter_tree() -> void:
	super()
	add_to_group(GROUP)
	set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		update_configuration_warnings()


func _process(delta: float) -> void:
	super(delta)
	if follow_camera and not Engine.is_editor_hint():
		_follow()


func _driven_properties() -> Array[StringName]:
	var list := super()
	list.append_array([&"uv_tiling", &"hole_size", &"follow_camera", &"follow_target", &"follow_look_at", &"follow_snap"])
	return list


func _validate_property(property: Dictionary) -> void:
	super(property)
	if property.name in [&"follow_target", &"follow_look_at", &"follow_snap"] and not follow_camera:
		property.usage |= PROPERTY_USAGE_READ_ONLY


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if hole_size.x >= size_x and hole_size.y >= size_z:
		warnings.append("구멍이 표면 크기 이상이라 메쉬가 통째로 비어 있습니다.")
	if estimated_vertex_count > 20000:
		warnings.append("정점 %d개: 모바일에서는 물 하나당 20,000 이하를 권장합니다." % estimated_vertex_count)
	if wave_enabled and shortest_wavelength < vertex_spacing * 4.0:
		warnings.append("가장 짧은 파장(%.2f)이 정점 간격 × 4(%.2f)보다 짧아 파도가 떨리기만 합니다. 분할을 늘리거나 파도를 끄세요." % [shortest_wavelength, vertex_spacing * 4.0])
	if far_surface == self:
		warnings.append("자기 자신을 먼 바다로 연결할 수 없습니다.")
	elif has_far_surface:
		if far_surface.size_x <= size_x or far_surface.size_z <= size_z:
			warnings.append("먼 바다가 이 바다보다 작거나 같아 구멍이 먼 바다를 통째로 비웁니다. 먼 바다를 더 크게 만드세요.")
		if far_surface.has_far_surface:
			warnings.append("먼 바다에도 먼 바다가 연결되어 있습니다. 동기화는 한 단계만 전파됩니다.")
	return warnings


#region 세트

## 카메라 추적 근거리 패치(80 m / 80분할, 정점 간격 1 m)와 구멍 낸 먼 바다(1000 m / 8분할, 파도·하이라이트 끔)를
## 동기화로 연결한 세트를 만든다. 먼 바다의 타일링·구멍·추적은 동기화가 크기 비율로 유도한다.
## 반환: 두 바다를 자식으로 가진 Node3D (트리에 넣으면 동기화가 돈다)
static func create_ocean_set() -> Node3D:
	var root := Node3D.new()
	root.name = "OceanSet"
	var near := CatOceanFlowSurface.new()
	near.name = "OceanNear"
	near.size_x = 80.0
	near.size_z = 80.0
	near.subdiv_x = 80
	near.subdiv_z = 80
	near.follow_camera = true
	near.follow_look_at = true
	near.follow_snap = 0.0
	near.wave_edge_fade = 0.15
	var far := CatOceanFlowSurface.new()
	far.name = "OceanFar"
	far.size_x = 1000.0
	far.size_z = 1000.0
	far.subdiv_x = 8
	far.subdiv_z = 8
	# 먼 바다는 정점이 드물어 파도가 떨리기만 하고 하이라이트는 보이지 않는다
	far.wave_enabled = false
	far.highlight_enabled = false
	root.add_child(near)
	root.add_child(far)
	near.far_surface = far
	near.sync_far_surface()
	return root

#endregion


#region 동기화

## 근거리 패치 설정을 먼 바다로 밀어 넣는다(외형 + 크기 비율로 유도한 타일링·구멍·추적).
## 기능 토글과 먼 바다의 크기·분할 수·가장자리 페이드는 건드리지 않는다.
func sync_far_surface() -> void:
	if not has_far_surface:
		return
	var far := far_surface
	far._set_driver(self)
	copy_synced_appearance_to(far)
	var was := far._suppress_sync
	far._suppress_sync = true
	far.uv_tiling = synced_far_uv_tiling
	far.hole_size = Vector2(size_x, size_z)
	far.follow_camera = follow_camera
	far.follow_target = follow_target
	far.follow_look_at = follow_look_at
	far.follow_snap = effective_snap
	far._suppress_sync = was
	if far._mesh_dirty:
		far.rebuild_mesh()


func _on_settings_applied() -> void:
	sync_far_surface()
	# 먼 바다의 크기·분할 수를 바꿨으면 이 바다를 참조하는 근거리 패치가 다시 유도하게 한다
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group(GROUP):
			var near := node as CatOceanFlowSurface
			if near != null and near != self and near.far_surface == self:
				near.sync_far_surface()

#endregion


#region 메쉬

func _build_mesh(target: ArrayMesh) -> void:
	var arrays := build_grid_arrays(size_x, size_z, subdiv_x, subdiv_z, uv_tiling, hole_size)
	_commit_arrays(target, arrays[0], arrays[1], arrays[2])


## XZ 평면 그리드. 원점 중앙 정렬, 위(+Y)가 앞면. 구멍 경계에는 그리드 선을 끼워 지정 크기 그대로 뚫는다.
## 반환: [PackedVector3Array 위치, PackedVector2Array UV, PackedInt32Array 인덱스]
static func build_grid_arrays(sx: float, sz: float, div_x: int, div_z: int, tiling: Vector2, hole: Vector2 = Vector2.ZERO) -> Array:
	div_x = maxi(1, div_x)
	div_z = maxi(1, div_z)
	var half_x := sx * 0.5
	var half_z := sz * 0.5
	var hole_half_x := clampf(hole.x * 0.5, 0.0, half_x)
	var hole_half_z := clampf(hole.y * 0.5, 0.0, half_z)
	var has_hole := hole_half_x > 0.0 and hole_half_z > 0.0

	var axis_x := _build_axis(-half_x, sx, div_x, hole_half_x if has_hole else -1.0)
	var axis_z := _build_axis(-half_z, sz, div_z, hole_half_z if has_hole else -1.0)
	var count_x := axis_x.size()
	var count_z := axis_z.size()

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(count_x * count_z)
	uvs.resize(count_x * count_z)
	var k := 0
	for z in count_z:
		var pz := axis_z[z]
		var tz := (pz + half_z) / sz
		for x in count_x:
			var px := axis_x[x]
			vertices[k] = Vector3(px, 0.0, pz)
			uvs[k] = Vector2((px + half_x) / sx * tiling.x, tz * tiling.y)
			k += 1

	var indices := PackedInt32Array()
	for z in count_z - 1:
		var center_z := (axis_z[z] + axis_z[z + 1]) * 0.5
		for x in count_x - 1:
			if has_hole:
				var center_x := (axis_x[x] + axis_x[x + 1]) * 0.5
				if absf(center_x) < hole_half_x and absf(center_z) < hole_half_z:
					continue
			var i := z * count_x + x
			# Godot 은 위에서 볼 때 시계 방향이 앞면이다(+Z 가 화면 아래)
			indices.append_array([i, i + 1, i + count_x, i + 1, i + count_x + 1, i + count_x])
	return [vertices, uvs, indices]


## 한 축의 정점 좌표. 균일 분할 위에 구멍 경계(±hole_half)를 끼워 넣고 정렬한다.
static func _build_axis(start: float, size: float, div: int, hole_half: float) -> PackedFloat32Array:
	var axis := PackedFloat32Array()
	var step := size / div
	for i in div + 1:
		axis.append(start + step * i)
	if hole_half > 0.0:
		_insert_axis_line(axis, -hole_half, step)
		_insert_axis_line(axis, hole_half, step)
		axis.sort()
	return axis


static func _insert_axis_line(axis: PackedFloat32Array, value: float, step: float) -> void:
	var epsilon := step * 1e-4
	for a in axis:
		if absf(a - value) < epsilon:
			return
	axis.append(value)

#endregion


#region 카메라 추적

func _apply_all_properties() -> void:
	super()
	# 정점이 드문 먼 바다는 얼룩이 정점 사이에서 선형 보간돼 각진 무늬가 되므로 끈다(근거리 패치 가장자리도 중립으로 페이드)
	if vertex_spacing > surface_breakup_scale * 0.25:
		_material.set_shader_parameter(&"breakup_params", Vector4(0.0, 1.0 / surface_breakup_scale, 0.0, 0.0))


func _apply_surface_properties(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter(&"wave_edge_fade", wave_edge_fade)
	mat.set_shader_parameter(&"uv_world_offset", build_uv_world_offset(global_position))


## 카메라 위치를 스냅 간격으로 양자화해 따라간다. 움직인 만큼 UV 를 되돌려 노이즈가 월드에 고정된다.
func _follow() -> void:
	var cam := follow_target
	if cam == null or not is_instance_valid(cam):
		cam = get_viewport().get_camera_3d()
	if cam == null:
		return
	var snap := maxf(effective_snap, 1e-3)
	var current := global_position
	var center := resolve_follow_center(cam.global_position, -cam.global_basis.z, cam.far, current.y, follow_look_at)
	var target := Vector3(roundf(center.x / snap) * snap, current.y, roundf(center.z / snap) * snap)
	if (target - current).length_squared() < 1e-8:
		return
	global_position = target
	_apply_surface_properties_now()


## 추적 중심. 시선 교차점 모드면 카메라 중심 시선이 수면 높이와 만나는 점,
## 시선이 수면을 향하지 않으면 카메라 위치로 폴백한다. 교차 거리는 far 로 자른다.
static func resolve_follow_center(origin: Vector3, forward: Vector3, far_clip: float, plane_y: float, look_at: bool) -> Vector3:
	if not look_at or forward.y > -1e-4:
		return origin
	var t := (plane_y - origin.y) / forward.y
	if t <= 0.0:
		return origin
	return origin + forward * minf(t, far_clip)


## 메쉬 UV 에 더해 월드 기준 UV(월드 좌표 / 크기 × 타일링)로 만드는 보정값. zw = 1 / 타일링.
## 메쉬 UV 는 모서리가 0 이므로 반 크기만큼도 빼 준다. 이 항이 없으면(원본) 두 바다의 반 크기 차가
## 노이즈 주기의 정수배가 아닐 때(예: 80 m ↔ 1000 m) 이음매에서 무늬가 어긋난다.
## 카메라 추적이 꺼져 있으면 xy 는 0.
func build_uv_world_offset(pos: Vector3) -> Vector4:
	var inv_x := 1.0 / uv_tiling.x if absf(uv_tiling.x) > 1e-6 else 0.0
	var inv_y := 1.0 / uv_tiling.y if absf(uv_tiling.y) > 1e-6 else 0.0
	if not follow_camera:
		return Vector4(0.0, 0.0, inv_x, inv_y)
	return Vector4((pos.x / size_x - 0.5) * uv_tiling.x, (pos.z / size_z - 0.5) * uv_tiling.y, inv_x, inv_y)

#endregion
