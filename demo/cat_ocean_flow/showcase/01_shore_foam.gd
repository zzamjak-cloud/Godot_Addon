extends "res://demo/cat_ocean_flow/showcase/showcase_base.gd"

const DURATION := 7.0


func _build() -> void:
	caption_text = "접경 포말 (Shore Foam)"
	ocean.cell_foam_enabled = false
	ocean.highlight_enabled = false


func _step(_time: float) -> void:
	var u := prog(0.0, 7.0)
	aim(Vector3(-12.0 + 18.0 * u, 9.0, -14.0), Vector3(0, 0, 10))
	var first := t < 3.5
	ocean.foam_distance = 0.2 + 1.2 * sin(prog(0.0, 3.5) * PI) if first else 1.0
	ocean.foam_cutoff = 0.6 if first else 0.2 + 1.0 * sin(prog(3.5, 7.0) * PI)
	set_info("foam_distance=%.2f   foam_cutoff=%.2f" % [ocean.foam_distance, ocean.foam_cutoff])
