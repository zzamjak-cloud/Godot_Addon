extends "res://demo/cat_ocean_flow/showcase/showcase_base.gd"

const DURATION := 8.0


func _init() -> void:
	scene_path = "res://demo/cat_ocean_flow/river_demo.tscn"
	caption_text = "강 (River): 경로 · 폭 곡선"


func _step(_time: float) -> void:
	var length := river.curve.get_baked_length()
	var f := length * 0.55 * prog(0.0, 8.0)
	var p := river.curve.sample_baked(f)
	var ahead := river.curve.sample_baked(f + 10.0)
	aim(p + Vector3(0, 8.0, -11.0), ahead)
	river.width = 5.0 + 2.5 * sin(prog(0.0, 8.0) * TAU)
	set_info("width=%.1f   width_curve (0.9 → 1.3 → 1.0 배)   경로=Curve3D" % river.width)
