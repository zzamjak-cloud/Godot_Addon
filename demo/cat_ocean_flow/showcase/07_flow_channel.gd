extends "res://demo/cat_ocean_flow/showcase/showcase_base.gd"

const DURATION := 9.0
# 모드, 방향, 속도, 범위, 이징, 설명
const _STAGES := [
	[CatFlowChannel.Mode.LOOP, Vector2(1, 0), 0.08, 0.2, CatEase.Type.LINEAR, "LOOP / LINEAR"],
	[CatFlowChannel.Mode.LOOP, Vector2(0, 1), 0.25, 0.2, CatEase.Type.IN_OUT_SINE, "LOOP / IN_OUT_SINE (사이클마다 가감속)"],
	[CatFlowChannel.Mode.PING_PONG, Vector2(1, 0), 2.0, 0.3, CatEase.Type.OUT_BOUNCE, "PING_PONG / OUT_BOUNCE"],
]
var _label := ""


func _build() -> void:
	caption_text = "흐름 채널 (Flow Channel)"
	ocean.shore_foam_enabled = false
	ocean.highlight_enabled = false
	ocean.noise_churn_enabled = false
	ocean.cell_cutoff = 0.6


func _step(_time: float) -> void:
	aim(Vector3(-4.0 + 8.0 * prog(0.0, 9.0), 8.0, -2.0), Vector3(0, 0, 24))
	var s := stage("f", [3.0, 6.0])
	if s.changed:
		var v: Array = _STAGES[s.index]
		var ch := ocean.channel1
		ch.mode = v[0]
		ch.direction = v[1]
		ch.speed = v[2]
		ch.range = v[3]
		ch.ease = v[4]
		_label = v[5]
	set_info("channel1: %s   speed=%.2f" % [_label, ocean.channel1.speed])
