extends "res://demo/cat_ocean_flow/showcase/showcase_base.gd"

const DURATION := 8.0


func _init() -> void:
	scene_path = "res://demo/cat_ocean_flow/horizon_demo.tscn"
	caption_text = "수평선 (근거리 패치 + 먼 바다)"


func _step(_time: float) -> void:
	var u := prog(0.0, 8.0)
	var from := Vector3(-30.0 + 50.0 * u, 14.0, -40.0 + 55.0 * u)
	aim(from, from + Vector3(10.0 - 20.0 * u, -14.0, 60.0))
	var near: Node3D = get_node("HorizonDemo/OceanSet/OceanNear") if has_node("HorizonDemo/OceanSet/OceanNear") else null
	var c := near.global_position if near != null else Vector3.ZERO
	set_info("근거리 패치 중심 = (%.0f, %.0f)   카메라 = (%.0f, %.0f)" % [c.x, c.z, from.x, from.z])
