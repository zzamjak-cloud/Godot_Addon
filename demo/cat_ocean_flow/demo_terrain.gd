@tool
extends MeshInstance3D
## 데모용 절차 지형. 해변 경사(BEACH), 강 골짜기(VALLEY), 섬(ISLAND)을 만든다.
## 메쉬는 실행할 때마다 만들므로 씬 파일에 저장하지 않는다.

enum Shape { BEACH, VALLEY, ISLAND }

@export var shape: Shape = Shape.BEACH:
	set(v):
		shape = v
		_queue_build()
@export var size: Vector2 = Vector2(80, 80):
	set(v):
		size = v
		_queue_build()
@export_range(8, 400) var resolution: int = 160:
	set(v):
		resolution = v
		_queue_build()
## VALLEY: 골짜기를 파 낼 강
@export var river: CatOceanFlowRiver:
	set(v):
		river = v
		_queue_build()
@export var valley_depth: float = 1.4
@export var valley_width: float = 7.0
@export var bank_height: float = 5.0

var _queued := false
var _river_samples := PackedVector3Array()


func _ready() -> void:
	_build()


func _validate_property(property: Dictionary) -> void:
	if property.name == "mesh":
		property.usage &= ~PROPERTY_USAGE_STORAGE


func _queue_build() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	_build.call_deferred()


func _build() -> void:
	_queued = false
	_river_samples.clear()
	if shape == Shape.VALLEY and river != null:
		var s := CatOceanFlowRiver.resample(river.curve, river.loop_path, 160)
		for p: Vector3 in s.positions:
			_river_samples.append(to_local(river.to_global(p)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := resolution
	for z in n + 1:
		for x in n + 1:
			var px := (x / float(n) - 0.5) * size.x
			var pz := (z / float(n) - 0.5) * size.y
			var h := _height(px, pz)
			st.set_color(_color(h))
			st.set_uv(Vector2(px, pz) * 0.25)
			st.add_vertex(Vector3(px, h, pz))
	for z in n:
		for x in n:
			var i := z * (n + 1) + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + n + 1)
			st.add_index(i + 1)
			st.add_index(i + n + 2)
			st.add_index(i + n + 1)
	st.generate_normals()
	mesh = st.commit()
	if material_override == null:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.roughness = 1.0
		material_override = mat


func _height(x: float, z: float) -> float:
	match shape:
		Shape.BEACH:
			# 완만한 경사(+Z 가 바다 쪽)에 물결 모양 해안선과 작은 모래톱
			var h := -0.11 * z + 0.9 * sin(x * 0.11) + 0.35 * sin(x * 0.37 + z * 0.21)
			h += 1.2 * exp(-(pow(x - 12.0, 2.0) + pow(z - 9.0, 2.0)) / 18.0)
			return h
		Shape.VALLEY:
			var best := INF
			var best_y := 0.0
			for p in _river_samples:
				var d := Vector2(p.x - x, p.z - z).length_squared()
				if d < best:
					best = d
					best_y = p.y
			var d := sqrt(best)
			var hills := 1.5 * sin(x * 0.09) * cos(z * 0.07) + 0.6 * sin(x * 0.23 + z * 0.17)
			var h := best_y - valley_depth + (valley_depth + bank_height) * smoothstep(0.0, valley_width, d)
			return h + hills * smoothstep(valley_width, valley_width * 2.5, d)
		_:
			var r := Vector2(x, z).length()
			var island := 7.0 * exp(-pow(r / 26.0, 2.0)) - 5.0
			return island + 0.6 * sin(x * 0.13) * cos(z * 0.11)


func _color(h: float) -> Color:
	var sand := Color(0.93, 0.84, 0.62)
	var wet := Color(0.78, 0.68, 0.48)
	var grass := Color(0.45, 0.68, 0.32)
	if h < 0.0:
		return wet
	return sand.lerp(grass, smoothstep(1.5, 3.0, h))
