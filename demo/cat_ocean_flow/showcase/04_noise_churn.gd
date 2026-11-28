extends "res://demo/cat_ocean_flow/showcase/showcase_base.gd"

const DURATION := 8.0


func _build() -> void:
	caption_text = "노이즈 난류 (Noise Churn)"
	ocean.shore_foam_enabled = false
	ocean.highlight_enabled = false
	ocean.cell_cutoff = 0.62
	ocean.noise_churn_enabled = false


func _step(_time: float) -> void:
	aim(Vector3(0, 8.0, -2.0), Vector3(0, 0, 24))
	var s := stage("c", [2.8, 5.4])
	if s.changed:
		ocean.noise_churn_enabled = s.index > 0
		ocean.churn_speed = 0.12 if s.index < 2 else 0.5
		ocean.churn_jitter = 0.5 if s.index < 2 else 1.0
	var label: String = ["끔 (단순 스크롤)", "켬", "강하게"][s.index]
	set_info("noise_churn_enabled=%s   churn_speed=%.2f   churn_jitter=%.1f   %s" % [ocean.noise_churn_enabled, ocean.churn_speed, ocean.churn_jitter, label])
