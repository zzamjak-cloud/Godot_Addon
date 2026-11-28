extends "res://demo/cat_ocean_flow/showcase/showcase_base.gd"

const DURATION := 7.0


func _build() -> void:
	caption_text = "셀 거품 (Cell Foam)"
	ocean.shore_foam_enabled = false
	ocean.highlight_enabled = false
	ocean.noise_churn_enabled = false


func _step(_time: float) -> void:
	aim(Vector3(-8.0 + 8.0 * prog(0.0, 7.0), 8.0, -2.0), Vector3(0, 0, 26))
	var first := t < 4.0
	ocean.cell_cutoff = 0.9 - 0.45 * sin(prog(0.0, 4.0) * PI * 0.5) if first else 0.55
	ocean.cell_intensity = 0.5 if first else 0.2 + 0.8 * sin(prog(4.0, 7.0) * PI)
	set_info("cell_cutoff=%.2f   cell_intensity=%.2f" % [ocean.cell_cutoff, ocean.cell_intensity])
