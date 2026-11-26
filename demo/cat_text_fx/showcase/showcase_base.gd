extends Control
## 쇼케이스 씬 공통 베이스. 배경·캡션·값 표시줄·한글 폰트를 만들고, 시간(t)에 따라 _step을 호출한다.
## DURATION은 각 씬 스크립트의 const이며 tools/record_showcase.sh가 녹화 길이로 읽는다.

const SIZE := Vector2(1280, 720)

var caption_text := ""
var bg_color := Color(0.15, 0.17, 0.23)
var t := 0.0
var font: SystemFont
var _caption: Label
var _info: Label
var _stage_cache := {}
var _pending_info := ""


func _ready() -> void:
	position = Vector2.ZERO
	size = SIZE
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Apple SD Gothic Neo", "Noto Sans CJK KR", "Malgun Gothic"])
	font.font_weight = 700
	var bg := ColorRect.new()
	bg.color = bg_color
	bg.size = SIZE
	add_child(bg)
	_build()
	_caption = _make_label(44, Color(1, 1, 1), 28.0)
	_caption.text = caption_text
	_info = _make_label(26, Color(0.62, 0.8, 0.95), SIZE.y - 70.0)
	_info.text = _pending_info


## 서브클래스가 오버라이드한다.
func _build() -> void:
	pass


func _step(_time: float) -> void:
	pass


func _process(delta: float) -> void:
	t += delta
	_step(t)


func set_info(s: String) -> void:
	_pending_info = s
	if _info != null:
		_info.text = s


## 시간 t가 경계 목록 중 어느 구간인지(0부터). 구간이 바뀐 첫 호출에서만 changed가 true.
func stage(key: String, bounds: Array) -> Dictionary:
	var idx := 0
	for b: float in bounds:
		if t >= b:
			idx += 1
	var changed: bool = _stage_cache.get(key, -1) != idx
	_stage_cache[key] = idx
	return {"index": idx, "changed": changed}


func make_text(txt: String, font_size: int, y: float, h: float = 200.0) -> CatText:
	var ct := CatText.new()
	ct.font = font
	ct.font_size = font_size
	ct.text = txt
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ct.position = Vector2(0, y)
	ct.size = Vector2(SIZE.x, h)
	add_child(ct)
	return ct


func _make_label(font_size: int, color: Color, y: float) -> Label:
	var l := Label.new()
	l.add_theme_font_override(&"font", font)
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(SIZE.x, 50)
	add_child(l)
	return l


static func hex(c: Color) -> String:
	return "#" + c.to_html(false)
