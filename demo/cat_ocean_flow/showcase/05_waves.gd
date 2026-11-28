extends "res://demo/cat_ocean_flow/showcase/showcase_base.gd"

const DURATION := 8.0


func _build() -> void:
	caption_text = "파동 (Gerstner + 잔물결)"
	ocean.wave_enabled = false
	ocean.shore_foam_enabled = false
	ocean.cell_foam_enabled = false
	ocean.highlight_cutoff = 0.85


func _step(_time: float) -> void:
	aim(Vector3(-6.0 + 12.0 * prog(0.0, 8.0), 3.2, 12.0), Vector3(0, 0, 40))
	var s := stage("w", [2.0, 4.0, 6.0])
	if s.changed:
		ocean.wave_enabled = s.index > 0
		ocean.ripple.x = 0.0 if s.index == 1 else 0.04
	if s.index >= 2:
		var k := prog(4.0, 6.0) if s.index == 2 else 1.0
		ocean.wave_a = Vector4(1, 0, 0.25 + 0.2 * k, 8.0)
		ocean.wave_b = Vector4(0.7, 0.7, 0.15 + 0.15 * k, 4.0)
	var label: String = ["파동 끔", "Gerstner 2개", "+ 잔물결", "가파르게"][s.index]
	set_info("%s   wave_a.steepness=%.2f   ripple.amplitude=%.2f" % [label, ocean.wave_a.z, ocean.ripple.x])
