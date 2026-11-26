extends "res://demo/cat_text_fx/showcase/showcase_base.gd"

const DURATION := 8.0

var _flows: Array[CatMaskFlow] = []


func _build() -> void:
	caption_text = "마스크 흐름 (MaskFlow)"
	# [제목, 방향, static, 문구들, interval]
	var specs := [
		["LEFT (←)", CatMaskFlow.FlowDirection.LEFT, false, ["Breaking news 속보", "Event starts now"], 0.0],
		["RIGHT (→)", CatMaskFlow.FlowDirection.RIGHT, false, ["Right flow 오른쪽 흐름", "Second"], 0.0],
		["TOP (↑ 한 줄씩)", CatMaskFlow.FlowDirection.TOP, false, ["First line", "Second line", "Third line"], 0.9],
		["BOTTOM (↓ 한 줄씩)", CatMaskFlow.FlowDirection.BOTTOM, false, ["Down one", "Down two", "Down three"], 0.9],
		["static: 맞으면 정지", CatMaskFlow.FlowDirection.LEFT, true, ["Fits the mask 정지"], 0.0],
		["static: 넘치면 흐름", CatMaskFlow.FlowDirection.LEFT, true, ["This long text overflows the mask so it flows 넘치면 흐릅니다"], 0.0],
	]
	for i in specs.size():
		var sp: Array = specs[i]
		var x := 60.0 + (i % 2) * 600.0
		var y := 120.0 + (i / 2) * 165.0
		var title := Label.new()
		title.add_theme_font_override(&"font", font)
		title.add_theme_font_size_override(&"font_size", 24)
		title.add_theme_color_override(&"font_color", Color(1, 0.82, 0.3))
		title.text = sp[0]
		title.position = Vector2(x, y)
		add_child(title)
		var frame := ColorRect.new()
		frame.color = Color(0.05, 0.06, 0.09)
		frame.position = Vector2(x, y + 38)
		frame.size = Vector2(560, 70)
		add_child(frame)
		var flow := CatMaskFlow.new()
		flow.position = Vector2(x, y + 38)
		flow.size = Vector2(560, 70)
		flow.direction = sp[1]
		flow.static_mode = sp[2]
		flow.interval = sp[4]
		flow.velocity = 110.0
		flow.gap = 60.0
		var tpl := Label.new()
		tpl.add_theme_font_override(&"font", font)
		tpl.add_theme_font_size_override(&"font_size", 36)
		tpl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tpl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if sp[1] == CatMaskFlow.FlowDirection.TOP or sp[1] == CatMaskFlow.FlowDirection.BOTTOM else HORIZONTAL_ALIGNMENT_LEFT
		tpl.text = sp[3][0]
		flow.add_child(tpl)
		add_child(flow)
		flow.set_text_entries(PackedStringArray(sp[3]))
		_flows.append(flow)
	set_info("direction = LEFT / RIGHT / TOP / BOTTOM   static_mode (맞으면 정지, 넘치면 흐름)   velocity=110")
