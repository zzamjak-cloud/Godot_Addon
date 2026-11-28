extends "res://demo/cat_ocean_flow/showcase/showcase_base.gd"

const DURATION := 8.0


func _build() -> void:
	caption_text = "셀 톤 하이라이트 (Highlight)"
	ocean.shore_foam_enabled = false
	ocean.cell_foam_enabled = false
	ocean.highlight_cutoff = 0.8


func _step(_time: float) -> void:
	aim(Vector3(0, 6.0, 6.0), Vector3(0, 0, 40))
	var first := t < 4.0
	var pitch := -14.0 - 36.0 * prog(0.0, 4.0) if first else -50.0
	sun.rotation_degrees = Vector3(pitch, 0, 0)
	ocean.highlight_cutoff = 0.8 if first else 0.85 - 0.6 * sin(prog(4.0, 8.0) * PI)
	set_info("태양 각도=%.0f   highlight_cutoff=%.2f   highlight_intensity=%.1f   normal_jitter=%.1f" % [-pitch, ocean.highlight_cutoff, ocean.highlight_intensity, ocean.highlight_normal_jitter])
