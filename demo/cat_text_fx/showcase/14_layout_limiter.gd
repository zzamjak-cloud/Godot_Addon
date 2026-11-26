extends "res://demo/cat_text_fx/showcase/showcase_base.gd"

const DURATION := 8.0
const _FULL := "Cat Text FX keeps long game text inside a fixed width and wraps it automatically."
const _MAX_WIDTH := 520.0

var _ct: CatText
var _panel: PanelContainer
var _grow_start := 0.5
var _chars_per_sec := 15.0


func _build() -> void:
	caption_text = "레이아웃 리미터 (CatLayoutLimiter)"
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.18)
	sb.set_content_margin_all(20)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.4, 0.6, 0.9)
	_panel.add_theme_stylebox_override(&"panel", sb)
	_panel.position = Vector2(380, 170)
	_panel.size_flags_horizontal = 0
	add_child(_panel)
	_ct = CatText.new()
	_ct.font = font
	_ct.font_size = 40
	_ct.text = "C"
	_panel.add_child(_ct)
	var lim := CatLayoutLimiter.new()
	lim.max_width = _MAX_WIDTH
	_ct.add_child(lim)
	# 한도선(패널 안쪽 왼쪽 + max_width)
	var guide := ColorRect.new()
	guide.color = Color(1, 0.35, 0.35, 0.8)
	guide.position = Vector2(380 + 22 + _MAX_WIDTH, 150)
	guide.size = Vector2(2, 420)
	add_child(guide)
	var gl := Label.new()
	gl.add_theme_font_override(&"font", font)
	gl.add_theme_font_size_override(&"font_size", 22)
	gl.add_theme_color_override(&"font_color", Color(1, 0.5, 0.5))
	gl.text = "max_width=520"
	gl.position = Vector2(380 + 22 + _MAX_WIDTH - 90, 125)
	add_child(gl)


func _step(time: float) -> void:
	var n := clampi(int((time - _grow_start) * _chars_per_sec) + 1, 1, _FULL.length())
	_ct.text = _FULL.substr(0, n)
	set_info("글자 %d개  max_width=%d  텍스트 폭 도달 시 줄바꿈 (autowrap=%s)" % [n, _MAX_WIDTH, "ON" if _ct.autowrap_mode != TextServer.AUTOWRAP_OFF else "OFF"])
