@tool
@icon("res://addons/cat_ocean_flow/icons/cat_ocean_flow_river.svg")
class_name CatOceanFlowRiver
extends CatOceanFlowBase
## 강·하천용 물 표면(Unity OceanFlowRiver). Curve3D 경로를 호 길이 등간격으로 재샘플해 리본 메쉬를 만든다.
## UV 의 v 가 누적 거리에 비례하므로 굽은 물길에서도 흐름이 물길을 따라간다.
## 에디터에서는 자식 Path3D 가 같은 curve 를 공유해 Godot 의 경로 기즈모로 편집한다.

const GROUP := &"cat_ocean_flow_river"

# 세그먼트 하나를 호 길이 LUT 로 근사할 때 쓰는 분할 수
const LUT_STEPS_PER_SEGMENT := 24
# 순환이 시작점으로 돌아오지 않는 형태(A→B→C→B)를 막는 안전망
const MAX_CHAIN_DEPTH := 64

@export_group("형상")
## 베지어 경로. 점의 in/out 핸들은 점 기준 상대 오프셋이다(로컬 좌표)
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "Curve3D", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_ALWAYS_DUPLICATE) var curve: Curve3D:
	set(v):
		if curve == v:
			return
		if curve != null and curve.changed.is_connected(_on_shape_changed):
			curve.changed.disconnect(_on_shape_changed)
		curve = v
		if curve != null:
			curve.changed.connect(_on_shape_changed)
		if _edit_path != null and is_instance_valid(_edit_path) and _edit_path.curve != curve:
			_edit_path.curve = curve
		_changed(true)
## 마지막 점과 첫 점을 이어 닫힌 물길을 만든다
@export var loop_path: bool = false:
	set(v):
		if loop_path != v:
			loop_path = v
			_changed(true)
## 기본 강폭 (월드 단위)
@export_range(0.01, 1000.0, 0.01, "or_greater") var width: float = 4.0:
	set(v):
		v = maxf(0.01, v)
		if width != v:
			width = v
			_changed(true)
## 경로 진행도(0~1)에 따른 폭 배율. 1 보다 크게 하려면 곡선의 max_value 를 올린다
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "Curve", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_ALWAYS_DUPLICATE) var width_curve: Curve:
	set(v):
		if width_curve == v:
			return
		if width_curve != null and width_curve.changed.is_connected(_on_shape_changed):
			width_curve.changed.disconnect(_on_shape_changed)
		width_curve = v
		if width_curve != null:
			width_curve.changed.connect(_on_shape_changed)
		_changed(true)
## 경로 방향 샘플 수. 클수록 곡선이 부드러워진다
@export_range(2, 512) var length_samples: int = 64:
	set(v):
		v = clampi(v, 2, 512)
		if length_samples != v:
			length_samples = v
			_changed(true)
## 폭 방향 분할 수
@export_range(1, 16) var width_segments: int = 4:
	set(v):
		v = clampi(v, 1, 16)
		if width_segments != v:
			width_segments = v
			_changed(true)
## UV 의 v 1칸에 해당하는 월드 거리
@export_range(0.01, 1000.0, 0.01, "or_greater") var uv_length_scale: float = 8.0:
	set(v):
		v = maxf(0.01, v)
		if uv_length_scale != v:
			uv_length_scale = v
			_changed(true)
## UV v 시작값. 강을 이어 붙일 때 앞 강의 uv_end_v 를 넣으면 무늬가 이어진다
@export var uv_start_v: float = 0.0:
	set(v):
		if uv_start_v != v:
			uv_start_v = v
			_changed(true)

@export_group("다음 강 이어붙임")
## 이 강 뒤에 이어 붙일 강. 연결하면 외형·폭·v 밀도가 복사되고 시작 v 는 이 강의 끝 v 로 맞춰진다
@export var next_river: CatOceanFlowRiver:
	set(v):
		if next_river == v:
			return
		if next_river != null and is_instance_valid(next_river) and next_river._driver == self:
			next_river._set_driver(null)
		next_river = v
		_changed()

## 마지막 메쉬 생성 때 재샘플된 경로의 총 길이 (월드 단위).
var path_length: float = 0.0

## 이 강 끝에서의 v. 다음 강의 uv_start_v 에 넣으면 이음매에서 노이즈가 이어진다.
var uv_end_v: float:
	get:
		return uv_start_v + path_length / maxf(0.01, uv_length_scale)

## 현재 설정으로 만들어질 정점 수.
var estimated_vertex_count: int:
	get:
		if curve == null or curve.point_count < 2:
			return 0
		return length_samples * (width_segments + 1)

## 경로 시작점에서의 실제 폭.
var start_width: float:
	get:
		return width * (width_curve.sample(0.0) if width_curve != null else 1.0)

## 경로 끝점에서의 실제 폭.
var end_width: float:
	get:
		return width * (width_curve.sample(1.0) if width_curve != null else 1.0)

## 동기화가 실제로 동작하는 상태인지. 자기 자신을 참조하면 false.
var has_next_river: bool:
	get:
		return next_river != null and is_instance_valid(next_river) and next_river != self

var _edit_path: Path3D


func _init() -> void:
	super()
	# 새로 만든 강은 강 전용 파동과 기본 S자 경로로 시작한다(씬에서 불러오면 저장 값이 덮어쓴다)
	apply_river_wave_defaults()
	var wc := Curve.new()
	wc.max_value = 4.0
	wc.add_point(Vector2(0.0, 1.0))
	wc.add_point(Vector2(1.0, 1.0))
	wc.resource_local_to_scene = true
	width_curve = wc
	create_default_path()


func _enter_tree() -> void:
	super()
	add_to_group(GROUP)


func _ready() -> void:
	if Engine.is_editor_hint():
		_ensure_edit_path.call_deferred()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() and _edit_path != null and is_instance_valid(_edit_path):
		# 경로 점은 강의 로컬 좌표이므로 편집용 Path3D 는 강과 같은 자리에 둔다
		if _edit_path.transform != Transform3D.IDENTITY:
			_edit_path.transform = Transform3D.IDENTITY
		if _edit_path.curve != null and _edit_path.curve != curve:
			curve = _edit_path.curve
	super(delta)


func _driven_properties() -> Array[StringName]:
	var list := super()
	list.append_array([&"uv_length_scale", &"width", &"width_curve", &"uv_start_v"])
	return list


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if curve == null or curve.point_count < 2:
		warnings.append("경로 점이 2개 이상이어야 물이 생깁니다.")
	if next_river == self:
		warnings.append("자기 자신을 다음 강으로 연결할 수 없습니다.")
	elif has_next_river:
		if loop_path:
			warnings.append("닫힌 물길(loop_path)은 이어 붙일 끝이 없습니다.")
		if absf(end_width - next_river.start_width) > 0.01:
			warnings.append("이음매 폭이 다릅니다(끝 %.2f / 다음 시작 %.2f). 폭 곡선 양 끝을 맞추거나 상수로 두세요." % [end_width, next_river.start_width])
		var end := get_path_end()
		if end.ok and next_river.curve != null and next_river.curve.point_count > 0:
			var next_start := next_river.to_global(next_river.curve.get_point_position(0))
			if to_global(end.position).distance_to(next_start) > 0.05:
				warnings.append("다음 강의 시작점이 이 강의 끝점과 떨어져 있어 물길에 틈이 보입니다.")
	if wave_enabled and shortest_wavelength < (path_length / maxf(1.0, length_samples - 1)) * 4.0:
		warnings.append("가장 짧은 파장이 샘플 간격 × 4 보다 짧아 파도가 떨리기만 합니다.")
	return warnings


#region 공개 API

## 강에 맞는 파동 기본값. 바다의 큰 스웰 대신 잔물결이 주가 된다(진폭 합 약 0.03 m).
func apply_river_wave_defaults() -> void:
	wave_a = Vector4(0.0, 1.0, 0.03, 3.0)    # 진폭 ≈ 0.014 m
	wave_b = Vector4(0.94, 0.34, 0.02, 1.9)   # 진폭 ≈ 0.006 m. A 와 약 70°·무리수에 가까운 파장비
	ripple = Vector4(0.012, 5.0, 2.5, 0.0)   # 진폭 0.012 m
	# 강 폭이 수 m 라 너울·얼룩도 그만큼 잘게 둔다
	wave_phase_jitter = 0.4
	swell_variation = 0.3
	swell_scale = 10.0
	surface_breakup_scale = 8.0


## 점 3개짜리 완만한 S자 기본 경로.
func create_default_path() -> void:
	var c := Curve3D.new()
	c.add_point(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -3.0), Vector3(0.0, 0.0, 3.0))
	c.add_point(Vector3(4.0, 0.0, 8.0), Vector3(-2.0, 0.0, -3.0), Vector3(2.0, 0.0, 3.0))
	c.add_point(Vector3(0.0, 0.0, 16.0), Vector3(0.0, 0.0, -3.0), Vector3(0.0, 0.0, 3.0))
	c.resource_local_to_scene = true
	curve = c


## 경로 끝점의 위치와 진행 방향(로컬). 다음 강을 여기에 놓고 이 방향으로 돌리면 물길이 이어진다.
## 반환: { ok: bool, position: Vector3, direction: Vector3 } — 닫힌 물길이거나 점이 부족하면 ok = false
func get_path_end() -> Dictionary:
	var result := {ok = false, position = Vector3.ZERO, direction = Vector3.BACK}
	if loop_path or curve == null or curve.point_count < 2:
		return result
	var last := curve.point_count - 1
	result.position = curve.get_point_position(last)
	# 들어오는 핸들의 반대가 진행 방향. 핸들이 0 이면 이전 점에서 오는 방향을 쓴다
	var dir := -curve.get_point_in(last)
	if dir.length_squared() < 1e-8:
		dir = curve.get_point_position(last) - curve.get_point_position(last - 1)
		if dir.length_squared() < 1e-8:
			return result
	result.direction = dir.normalized()
	result.ok = true
	return result


## 이어 붙인 강 두 구간을 만든다. 뒤 구간은 앞 구간의 경로 끝점에 놓이고 그 진행 방향으로 회전된다.
## 반환: 두 구간을 자식으로 가진 Node3D
static func create_river_set() -> Node3D:
	var root := Node3D.new()
	root.name = "RiverSet"
	var first := CatOceanFlowRiver.new()
	first.name = "RiverSegment1"
	var second := CatOceanFlowRiver.new()
	second.name = "RiverSegment2"
	root.add_child(first)
	root.add_child(second)
	var end := first.get_path_end()
	if end.ok:
		var dir: Vector3 = end.direction
		var up := Vector3.BACK if absf(dir.dot(Vector3.UP)) > 0.99 else Vector3.UP
		# 기본 경로는 +Z 로 진행하므로 +Z 를 진행 방향에 맞춘다
		second.transform = Transform3D(Basis.looking_at(dir, up, true), end.position)
	first.next_river = second
	first.rebuild_mesh()
	first.sync_next_river()
	return root


## 이 강의 설정을 뒤에 이어 붙인 강으로 밀어 넣고 사슬 끝까지 전파한다(시작 v 누적).
func sync_next_river() -> void:
	_sync_next_river(self, 0)


func _sync_next_river(origin: CatOceanFlowRiver, depth: int) -> void:
	if not has_next_river:
		return
	var next := next_river
	if next == origin:
		push_warning("[CatOceanFlow] '%s' 의 다음 강 연결이 순환입니다. 전파를 여기서 멈춥니다." % name)
		return
	if depth >= MAX_CHAIN_DEPTH:
		push_warning("[CatOceanFlow] 다음 강 연결이 %d 단계를 넘어 전파를 멈춥니다. 순환인지 확인하세요." % MAX_CHAIN_DEPTH)
		return

	next._set_driver(self)
	copy_synced_appearance_to(next)
	var was := next._suppress_sync
	next._suppress_sync = true
	next.uv_length_scale = uv_length_scale
	next.width = width
	if width_curve == null:
		next.width_curve = null
	elif next.width_curve == null or not CatFlowChannel._curves_equal(next.width_curve, width_curve):
		next.width_curve = width_curve.duplicate()
	if _mesh_dirty:
		rebuild_mesh()
	next.uv_start_v = uv_end_v
	next._suppress_sync = was
	# 끝 v 는 path_length 에 의존하므로 다음 칸으로 넘기기 전에 뒤 강의 메쉬를 먼저 만든다
	if next._mesh_dirty:
		next.rebuild_mesh()
	next._sync_next_river(origin, depth + 1)

#endregion


func _on_settings_applied() -> void:
	sync_next_river()
	# 뒤 강에서 값을 만졌을 때 이 강을 참조하는 앞 강이 동기화 값을 다시 채우게 한다
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group(GROUP):
			var previous := node as CatOceanFlowRiver
			if previous != null and previous != self and previous.next_river == self:
				previous.sync_next_river()


func _on_shape_changed() -> void:
	_changed(true)


## 편집용 자식 Path3D 를 찾거나 만든다. 같은 Curve3D 를 공유하므로 경로 기즈모 편집이 곧바로 반영된다.
func _ensure_edit_path() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child is Path3D:
			_edit_path = child
			break
	var scene_root := get_tree().edited_scene_root
	if _edit_path == null and scene_root != null and (owner == scene_root or self == scene_root):
		_edit_path = Path3D.new()
		_edit_path.name = "EditPath"
		add_child(_edit_path)
		_edit_path.owner = scene_root
	if _edit_path != null:
		# 복제(Ctrl+D) 직후에는 강이 독립 사본을 갖고 있으므로 강 쪽 곡선을 기준으로 맞춘다
		_edit_path.transform = Transform3D.IDENTITY
		_edit_path.curve = curve


#region 메쉬

func _build_mesh(target: ArrayMesh) -> void:
	path_length = 0.0
	var samples := resample(curve, loop_path, length_samples)
	var count: int = samples.positions.size()
	if count < 2:
		target.clear_surfaces()
		return
	path_length = samples.distances[count - 1]
	var arrays := build_ribbon_arrays(samples.positions, samples.tangents, samples.distances,
			width, width_curve, width_segments, uv_length_scale, uv_start_v)
	_commit_arrays(target, arrays[0], arrays[1], arrays[2])


## 경로를 따라가는 리본. u 는 폭 방향 0~1, v 는 uv_start_v + 누적 거리 / uv_length_scale.
## 반환: [PackedVector3Array 위치, PackedVector2Array UV, PackedInt32Array 인덱스]
static func build_ribbon_arrays(positions: PackedVector3Array, tangents: PackedVector3Array, distances: PackedFloat32Array,
		ribbon_width: float, curve_scale: Curve, segments: int, length_scale: float, start_v: float = 0.0) -> Array:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var count := positions.size()
	if count < 2:
		return [vertices, uvs, indices]
	segments = maxi(1, segments)
	length_scale = maxf(1e-4, length_scale)
	var stride := segments + 1
	for i in count:
		var along := i / float(count - 1)
		var half_width := ribbon_width * (curve_scale.sample(along) if curve_scale != null else 1.0) * 0.5
		# 수평면 기준 옆 방향. 접선이 수직에 가까우면 폴백한다
		var right := Vector3.UP.cross(tangents[i])
		var right_len := right.length()
		right = right / right_len if right_len > 1e-4 else Vector3.RIGHT
		var v := start_v + distances[i] / length_scale
		for j in stride:
			var u := j / float(segments)
			vertices.append(positions[i] + right * ((u - 0.5) * 2.0 * half_width))
			uvs.append(Vector2(u, v))
	for i in count - 1:
		var row := i * stride
		var next_row := row + stride
		for j in segments:
			# Godot 은 위에서 볼 때 시계 방향이 앞면이다
			indices.append_array([row + j, row + j + 1, next_row + j, row + j + 1, next_row + j + 1, next_row + j])
	return [vertices, uvs, indices]

#endregion


#region 경로 수학 (원본 OceanFlowPath)

## 3차 베지어 위치.
static func evaluate_cubic(p0: Vector3, c0: Vector3, c1: Vector3, p1: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * c0 + 3.0 * u * t * t * c1 + t * t * t * p1


## 3차 베지어의 1차 미분(정규화하지 않음).
static func evaluate_tangent(p0: Vector3, c0: Vector3, c1: Vector3, p1: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return 3.0 * u * u * (c0 - p0) + 6.0 * u * t * (c1 - c0) + 3.0 * t * t * (p1 - c1)


static func _segment_count(c: Curve3D, loop: bool) -> int:
	return c.point_count if loop else c.point_count - 1


## 세그먼트 index 의 제어점 4개 [p0, c0, c1, p1].
static func _get_segment(c: Curve3D, loop: bool, index: int) -> Array[Vector3]:
	var b := (index + 1) % c.point_count if loop else index + 1
	var pa := c.get_point_position(index)
	var pb := c.get_point_position(b)
	return [pa, pa + c.get_point_out(index), pb + c.get_point_in(b), pb]


## 경로 전체 길이 근사.
static func measure_length(c: Curve3D, loop: bool) -> float:
	if c == null or c.point_count < 2:
		return 0.0
	var total := 0.0
	for s in _segment_count(c, loop):
		var seg := _get_segment(c, loop, s)
		var prev := seg[0]
		for i in range(1, LUT_STEPS_PER_SEGMENT + 1):
			var cur := evaluate_cubic(seg[0], seg[1], seg[2], seg[3], i / float(LUT_STEPS_PER_SEGMENT))
			total += prev.distance_to(cur)
			prev = cur
	return total


## 호 길이 기준 등간격 재샘플. 닫힌 경로는 [0, 전체 길이) 에 고르게 분산해 이음매 퇴화를 막는다.
## 반환: { positions: PackedVector3Array, tangents: PackedVector3Array, distances: PackedFloat32Array } (입력이 부족하면 빈 배열)
static func resample(c: Curve3D, loop: bool, sample_count: int) -> Dictionary:
	var out := {positions = PackedVector3Array(), tangents = PackedVector3Array(), distances = PackedFloat32Array()}
	if c == null or c.point_count < 2 or sample_count < 2:
		return out
	var segments := _segment_count(c, loop)
	# LUT: 누적 거리 ↔ 전역 t(세그먼트 인덱스 + 세그먼트 내 t)
	var lut_d := PackedFloat32Array()
	var lut_t := PackedFloat32Array()
	var accumulated := 0.0
	var prev := Vector3.ZERO
	var segs: Array = []
	for s in segments:
		var seg := _get_segment(c, loop, s)
		segs.append(seg)
		for i in LUT_STEPS_PER_SEGMENT + 1:
			if s > 0 and i == 0:
				continue
			var local_t := i / float(LUT_STEPS_PER_SEGMENT)
			var cur := evaluate_cubic(seg[0], seg[1], seg[2], seg[3], local_t)
			if not lut_d.is_empty():
				accumulated += prev.distance_to(cur)
			lut_d.append(accumulated)
			lut_t.append(s + local_t)
			prev = cur
	var total := lut_d[lut_d.size() - 1]
	if total <= 1e-6:
		return out

	var step := total / sample_count if loop else total / (sample_count - 1)
	out.positions.resize(sample_count)
	out.tangents.resize(sample_count)
	out.distances.resize(sample_count)
	for i in sample_count:
		var target := step * i
		var global_t := _lut_distance_to_t(lut_d, lut_t, target)
		var seg_i := mini(int(global_t), segments - 1)
		var local_t := global_t - seg_i
		var seg: Array[Vector3] = segs[seg_i]
		out.positions[i] = evaluate_cubic(seg[0], seg[1], seg[2], seg[3], local_t)
		var tangent := evaluate_tangent(seg[0], seg[1], seg[2], seg[3], local_t)
		var tangent_len := tangent.length()
		# 제어점이 겹쳐 접선이 0 이 되면 폴백한다
		out.tangents[i] = tangent / tangent_len if tangent_len > 1e-6 else Vector3.BACK
		out.distances[i] = target
	return out


static func _lut_distance_to_t(lut_d: PackedFloat32Array, lut_t: PackedFloat32Array, distance: float) -> float:
	var n := lut_d.size()
	if distance <= 0.0:
		return lut_t[0]
	if distance >= lut_d[n - 1]:
		return lut_t[n - 1]
	var low := 0
	var high := n - 1
	while low + 1 < high:
		var mid := (low + high) >> 1
		if lut_d[mid] <= distance:
			low = mid
		else:
			high = mid
	var span := lut_d[high] - lut_d[low]
	var k := (distance - lut_d[low]) / span if span > 1e-6 else 0.0
	return lerpf(lut_t[low], lut_t[high], k)

#endregion
