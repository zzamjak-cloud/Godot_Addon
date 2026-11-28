@tool
@abstract
class_name CatOceanFlowBase
extends MeshInstance3D
## 바다와 강이 공유하는 물 노드 베이스(Unity OceanFlowBase).
## 메쉬·머티리얼 수명주기, 셰이더 값 적용, UV 흐름 구동을 맡는다. 메쉬 생성은 파생 클래스의 _build_mesh().

const SHADER_INCLUDE := "res://addons/cat_ocean_flow/shaders/cat_ocean_flow.gdshaderinc"
const DEFAULT_NOISE_PATH := "res://addons/cat_ocean_flow/noise/cat_ocean_flow_noise.png"

## 셰이더 기능 비트. 켠 조합마다 #define 이 다른 Shader 를 만든다.
enum Feature { WAVE_ON = 1, FOAM_SHORE = 2, CELL_FOAM = 4, NOISE_CHURN = 8, SPECULAR = 16 }
const FEATURE_DEFINES := ["WAVE_ON", "FOAM_SHORE", "CELL_FOAM", "NOISE_CHURN", "SPECULAR"]

# 두 노이즈 레이어가 같은 박자로 태어나고 사라지지 않도록 채널1 의 난류 위상을 어긋나게 둔다
const CHANNEL1_CHURN_PHASE := 0.37

## 근거리 → 먼 바다, 앞 강 → 뒤 강으로 그대로 복사되는 외형 값(기능 on/off 토글은 제외).
const SYNCED_APPEARANCE: Array[StringName] = [
	&"shallow_color", &"deep_color", &"shallow_alpha", &"deep_alpha", &"depth_fade_distance",
	&"foam_color", &"foam_distance", &"foam_cutoff", &"foam_softness", &"foam_noise_amount",
	&"foam_alpha", &"foam_fade_start", &"foam_fade_end",
	&"noise_texture", &"churn_speed", &"churn_jitter", &"churn_warp", &"churn_rotation",
	&"cell_color", &"cell_cutoff", &"cell_softness", &"cell_intensity",
	&"surface_breakup", &"surface_breakup_scale",
	&"wave_a", &"wave_b", &"ripple", &"wave_phase_jitter", &"swell_variation", &"swell_scale",
	&"highlight_color", &"highlight_power", &"highlight_cutoff", &"highlight_intensity",
	&"use_unscaled_time",
]

const _GROUP_TOGGLES := {
	&"shore_foam_enabled": [&"foam_color", &"foam_distance", &"foam_cutoff", &"foam_softness",
		&"foam_noise_amount", &"foam_alpha", &"foam_fade_start", &"foam_fade_end", &"channel0"],
	&"noise_churn_enabled": [&"churn_speed", &"churn_jitter", &"churn_warp", &"churn_rotation"],
	&"cell_foam_enabled": [&"cell_color", &"cell_cutoff", &"cell_softness", &"cell_intensity"],
	&"wave_enabled": [&"wave_a", &"wave_b", &"ripple", &"wave_phase_jitter", &"swell_variation", &"swell_scale"],
	&"highlight_enabled": [&"highlight_color", &"highlight_power", &"highlight_cutoff",
		&"highlight_intensity", &"main_light"],
}

static var _shader_cache: Dictionary = {}
static var _default_noise: Texture2D

#region 물 색
@export_group("물 색")
@export var shallow_color: Color = Color(0.45, 0.90, 0.92, 1.0):
	set(v):
		if shallow_color != v:
			shallow_color = v
			_changed()
@export var deep_color: Color = Color(0.06, 0.28, 0.55, 1.0):
	set(v):
		if deep_color != v:
			deep_color = v
			_changed()
@export_range(0.0, 1.0) var shallow_alpha: float = 0.5:
	set(v):
		if shallow_alpha != v:
			shallow_alpha = v
			_changed()
@export_range(0.0, 1.0) var deep_alpha: float = 0.95:
	set(v):
		if deep_alpha != v:
			deep_alpha = v
			_changed()
## 이 깊이에서 완전히 깊은 색이 된다
@export_range(0.05, 30.0) var depth_fade_distance: float = 3.0:
	set(v):
		if depth_fade_distance != v:
			depth_fade_distance = v
			_changed()
#endregion

#region 접경 포말
@export_group("접경 포말")
@export var shore_foam_enabled: bool = true:
	set(v):
		if shore_foam_enabled != v:
			shore_foam_enabled = v
			_changed(false, true)
@export var foam_color: Color = Color.WHITE:
	set(v):
		if foam_color != v:
			foam_color = v
			_changed()
## 포말이 생기는 수심 (월드 단위)
@export_range(0.01, 10.0) var foam_distance: float = 0.6:
	set(v):
		if foam_distance != v:
			foam_distance = v
			_changed()
@export_range(0.0, 2.0) var foam_cutoff: float = 0.6:
	set(v):
		if foam_cutoff != v:
			foam_cutoff = v
			_changed()
@export_range(0.001, 0.5) var foam_softness: float = 0.04:
	set(v):
		if foam_softness != v:
			foam_softness = v
			_changed()
@export_range(0.0, 1.0) var foam_noise_amount: float = 0.35:
	set(v):
		if foam_noise_amount != v:
			foam_noise_amount = v
			_changed()
@export_range(0.0, 1.0) var foam_alpha: float = 1.0:
	set(v):
		if foam_alpha != v:
			foam_alpha = v
			_changed()
## 이 카메라 거리부터 포말을 지우기 시작한다. 0 이면 끔. 먼 물가는 깊이 분해능이 떨어져 띠가 깜빡인다
@export_range(0.0, 2000.0, 0.1, "or_greater") var foam_fade_start: float = 0.0:
	set(v):
		v = maxf(v, 0.0)
		if foam_fade_start != v:
			foam_fade_start = v
			_changed()
## 이 카메라 거리에서 포말이 완전히 사라진다
@export_range(0.0, 2000.0, 0.1, "or_greater") var foam_fade_end: float = 300.0:
	set(v):
		v = maxf(v, 0.0)
		if foam_fade_end != v:
			foam_fade_end = v
			_changed()
## 포말 노이즈 레이어의 흐름 (채널 0)
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "CatFlowChannel", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_ALWAYS_DUPLICATE) var channel0: CatFlowChannel:
	set(v):
		_swap_channel(channel0, v)
		channel0 = v
		_changed()
#endregion

#region 수면 노이즈
@export_group("수면 노이즈")
## 비워 두면 애드온 기본 노이즈를 쓴다. 단일 채널(R) 선형 데이터 — 반복(repeat) 샘플링한다
@export var noise_texture: Texture2D:
	set(v):
		if noise_texture != v:
			noise_texture = v
			_changed()
## 수면 노이즈 레이어의 흐름 (채널 1)
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "CatFlowChannel", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_ALWAYS_DUPLICATE) var channel1: CatFlowChannel:
	set(v):
		_swap_channel(channel1, v)
		channel1 = v
		_changed()
## 노이즈가 형태를 유지한 채 흘러가는 대신 계속 태어나고 사라지게 한다
@export var noise_churn_enabled: bool = true:
	set(v):
		if noise_churn_enabled != v:
			noise_churn_enabled = v
			_changed(false, true)
## 초당 재배치 사이클 수. 낮을수록 천천히 뒤엉킨다
@export_range(0.01, 2.0) var churn_speed: float = 0.12:
	set(v):
		if churn_speed != v:
			churn_speed = v
			_changed()
## 사이클마다 노이즈가 옮겨 앉는 거리 (UV 단위)
@export_range(0.0, 1.0) var churn_jitter: float = 0.5:
	set(v):
		if churn_jitter != v:
			churn_jitter = v
			_changed()
## UV 를 비트는 세기. 그물망이 통째로 미끄러지는 느낌을 없앤다
@export_range(0.0, 0.3) var churn_warp: float = 0.06:
	set(v):
		if churn_warp != v:
			churn_warp = v
			_changed()
## 사이클마다 노이즈가 돌아가는 각도 폭 (라디안)
@export_range(0.0, 1.5) var churn_rotation: float = 0.6:
	set(v):
		if churn_rotation != v:
			churn_rotation = v
			_changed()
@export var cell_foam_enabled: bool = true:
	set(v):
		if cell_foam_enabled != v:
			cell_foam_enabled = v
			_changed(false, true)
@export var cell_color: Color = Color.WHITE:
	set(v):
		if cell_color != v:
			cell_color = v
			_changed()
@export_range(0.0, 1.0) var cell_cutoff: float = 0.72:
	set(v):
		if cell_cutoff != v:
			cell_cutoff = v
			_changed()
@export_range(0.001, 0.3) var cell_softness: float = 0.03:
	set(v):
		if cell_softness != v:
			cell_softness = v
			_changed()
@export_range(0.0, 2.0) var cell_intensity: float = 0.5:
	set(v):
		if cell_intensity != v:
			cell_intensity = v
			_changed()
@export_subgroup("얼룩")
## 셀 거품·하이라이트 밀도를 구역마다 다르게 한다. 0 이면 수면 전체가 균일
@export_range(0.0, 1.0) var surface_breakup: float = 0.6:
	set(v):
		if surface_breakup != v:
			surface_breakup = v
			_changed()
## 얼룩 한 덩어리의 크기 (월드 m)
@export_range(2.0, 200.0, 0.1, "or_greater") var surface_breakup_scale: float = 25.0:
	set(v):
		v = maxf(v, 0.1)
		if surface_breakup_scale != v:
			surface_breakup_scale = v
			_changed()
#endregion

#region 파동
@export_group("파동")
## 파도 진폭이 컬링 여유에 반영되므로 바꾸면 메쉬를 다시 만든다
@export var wave_enabled: bool = true:
	set(v):
		if wave_enabled != v:
			wave_enabled = v
			_changed(true, true)
## Gerstner 파 A: 방향 xy, 가파름 z, 파장 w
@export var wave_a: Vector4 = Vector4(1.0, 0.0, 0.25, 8.0):
	set(v):
		if wave_a != v:
			wave_a = v
			_changed(true)
## Gerstner 파 B: 방향 xy, 가파름 z, 파장 w
@export var wave_b: Vector4 = Vector4(0.7, 0.7, 0.15, 4.0):
	set(v):
		if wave_b != v:
			wave_b = v
			_changed(true)
## 잔물결: 진폭 x, 주파수 y, 속도 z
@export var ripple: Vector4 = Vector4(0.04, 3.0, 1.5, 0.0):
	set(v):
		if ripple != v:
			ripple = v
			_changed(true)
@export_subgroup("변화")
## 지역마다 파의 위상을 비틀어 마루선이 곧게 이어지지 않게 한다
@export_range(0.0, 1.0) var wave_phase_jitter: float = 0.5:
	set(v):
		if wave_phase_jitter != v:
			wave_phase_jitter = v
			_changed()
## 지역마다 진폭을 줄여 너울 묶음을 만든다(1 이면 최소 0.3배). 진폭을 키우지는 않는다
@export_range(0.0, 1.0) var swell_variation: float = 0.4:
	set(v):
		if swell_variation != v:
			swell_variation = v
			_changed()
## 너울 묶음 한 덩어리의 크기 (월드 m)
@export_range(2.0, 400.0, 0.1, "or_greater") var swell_scale: float = 40.0:
	set(v):
		v = maxf(v, 0.1)
		if swell_scale != v:
			swell_scale = v
			_changed()
#endregion

#region 하이라이트
@export_group("하이라이트")
@export var highlight_enabled: bool = true:
	set(v):
		if highlight_enabled != v:
			highlight_enabled = v
			_changed(false, true)
@export var highlight_color: Color = Color.WHITE:
	set(v):
		if highlight_color != v:
			highlight_color = v
			_changed()
@export_range(1.0, 256.0) var highlight_power: float = 64.0:
	set(v):
		if highlight_power != v:
			highlight_power = v
			_changed()
@export_range(0.0, 1.0) var highlight_cutoff: float = 0.5:
	set(v):
		if highlight_cutoff != v:
			highlight_cutoff = v
			_changed()
@export_range(0.0, 3.0) var highlight_intensity: float = 0.8:
	set(v):
		if highlight_intensity != v:
			highlight_intensity = v
			_changed()
## 하이라이트 방향·색을 줄 빛. 비우면 씬에서 처음 찾은 보이는 DirectionalLight3D
@export var main_light: DirectionalLight3D:
	set(v):
		if main_light != v:
			main_light = v
			_light_searched = false
			_changed()
#endregion

#region 시간
@export_group("시간")
## Engine.time_scale 의 영향을 받지 않는 실제 시간을 쓴다
@export var use_unscaled_time: bool = false:
	set(v):
		if use_unscaled_time != v:
			use_unscaled_time = v
			_changed()
#endregion

## 외부가 시간을 직접 밀어주는 중인지. true 면 _process 가 시간을 진행시키지 않는다.
var externally_driven: bool = false

## 흐름·난류에 쓰는 누적 시간(초). 파도는 셰이더 TIME 을 쓴다.
var flow_time: float = 0.0

## 파도 A·B 중 짧은 파장. 정점 간격 대비 앨리어싱 경고에 쓰인다.
var shortest_wavelength: float:
	get:
		return minf(wave_a.w, wave_b.w)

var _mesh: ArrayMesh
var _material: ShaderMaterial
var _applied_mask: int = -1
var _mesh_dirty: bool = true
var _props_dirty: bool = true
var _sync_dirty: bool = true
var _suppress_sync: bool = false
var _driver: Node   # 이 물에 값을 밀어 넣는 근거리 바다/앞 강. 있으면 동기화 항목이 잠긴다
var _light_cache: DirectionalLight3D
var _light_searched: bool = false
var _last_light_dir: Vector3 = Vector3.INF
var _last_light_color: Color = Color(-1, -1, -1)
var _last_ticks_usec: int = 0


func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var c0 := CatFlowChannel.create_default(Vector2(1.0, 0.15), 0.06)
	c0.tiling = Vector2(4.0, 4.0)
	channel0 = c0
	var c1 := CatFlowChannel.create_default(Vector2(-0.6, 1.0), 0.035)
	c1.tiling = Vector2(7.0, 7.0)
	channel1 = c1


func _enter_tree() -> void:
	_ensure_mesh()
	_ensure_material()
	_mesh_dirty = true
	_props_dirty = true
	_sync_dirty = true
	_last_ticks_usec = Time.get_ticks_usec()
	set_process(true)


func _process(delta: float) -> void:
	_flush()
	var now := Time.get_ticks_usec()
	if not externally_driven:
		flow_time += float(now - _last_ticks_usec) / 1000000.0 if use_unscaled_time else delta
	_last_ticks_usec = now
	_apply_per_frame_properties()


## 쌓인 변경(메쉬·머티리얼·동기화)을 지금 한 번에 반영한다. 보통은 _process 가 부른다.
func _flush() -> void:
	if _mesh_dirty:
		rebuild_mesh()
	if _props_dirty:
		_props_dirty = false
		_apply_all_properties()
		if Engine.is_editor_hint():
			update_configuration_warnings()
	if _sync_dirty:
		_sync_dirty = false
		_on_settings_applied()


func _validate_property(property: Dictionary) -> void:
	var prop_name: StringName = property.name
	# 생성 메쉬·머티리얼은 매번 만들어지므로 씬 파일에 저장하지 않는다
	if prop_name == &"mesh" or prop_name == &"material_override":
		property.usage &= ~PROPERTY_USAGE_STORAGE
		property.usage |= PROPERTY_USAGE_READ_ONLY
		return
	for toggle: StringName in _GROUP_TOGGLES:
		if prop_name in _GROUP_TOGGLES[toggle] and not get(toggle):
			property.usage |= PROPERTY_USAGE_READ_ONLY
	# 얼룩은 셀 거품과 하이라이트가 같이 쓰므로 둘 다 꺼졌을 때만 잠근다
	if prop_name in [&"surface_breakup", &"surface_breakup_scale"] and not cell_foam_enabled and not highlight_enabled:
		property.usage |= PROPERTY_USAGE_READ_ONLY
	if is_driven() and prop_name in _driven_properties():
		property.usage |= PROPERTY_USAGE_READ_ONLY


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if wave_enabled and wave_a.z + wave_b.z > 1.0:
		warnings.append("파도 A·B 의 가파름 합이 1을 넘어 수면이 접힙니다.")
	if not global_basis.get_scale().is_equal_approx(Vector3.ONE):
		warnings.append("스케일은 1로 두세요. 파도 변위는 월드 단위지만 컬링 여유는 로컬 단위라 가장자리에서 팝핑이 생깁니다.")
	return warnings


#region 공개 API

## 메쉬를 지금 다시 만든다. 파라미터가 바뀌었을 때만 부른다.
func rebuild_mesh() -> void:
	_mesh_dirty = false
	_ensure_mesh()
	_build_mesh(_mesh)
	extra_cull_margin = get_bounds_padding()


## 다음 프레임에 셰이더 값 전체를 다시 적용하도록 표시한다.
func mark_properties_dirty() -> void:
	_props_dirty = true


## 시간을 수동으로 진행시킨다(externally_driven 과 함께 쓴다).
func advance_preview_time(delta_time: float) -> void:
	flow_time += delta_time
	if _material != null:
		_apply_per_frame_properties()


## 흐름 시간을 0 으로 되돌린다.
func reset_preview_time() -> void:
	flow_time = 0.0
	if _material != null:
		_apply_per_frame_properties()


## 다른 물이 이 물에 값을 밀어 넣는 중인지(먼 바다·뒤 강).
func is_driven() -> bool:
	return _driver != null and is_instance_valid(_driver)


## 파도 변위를 감안한 컬링 여유(진폭 합). extra_cull_margin 에 그대로 쓴다.
func get_bounds_padding() -> float:
	if not wave_enabled:
		return 0.0
	# Gerstner 진폭 = 가파름 / k = 가파름 * 파장 / 2PI
	return wave_a.z * wave_a.w / TAU + wave_b.z * wave_b.w / TAU + absf(ripple.x)


## 켠 기능의 비트마스크.
func get_feature_mask() -> int:
	var mask := 0
	if wave_enabled:
		mask |= Feature.WAVE_ON
	if shore_foam_enabled:
		mask |= Feature.FOAM_SHORE
	if cell_foam_enabled:
		mask |= Feature.CELL_FOAM
	if noise_churn_enabled:
		mask |= Feature.NOISE_CHURN
	if highlight_enabled:
		mask |= Feature.SPECULAR
	return mask


## 이 노드가 쓰는 머티리얼(노드마다 하나).
func get_water_material() -> ShaderMaterial:
	_ensure_material()
	return _material


## 기능 조합별 셰이더. 같은 조합은 모든 물이 하나를 공유한다.
static func get_variant_shader(mask: int) -> Shader:
	var cached: Shader = _shader_cache.get(mask)
	if cached != null:
		return cached
	var code := "shader_type spatial;\n"
	for i in FEATURE_DEFINES.size():
		if mask & (1 << i):
			code += "#define %s\n" % FEATURE_DEFINES[i]
	code += "#include \"%s\"\n" % SHADER_INCLUDE
	var shader := Shader.new()
	shader.code = code
	_shader_cache[mask] = shader
	return shader


## 외형 값을 다른 물로 복사한다. 기능 on/off 토글과 형상은 복사하지 않는다.
func copy_synced_appearance_to(target: CatOceanFlowBase) -> void:
	if target == null or target == self:
		return
	var was := target._suppress_sync
	target._suppress_sync = true
	for prop in SYNCED_APPEARANCE:
		target.set(prop, get(prop))
	if target.channel0 == null:
		target.channel0 = CatFlowChannel.new()
	if target.channel1 == null:
		target.channel1 = CatFlowChannel.new()
	target.channel0.copy_from(channel0)
	target.channel1.copy_from(channel1)
	target._suppress_sync = was

#endregion


#region 파생 클래스 훅

## 파생 클래스가 자기 형상의 메쉬를 채운다.
@abstract func _build_mesh(mesh: ArrayMesh) -> void


## 표면 전용 셰이더 값(카메라 추적 UV 보정, 가장자리 페이드). 강은 기본값을 유지한다.
func _apply_surface_properties(_mat: ShaderMaterial) -> void:
	pass


## 값이 바뀐 뒤 한 번 호출된다. 다른 물로 값을 전파할 때 쓴다.
func _on_settings_applied() -> void:
	pass


## 동기화 대상일 때 잠글 속성 목록.
func _driven_properties() -> Array[StringName]:
	var list: Array[StringName] = SYNCED_APPEARANCE.duplicate()
	list.append(&"channel0")
	list.append(&"channel1")
	return list


func _set_driver(driver: Node) -> void:
	if _driver == driver:
		return
	_driver = driver
	notify_property_list_changed()


## 표면 전용 값만 즉시 다시 올린다.
func _apply_surface_properties_now() -> void:
	if _material != null:
		_apply_surface_properties(_material)


## 배열을 메쉬 표면으로 올린다. 법선은 셰이더가 만들므로 위치·UV 만 둔다.
static func _commit_arrays(mesh: ArrayMesh, vertices: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	mesh.clear_surfaces()
	if indices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

#endregion


#region 내부 구현

## setter 공통 처리. 실제 반영은 다음 _process 에서 한 번만 한다.
func _changed(rebuild: bool = false, relist: bool = false) -> void:
	_props_dirty = true
	if rebuild:
		_mesh_dirty = true
	if not _suppress_sync:
		_sync_dirty = true
	if relist:
		notify_property_list_changed()


func _swap_channel(old: CatFlowChannel, new: CatFlowChannel) -> void:
	if old != null and old.changed.is_connected(_on_channel_changed):
		old.changed.disconnect(_on_channel_changed)
	if new != null and not new.changed.is_connected(_on_channel_changed):
		new.changed.connect(_on_channel_changed)


func _on_channel_changed() -> void:
	_changed()


func _ensure_mesh() -> void:
	if _mesh != null:
		return
	_mesh = ArrayMesh.new()
	mesh = _mesh


func _ensure_material() -> void:
	if _material != null:
		return
	_material = ShaderMaterial.new()
	material_override = _material


func _apply_per_frame_properties() -> void:
	# 노이즈 텍스처 주기가 1 이라 [0,1) 로 감아도 결과가 같고, 장시간 실행 시 정밀도 손실을 막는다
	var o0 := CatFlowChannel.evaluate(channel0, flow_time)
	var o1 := CatFlowChannel.evaluate(channel1, flow_time)
	_material.set_shader_parameter(&"flow_offsets",
			Vector4(fposmod(o0.x, 1.0), fposmod(o0.y, 1.0), fposmod(o1.x, 1.0), fposmod(o1.y, 1.0)))
	if noise_churn_enabled:
		_apply_churn_phases()
	if highlight_enabled:
		_apply_light()


# 매 프레임 호출되므로 Dictionary 를 만들지 않고 값 타입만 쓴다
func _apply_churn_phases() -> void:
	var t0 := churn_cycle(flow_time, churn_speed, 0.0)
	var t1 := churn_cycle(flow_time, churn_speed, CHANNEL1_CHURN_PHASE)
	_material.set_shader_parameter(&"churn_params", Vector4(churn_weight_b(t0), churn_weight_b(t1), churn_warp, flow_time))
	_material.set_shader_parameter(&"churn0_a", _build_churn_phase(floorf(t0), churn_jitter, churn_rotation))
	_material.set_shader_parameter(&"churn0_b", _build_churn_phase(floorf(t0 + 0.5), churn_jitter, churn_rotation))
	_material.set_shader_parameter(&"churn1_a", _build_churn_phase(floorf(t1), churn_jitter, churn_rotation))
	_material.set_shader_parameter(&"churn1_b", _build_churn_phase(floorf(t1 + 0.5), churn_jitter, churn_rotation))


## 난류 위상 진행값 t. 위상 A 의 인덱스 = floor(t), 위상 B 의 인덱스 = floor(t + 0.5).
static func churn_cycle(time: float, speed: float, phase_shift: float) -> float:
	return time * maxf(speed, 1e-4) + phase_shift


## 위상 B 의 가중치. 위상의 사이클 인덱스가 바뀌는 순간 그 위상의 가중치가 정확히 0 이라 전환에서 튐이 없다.
static func churn_weight_b(t: float) -> float:
	return absf(1.0 - 2.0 * (t - floorf(t)))


## 테스트·디버그용 묶음 결과(_apply_churn_phases 와 같은 함수를 쓴다).
## 반환: { phase_a: Vector4, phase_b: Vector4, weight_b: float, index_a: float, index_b: float }
static func compute_churn_phase(time: float, speed: float, jitter: float, rotation_range: float, phase_shift: float) -> Dictionary:
	var t := churn_cycle(time, speed, phase_shift)
	return {
		phase_a = _build_churn_phase(floorf(t), jitter, rotation_range),
		phase_b = _build_churn_phase(floorf(t + 0.5), jitter, rotation_range),
		weight_b = churn_weight_b(t),
		index_a = floorf(t),
		index_b = floorf(t + 0.5),
	}


static func _build_churn_phase(cycle_index: float, jitter: float, rotation_range: float) -> Vector4:
	var h := churn_hash(cycle_index)
	var angle := (h.y * 2.0 - 1.0) * rotation_range
	return Vector4(h.x * jitter, h.y * jitter, cos(angle), sin(angle))


## 사이클 인덱스에서 의사난수 2성분. 인덱스를 64 로 접어 sin 인자가 커지지 않게 한다.
static func churn_hash(cycle_index: float) -> Vector2:
	var n := fposmod(cycle_index, 64.0)
	var sx := sin(n * 12.9898 + 4.1414) * 43758.5453
	var sy := sin(n * 78.2330 + 1.7231) * 43758.5453
	return Vector2(sx - floorf(sx), sy - floorf(sy))


func _apply_all_properties() -> void:
	_ensure_material()
	var mask := get_feature_mask()
	if mask != _applied_mask:
		_applied_mask = mask
		_material.shader = get_variant_shader(mask)

	var noise := noise_texture
	if noise == null:
		if _default_noise == null:
			_default_noise = load(DEFAULT_NOISE_PATH) as Texture2D
		noise = _default_noise
	var m := _material
	m.set_shader_parameter(&"noise_texture", noise)
	var t0 := channel0.tiling if channel0 != null else Vector2.ONE
	var t1 := channel1.tiling if channel1 != null else Vector2.ONE
	m.set_shader_parameter(&"flow_tiling", Vector4(t0.x, t0.y, t1.x, t1.y))

	m.set_shader_parameter(&"shallow_color", shallow_color)
	m.set_shader_parameter(&"deep_color", deep_color)
	m.set_shader_parameter(&"shallow_alpha", shallow_alpha)
	m.set_shader_parameter(&"deep_alpha", deep_alpha)
	m.set_shader_parameter(&"depth_fade_distance", depth_fade_distance)

	m.set_shader_parameter(&"foam_color", foam_color)
	m.set_shader_parameter(&"foam_distance", foam_distance)
	m.set_shader_parameter(&"foam_cutoff", foam_cutoff)
	m.set_shader_parameter(&"foam_softness", foam_softness)
	m.set_shader_parameter(&"foam_noise_amount", foam_noise_amount)
	m.set_shader_parameter(&"foam_alpha", foam_alpha)
	m.set_shader_parameter(&"foam_view_fade", resolve_foam_view_fade())

	m.set_shader_parameter(&"cell_color", cell_color)
	m.set_shader_parameter(&"cell_cutoff", cell_cutoff)
	m.set_shader_parameter(&"cell_softness", cell_softness)
	m.set_shader_parameter(&"cell_intensity", cell_intensity)

	m.set_shader_parameter(&"highlight_color", highlight_color)
	m.set_shader_parameter(&"highlight_power", highlight_power)
	m.set_shader_parameter(&"highlight_cutoff", highlight_cutoff)
	m.set_shader_parameter(&"highlight_intensity", highlight_intensity)

	m.set_shader_parameter(&"wave_a", wave_a)
	m.set_shader_parameter(&"wave_b", wave_b)
	m.set_shader_parameter(&"ripple", ripple)
	m.set_shader_parameter(&"wave_variation", Vector4(wave_phase_jitter, swell_variation, 1.0 / swell_scale, 0.0))
	m.set_shader_parameter(&"breakup_params", Vector4(surface_breakup, 1.0 / surface_breakup_scale, 0.0, 0.0))

	# 4.7 의 세 렌더러 모두 hint_depth_texture 를 지원한다. 더미 렌더러(헤드리스)만 제외
	m.set_shader_parameter(&"depth_available", 0.0 if RenderingServer.get_current_rendering_method() == "dummy" else 1.0)

	_apply_surface_properties(m)
	_light_searched = false   # 트리가 바뀌었을 수 있으니 빛을 다시 찾는다
	_last_light_dir = Vector3.INF
	_apply_per_frame_properties()


## 페이드가 꺼져 있으면(시작 0) 아주 먼 거리로 치환한다. 끝은 항상 시작보다 크게 보정한다.
func resolve_foam_view_fade() -> Vector2:
	if foam_fade_start <= 0.0:
		return Vector2(1e6, 1e6 + 1.0)
	return Vector2(foam_fade_start, maxf(foam_fade_end, foam_fade_start + 0.01))


func _apply_light() -> void:
	var light := _resolve_light()
	var dir := Vector3.UP
	var col := Color.WHITE
	if light != null:
		# DirectionalLight3D 는 -Z 로 비추므로 +Z 가 빛 쪽을 향하는 방향이다
		dir = light.global_basis.z.normalized()
		col = light.light_color * light.light_energy
	if dir != _last_light_dir:
		_last_light_dir = dir
		_material.set_shader_parameter(&"light_direction", dir)
	if col != _last_light_color:
		_last_light_color = col
		_material.set_shader_parameter(&"light_color", Vector3(col.r, col.g, col.b))


func _resolve_light() -> DirectionalLight3D:
	if main_light != null and is_instance_valid(main_light):
		return main_light
	if _light_cache != null and is_instance_valid(_light_cache) and _light_cache.is_inside_tree():
		return _light_cache
	# 매 프레임 찾지 않도록, 값이 바뀌거나 캐시한 빛이 사라졌을 때만 다시 찾는다
	if _light_searched and _light_cache == null:
		return null
	if not is_inside_tree():
		return null
	_light_searched = true
	_light_cache = null
	var tree := get_tree()
	var scope: Node = tree.edited_scene_root if tree.edited_scene_root != null else tree.current_scene
	if scope == null:
		scope = tree.root
	for node in scope.find_children("*", "DirectionalLight3D", true, false):
		var light := node as DirectionalLight3D
		if light.is_visible_in_tree():
			_light_cache = light
			break
	return _light_cache

#endregion
