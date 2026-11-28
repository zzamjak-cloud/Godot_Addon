extends "res://demo/cat_ocean_flow/showcase/showcase_base.gd"

const DURATION := 7.0
const _COLORS := [
	[Color(0.45, 0.90, 0.92), Color(0.06, 0.28, 0.55)],
	[Color(0.75, 0.95, 0.55), Color(0.10, 0.35, 0.30)],
	[Color(0.95, 0.70, 0.85), Color(0.25, 0.10, 0.45)],
]


func _build() -> void:
	caption_text = "깊이 색 (Depth Color)"
	ocean.shore_foam_enabled = false
	ocean.cell_foam_enabled = false
	ocean.highlight_enabled = false
	ocean.depth_fade_distance = 3.0


func _step(_time: float) -> void:
	aim(Vector3(0, 17.0, -6.0 + 4.0 * prog(0.0, 7.0)), Vector3(0, 0, 24))
	var s := stage("c", [3.0, 5.0])
	if s.index == 0:
		ocean.depth_fade_distance = 0.6 + 7.4 * sin(prog(0.0, 3.0) * PI)
	else:
		ocean.depth_fade_distance = 3.0
		if s.changed:
			var c: Array = _COLORS[s.index]
			ocean.shallow_color = c[0]
			ocean.deep_color = c[1]
	set_info("depth_fade_distance=%.1f   shallow=#%s   deep=#%s" % [ocean.depth_fade_distance, ocean.shallow_color.to_html(false), ocean.deep_color.to_html(false)])
