extends "res://demo/cat_ocean_flow/showcase/showcase_base.gd"

const DURATION := 9.0


func _build() -> void:
	caption_text = "파동 (Gerstner + 잔물결 + 변화)"
	ocean.wave_enabled = false
	ocean.shore_foam_enabled = false
	ocean.cell_foam_enabled = false
	ocean.highlight_cutoff = 0.85


func _step(_time: float) -> void:
	aim(Vector3(-6.0 + 12.0 * prog(0.0, 9.0), 3.2, 12.0), Vector3(0, 0, 40))
	var s := stage("w", [1.5, 3.0, 4.5, 6.5])
	if s.changed:
		ocean.wave_enabled = s.index > 0
		ocean.ripple.x = 0.0 if s.index == 1 else 0.04
		# 변화 단계 전에는 위상 지터·너울을 꺼서 균일한 파와 비교되게 한다
		ocean.wave_phase_jitter = 0.5 if s.index >= 3 else 0.0
		ocean.swell_variation = 0.4 if s.index >= 3 else 0.0
	if s.index >= 4:
		var k := prog(6.5, 8.0)
		ocean.wave_a = Vector4(1, 0, 0.25 + 0.2 * k, 8.0)
		ocean.wave_b = Vector4(0.7, 0.7, 0.15 + 0.15 * k, 4.0)
	var label: String = ["파동 끔", "Gerstner 2개", "+ 잔물결", "+ 변화", "가파르게"][s.index]
	set_info("%s   steepness=%.2f   ripple=%.2f   phase_jitter=%.1f   swell_variation=%.1f" % [label, ocean.wave_a.z, ocean.ripple.x, ocean.wave_phase_jitter, ocean.swell_variation])
