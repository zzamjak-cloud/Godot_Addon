extends Control
## X(트위터) 공유용 CAT Text FX 트레일러(1920x1080, 60fps).
## 화면 속 텍스트 연출은 애드온 노드(CatText·Outline·Glow·Curve·Animation·MaskFlow)로 만든다.
## 시간은 프레임 번호로 계산하므로 Movie Maker(--fixed-fps 60)에서 매번 같은 결과가 나온다.
## DURATION은 tools/record_trailer.sh가 녹화 길이로 읽는다.

const DURATION := 29.0
const SIZE := Vector2(1920, 1080)
const FPS := 60.0

const BG := Color("161a26")
const AMBER := Color("ffb13b")
const SKY := Color("8fd3ff")
const INK := Color("0d1018")
const DIM := Color("8b93a7")
const WHITE := Color("f4f6fb")

## [시작 시각(초), 컷 이름]. 컷마다 _build_<이름>(root)과 _upd_<이름>(local_time)을 둔다.
const CUTS := [
	[0.0, "cold"],
	[2.5, "title"],
	[5.5, "outline"],
	[7.1, "shadow"],
	[8.6, "second_face"],
	[10.1, "glow"],
	[11.7, "curve"],
	[13.5, "appear"],
	[15.1, "loop"],
	[16.6, "impact"],
	[18.5, "marquee"],
	[20.0, "code"],
	[23.5, "grid"],
	[26.0, "end"],
]
const PUNCH_TIME := 0.2

var sans: Font
var sans_regular: SystemFont
var mono: SystemFont

var _frame := 0
var _cut := -1
var _cut_start := 0.0
var _stage: Control
var _root: Control
var _upd: Callable
## 현재 컷 전용 상태. 컷이 바뀌면 비운다.
var _v := {}


func _ready() -> void:
	position = Vector2.ZERO
	size = SIZE
	# SystemFont의 font_weight는 .ttc(Apple SD Gothic Neo)에서 굵은 face를 고르지 못해 Regular가 나오므로 embolden으로 굵힌다.
	var bold := FontVariation.new()
	bold.base_font = _make_font(["Apple SD Gothic Neo", "Noto Sans CJK KR", "Malgun Gothic"], 800)
	bold.variation_embolden = 0.9
	sans = bold
	sans_regular = _make_font(["Apple SD Gothic Neo", "Noto Sans CJK KR", "Malgun Gothic"], 400)
	mono = _make_font(["Menlo", "SF Mono", "Consolas", "DejaVu Sans Mono"], 700)
	mono.fallbacks = [sans]

	_stage = Control.new()
	_stage.size = SIZE
	_stage.pivot_offset = SIZE * 0.5
	add_child(_stage)
	_stage.add_child(Backdrop.new())
	_stage.add_child(_make_vignette())


func _process(_delta: float) -> void:
	var t := _frame / FPS
	_frame += 1
	var idx := 0
	for i in CUTS.size():
		if t >= CUTS[i][0]:
			idx = i
	if idx != _cut:
		_enter_cut(idx)
	var lt := t - _cut_start
	# 컷 전환 순간 화면 전체 스케일 펀치(1.03 → 1.0).
	var p := clampf(lt / PUNCH_TIME, 0.0, 1.0) if _cut > 0 else 1.0
	_stage.scale = Vector2.ONE * lerpf(1.03, 1.0, 1.0 - pow(1.0 - p, 3.0))
	_upd.call(lt)


func _enter_cut(idx: int) -> void:
	if _root != null:
		_root.visible = false
		_root.queue_free()
	_cut = idx
	_cut_start = CUTS[idx][0]
	_v = {}
	_root = Control.new()
	_root.size = SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_root)
	var cut_name: String = CUTS[idx][1]
	call("_build_" + cut_name, _root)
	_upd = Callable(self, "_upd_" + cut_name)


#region 공용 도우미

func _make_font(names: Array, weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	return f


func _make_vignette() -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.08), Color(0, 0, 0, 0.6)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 480
	tex.height = 270
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.25, 0.5)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _text(parent: Control, s: String, font_size: int, rect: Rect2, color: Color = WHITE,
		f: Font = null, halign: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> CatText:
	var ct := CatText.new()
	ct.font = f if f != null else sans
	ct.font_size = font_size
	ct.font_color = color
	ct.text = s
	ct.horizontal_alignment = halign
	ct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ct.position = rect.position
	ct.size = rect.size
	ct.pivot_offset = rect.size * 0.5
	ct.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ct)
	return ct


func _outline(ct: CatText, color: Color, width: float, softness: float = 0.0) -> CatTextOutline:
	var ol := CatTextOutline.new()
	ol.set_outline(color, width, softness)
	ct.add_child(ol)
	return ol


func _glow(ct: CatText, color: Color, glow_range: float) -> CatTextGlow:
	var gl := CatTextGlow.new()
	gl.set_glow(color, glow_range)
	ct.add_child(gl)
	return gl


func _anim(ct: CatText) -> CatTextAnimation:
	var a := CatTextAnimation.new()
	a.play_on_ready = false
	ct.add_child(a)
	return a


## 몽타주 공통: 왼쪽 위 번호 + 모노 기능명, 왼쪽 아래 API 힌트.
func _header(root: Control, number: String, label: String, hint: String) -> void:
	var bar := ColorRect.new()
	bar.color = AMBER
	bar.position = Vector2(84, 78)
	bar.size = Vector2(8, 48)
	root.add_child(bar)
	if number != "":
		_text(root, number, 34, Rect2(112, 72, 80, 60), DIM, mono, HORIZONTAL_ALIGNMENT_LEFT)
	_text(root, label, 44, Rect2(112 if number == "" else 180, 70, 900, 64), AMBER, mono, HORIZONTAL_ALIGNMENT_LEFT)
	if hint != "":
		_text(root, hint, 30, Rect2(92, 960, 1700, 60), SKY, mono, HORIZONTAL_ALIGNMENT_LEFT)


## 텍스트를 바꾸고 바로 셰이핑해 애니메이션 재시작을 지금 끝낸 뒤 임팩트를 건다.
func _set_text_and_impact(ct: CatText, a: CatTextAnimation, s: String, rot: float) -> void:
	ct.text = s
	ct.get_cluster_count()
	a.impact_rotation = rot
	a.trigger_impact()


static func _ease_out(x: float) -> float:
	var c := clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - c, 3.0)

#endregion


#region 0. 콜드 오픈 — 평범한 Label

func _build_cold(root: Control) -> void:
	var tag := Label.new()
	tag.add_theme_font_override(&"font", mono)
	tag.add_theme_font_size_override(&"font_size", 30)
	tag.add_theme_color_override(&"font_color", Color(0.45, 0.48, 0.55))
	tag.text = "Label"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.position = Vector2(0, 420)
	tag.size = Vector2(SIZE.x, 50)
	root.add_child(tag)
	var l := Label.new()
	l.add_theme_font_override(&"font", sans_regular)
	l.add_theme_font_size_override(&"font_size", 76)
	l.add_theme_color_override(&"font_color", Color(0.62, 0.64, 0.68))
	l.text = "Godot Label, 이대로 괜찮을까?"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector2(0, 470)
	l.size = Vector2(SIZE.x, 140)
	root.add_child(l)
	_v.label = l
	_v.tag = tag


const _FLICKER := "1100101101000110010000"


func _upd_cold(lt: float) -> void:
	var l: Label = _v.label
	var tag: Label = _v.tag
	if lt < 1.8:
		return
	var f := int((lt - 1.8) * FPS) / 2
	var on := f < _FLICKER.length() and _FLICKER[f] == "1"
	l.visible = on
	tag.visible = on
	l.position.x = float((f * 37) % 13 - 6) * 3.0 if on else 0.0

#endregion


#region 1. 타이틀

func _build_title(root: Control) -> void:
	var ct := _text(root, "CAT Text FX", 210, Rect2(0, 290, SIZE.x, 320))
	_outline(ct, INK, 0.3)
	_glow(ct, Color(AMBER, 0.5), 0.32)
	var a := _anim(ct)
	a.character_delay = 0.045
	a.appear_position = Vector2(0, -150)
	a.appear_scale = Vector2(0.3, 0.3)
	a.appear_rotation = -14.0
	a.appear_duration = 0.55
	a.appear_ease = CatEase.Type.OUT_BACK
	a.enable_impact = true
	a.impact_scale = Vector2(1.35, 1.35)
	a.impact_position = Vector2(0, -24)
	a.impact_duration = 0.32
	a.impact_character_delay = 0.025
	a.play()
	var sub := _text(root, "Text effects for Godot 4", 56, Rect2(0, 620, SIZE.x, 90), SKY)
	sub.modulate.a = 0.0
	_v.anim = a
	_v.sub = sub
	_v.impact = false


func _upd_title(lt: float) -> void:
	var sub: CatText = _v.sub
	var k := _ease_out((lt - 0.9) / 0.45)
	sub.modulate.a = k
	sub.position.y = 620.0 + (1.0 - k) * 24.0
	if lt >= 1.45 and not _v.impact:
		_v.impact = true
		(_v.anim as CatTextAnimation).trigger_impact()

#endregion


#region 2~10. 기능 몽타주

func _build_outline(root: Control) -> void:
	_header(root, "01", "OUTLINE", "CatTextOutline.set_outline(color, width, softness)")
	var ct := _text(root, "OUTLINE 외곽선", 170, Rect2(0, 340, SIZE.x, 400))
	_v.ct = ct
	_v.ol = _outline(ct, SKY, 0.18)


func _upd_outline(lt: float) -> void:
	var ct: CatText = _v.ct
	ct.scale = Vector2.ONE * (1.0 + 0.05 * lt / 1.6)
	# 두께는 단계 전환만 한다.
	var step := 0 if lt < 0.55 else (1 if lt < 1.1 else 2)
	if _v.get("step", -1) != step:
		_v.step = step
		var ol: CatTextOutline = _v.ol
		match step:
			0:
				ol.set_outline(SKY, 0.18)
			1:
				ol.set_outline(AMBER, 0.34)
			2:
				ol.set_outline(Color("ff4f8b"), 0.24, 0.6)


func _build_shadow(root: Control) -> void:
	_header(root, "02", "SHADOW", "enable_shadow  ·  shadow_offset  ·  shadow_alpha")
	var ct := _text(root, "SHADOW 그림자", 170, Rect2(0, 340, SIZE.x, 400))
	var ol := _outline(ct, Color("1b2a6b"), 0.16)
	ol.enable_shadow = true
	ol.shadow_alpha = 0.8
	_v.ol = ol


func _upd_shadow(lt: float) -> void:
	var ol: CatTextOutline = _v.ol
	# 광원이 도는 것처럼 그림자 방향만 움직인다(크기는 고정).
	var ang := deg_to_rad(20.0 + lt * 140.0)
	ol.shadow_offset = Vector2(cos(ang), sin(ang)) * 0.13


func _build_second_face(root: Control) -> void:
	_header(root, "03", "SECOND FACE", "enable_second_face  ·  use_second_face_gradient")
	var ct := _text(root, "SECOND FACE", 190, Rect2(0, 340, SIZE.x, 400))
	var ol := _outline(ct, INK, 0.22)
	ol.enable_second_face = true
	ol.use_second_face_gradient = true
	ol.second_face_dilate = -0.06
	_v.ct = ct
	_v.ol = ol


func _upd_second_face(lt: float) -> void:
	var ol: CatTextOutline = _v.ol
	var h := lt * 0.35
	ol.second_face_gradient_top_left = Color.from_hsv(fmod(h, 1.0), 0.7, 1.0)
	ol.second_face_gradient_top_right = Color.from_hsv(fmod(h + 0.12, 1.0), 0.7, 1.0)
	ol.second_face_gradient_bottom_left = Color.from_hsv(fmod(h + 0.55, 1.0), 0.75, 1.0)
	ol.second_face_gradient_bottom_right = Color.from_hsv(fmod(h + 0.7, 1.0), 0.75, 1.0)
	(_v.ct as CatText).scale = Vector2.ONE * (1.04 - 0.04 * _ease_out(lt / 0.6))


func _build_glow(root: Control) -> void:
	_header(root, "04", "GLOW", "CatTextGlow.set_glow(color, range)  ·  inner_glow_alpha")
	var ct := _text(root, "GLOW 글로우", 190, Rect2(0, 340, SIZE.x, 400))
	_v.gl = _glow(ct, Color(AMBER, 0.5), 0.32)


func _upd_glow(lt: float) -> void:
	var gl: CatTextGlow = _v.gl
	# 색만 프레임마다 바꾼다. 범위는 고정.
	gl.glow_color = Color.from_hsv(fmod(0.11 + lt * 0.4, 1.0), 0.75, 1.0, 0.65)


func _build_curve(root: Control) -> void:
	_header(root, "05", "CURVE", "set_arch_curve()  →  set_wave_curve()  ·  curve_scale")
	var ct := _text(root, "ARCH & WAVE 곡선", 140, Rect2(0, 290, SIZE.x, 500))
	_outline(ct, INK, 0.16)
	var cv := CatTextCurve.new()
	cv.enable_dynamic_curve_scale = false
	ct.add_child(cv)
	cv.set_arch_curve(0.0)
	_v.cv = cv
	_v.mode = 0


func _upd_curve(lt: float) -> void:
	var cv: CatTextCurve = _v.cv
	if lt < 0.85:
		cv.curve_scale = 150.0 * _ease_out(lt / 0.5)
		return
	if _v.mode == 0:
		_v.mode = 1
		cv.set_wave_curve(0.0, 1.0)
	cv.curve_scale = 60.0 * sin((lt - 0.85) * 5.0) * _ease_out((lt - 0.85) / 0.25)


func _build_appear(root: Control) -> void:
	_header(root, "06", "APPEAR", "CatTextAnimation  ·  appear_ease = OUT_BOUNCE")
	var ct := _text(root, "등장 애니메이션!", 160, Rect2(0, 340, SIZE.x, 400))
	_outline(ct, Color("b3261e"), 0.2)
	var a := _anim(ct)
	a.character_delay = 0.05
	a.appear_position = Vector2(0, -220)
	a.appear_scale = Vector2(0.6, 0.6)
	a.appear_rotation = -25.0
	a.appear_duration = 0.6
	a.appear_ease = CatEase.Type.OUT_BOUNCE
	a.play()


func _upd_appear(_lt: float) -> void:
	pass


func _build_loop(root: Control) -> void:
	_header(root, "07", "LOOP", "enable_loop  ·  loop_type = YOYO  ·  loop_count = -1")
	var ct := _text(root, "둥실둥실 LOOP", 170, Rect2(0, 340, SIZE.x, 400))
	_outline(ct, Color("2a6fb3"), 0.2)
	var a := _anim(ct)
	a.enable_appear = false
	a.enable_loop = true
	a.loop_count = -1
	a.loop_position = Vector2(0, -60)
	a.loop_scale = Vector2(1.12, 1.12)
	a.loop_duration = 0.4
	a.character_delay = 0.07
	a.play()


func _upd_loop(_lt: float) -> void:
	pass


func _build_impact(root: Control) -> void:
	_header(root, "08", "IMPACT", "trigger_impact()")
	var combo := _text(root, "COMBO", 110, Rect2(0, 250, SIZE.x, 160), SKY)
	_outline(combo, INK, 0.2)
	var ct := _text(root, "x1", 280, Rect2(0, 400, SIZE.x, 420), AMBER)
	_outline(ct, Color("7a1410"), 0.22)
	var a := _anim(ct)
	a.enable_appear = false
	a.enable_loop = true
	a.loop_count = -1
	a.loop_position = Vector2(0, -8)
	a.loop_duration = 0.3
	a.enable_impact = true
	a.impact_scale = Vector2(1.55, 1.55)
	a.impact_duration = 0.13
	a.impact_character_delay = 0.0
	a.play()
	a.trigger_impact()
	_v.ct = ct
	_v.anim = a
	_v.count = 1


func _upd_impact(lt: float) -> void:
	# 0.1초부터 0.125초마다 1씩 올려 1.5초 안에 x12.
	var target := mini(12, 1 + int(maxf(lt - 0.1, 0.0) / 0.125))
	if target != _v.count:
		_v.count = target
		var rot := 9.0 if target % 2 == 0 else -9.0
		_set_text_and_impact(_v.ct, _v.anim, "x%d" % target, rot)


func _build_marquee(root: Control) -> void:
	_header(root, "09", "MARQUEE", "CatMaskFlow  ·  direction = LEFT / RIGHT  ·  velocity")
	_v.flows = [
		_make_flow(root, Rect2(0, 340, SIZE.x, 170), "BREAKING  ·  CAT Text FX  ·  전광판 흐름  ·  ", 110,
				AMBER, Color("0e1119"), CatMaskFlow.FlowDirection.LEFT, 700.0),
		_make_flow(root, Rect2(0, 560, SIZE.x, 130), "MASK FLOW  ·  마스크 영역 안에서 흐르는 텍스트  ·  ", 76,
				SKY, Color("101522"), CatMaskFlow.FlowDirection.RIGHT, 520.0),
	]


func _make_flow(root: Control, rect: Rect2, s: String, font_size: int, color: Color, band: Color,
		dir: CatMaskFlow.FlowDirection, velocity: float) -> CatMaskFlow:
	var bg := ColorRect.new()
	bg.color = band
	bg.position = rect.position
	bg.size = rect.size
	root.add_child(bg)
	var flow := CatMaskFlow.new()
	flow.position = rect.position
	flow.size = rect.size
	flow.direction = dir
	flow.velocity = velocity
	flow.gap = 0.0
	var tpl := CatText.new()
	tpl.font = sans
	tpl.font_size = font_size
	tpl.font_color = color
	tpl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tpl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tpl.text = s
	var ol := CatTextOutline.new()
	ol.set_outline(INK, 0.12)
	tpl.add_child(ol)
	flow.add_child(tpl)
	root.add_child(flow)
	return flow


func _upd_marquee(_lt: float) -> void:
	pass

#endregion


#region 11. 코드 → 결과

## [BBCode 줄, 순수 텍스트 줄, 타이핑 시작, 타이핑 끝]
const _CODE := [
	["[color=#ff7ab6]var[/color] fx := [color=#8fd3ff]CatText[/color].new()", "var fx := CatText.new()", 0.15, 0.5],
	["fx.text = [color=#ffb13b]\"레벨 업! LEVEL UP\"[/color]", "fx.text = \"레벨 업! LEVEL UP\"", 0.55, 0.95],
	["fx.add_child([color=#8fd3ff]CatTextGlow[/color].new())", "fx.add_child(CatTextGlow.new())", 1.0, 1.4],
	["fx.add_child([color=#8fd3ff]CatTextAnimation[/color].new())", "fx.add_child(CatTextAnimation.new())", 1.45, 1.9],
]
const _CODE_FONT_SIZE := 34
const _CODE_ORIGIN := Vector2(150, 330)
const _CODE_LINE_H := 70.0


func _build_code(root: Control) -> void:
	_header(root, "", "CODE → RESULT", "")
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0e1119")
	sb.border_color = Color("2a3145")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	panel.add_theme_stylebox_override(&"panel", sb)
	panel.position = Vector2(70, 190)
	panel.size = Vector2(930, 520)
	root.add_child(panel)
	_text(root, "player.gd", 26, Rect2(100, 210, 400, 50), DIM, mono, HORIZONTAL_ALIGNMENT_LEFT)
	var lines: Array[RichTextLabel] = []
	for i in _CODE.size():
		var num := _text(root, str(i + 1), _CODE_FONT_SIZE, Rect2(96, _CODE_ORIGIN.y + i * _CODE_LINE_H, 40, _CODE_LINE_H),
				Color(0.35, 0.38, 0.46), mono, HORIZONTAL_ALIGNMENT_RIGHT)
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.scroll_active = false
		rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
		rtl.add_theme_font_override(&"normal_font", mono)
		rtl.add_theme_font_size_override(&"normal_font_size", _CODE_FONT_SIZE)
		rtl.add_theme_color_override(&"default_color", Color("d8dee9"))
		rtl.text = _CODE[i][0]
		rtl.visible_characters = 0
		rtl.position = Vector2(_CODE_ORIGIN.x + 10, _CODE_ORIGIN.y + i * _CODE_LINE_H + 12)
		rtl.size = Vector2(820, _CODE_LINE_H)
		root.add_child(rtl)
		lines.append(rtl)
	var cursor := ColorRect.new()
	cursor.color = AMBER
	cursor.size = Vector2(4, 44)
	root.add_child(cursor)
	# 결과 영역
	var frame := Panel.new()
	var sb2 := StyleBoxFlat.new()
	sb2.bg_color = Color(1, 1, 1, 0.02)
	sb2.border_color = Color(SKY, 0.25)
	sb2.set_border_width_all(2)
	sb2.set_corner_radius_all(18)
	frame.add_theme_stylebox_override(&"panel", sb2)
	frame.position = Vector2(1040, 190)
	frame.size = Vector2(810, 520)
	root.add_child(frame)
	_text(root, "RESULT", 26, Rect2(1070, 210, 300, 50), Color(SKY, 0.7), mono, HORIZONTAL_ALIGNMENT_LEFT)
	_v.lines = lines
	_v.cursor = cursor
	_v.stage = 0
	_v.result_root = root


func _upd_code(lt: float) -> void:
	var lines: Array = _v.lines
	var cursor: ColorRect = _v.cursor
	var active := -1
	for i in _CODE.size():
		var c: Array = _CODE[i]
		var plain: String = c[1]
		var k := clampf((lt - c[2]) / (c[3] - c[2]), 0.0, 1.0)
		var n := int(round(k * plain.length()))
		(lines[i] as RichTextLabel).visible_characters = n
		if lt >= c[2]:
			active = i
			var w := mono.get_string_size(plain.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, -1, _CODE_FONT_SIZE).x
			cursor.position = Vector2(_CODE_ORIGIN.x + 10 + w + 4, _CODE_ORIGIN.y + i * _CODE_LINE_H + 14)
	var typing: bool = active >= 0 and lt < _CODE[active][3]
	cursor.visible = active >= 0 and (typing or int(lt * 2.5) % 2 == 0) and lt < 2.4
	# 코드 한 줄이 끝날 때마다 오른쪽 결과에 그 줄을 그대로 실행한다.
	var stage := 0
	for i in _CODE.size():
		if lt >= _CODE[i][3]:
			stage = i + 1
	while _v.stage < stage:
		_v.stage += 1
		_run_code_line(_v.stage)
	if lt >= 2.3 and not _v.has("caption"):
		var cap := _text(_v.result_root, "노드 몇 개면 끝", 104, Rect2(0, 760, SIZE.x, 170))
		_outline(cap, Color("2a6fb3"), 0.2)
		var a := _anim(cap)
		a.character_delay = 0.05
		a.appear_position = Vector2(0, 60)
		a.appear_scale = Vector2(0.4, 0.4)
		a.appear_duration = 0.45
		a.play()
		_v.caption = cap


func _run_code_line(line: int) -> void:
	match line:
		1:
			var fx := CatText.new()
			# 위치·폰트는 화면 배치용(코드 밖 설정).
			fx.font = sans
			fx.font_size = 84
			fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fx.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			fx.position = Vector2(1040, 290)
			fx.size = Vector2(810, 360)
			(_v.result_root as Control).add_child(fx)
			_v.fx = fx
		2:
			(_v.fx as CatText).text = "레벨 업! LEVEL UP"
		3:
			(_v.fx as CatText).add_child(CatTextGlow.new())
		4:
			(_v.fx as CatText).add_child(CatTextAnimation.new())

#endregion


#region 12. 그리드

const _GRID_W := 640.0
const _GRID_H := 540.0


func _build_grid(root: Control) -> void:
	for i in 2:
		var hl := ColorRect.new()
		hl.color = Color(1, 1, 1, 0.08)
		hl.position = Vector2(_GRID_W * (i + 1) - 1, 0)
		hl.size = Vector2(2, SIZE.y)
		root.add_child(hl)
	var vl := ColorRect.new()
	vl.color = Color(1, 1, 1, 0.08)
	vl.position = Vector2(0, _GRID_H - 1)
	vl.size = Vector2(SIZE.x, 2)
	root.add_child(vl)
	var labels := ["OUTLINE + LOOP", "GLOW", "CURVE", "SECOND FACE", "IMPACT", "MARQUEE"]
	for i in 6:
		var o := _cell_origin(i)
		_text(root, labels[i], 28, Rect2(o.x + 36, o.y + 30, 560, 44), AMBER, mono, HORIZONTAL_ALIGNMENT_LEFT)
	var body := Vector2(_GRID_W, 380)
	# 0: 외곽선 + 루프
	var c0 := _text(root, "외곽선", 120, Rect2(_cell_origin(0) + Vector2(0, 100), body))
	_outline(c0, SKY, 0.3)
	var a0 := _anim(c0)
	a0.enable_appear = false
	a0.enable_loop = true
	a0.loop_count = -1
	a0.loop_position = Vector2(0, -30)
	a0.loop_duration = 0.45
	a0.character_delay = 0.1
	a0.play()
	# 1: 글로우
	_v.gl = _glow(_text(root, "GLOW", 140, Rect2(_cell_origin(1) + Vector2(0, 100), body)), Color(AMBER, 0.5), 0.32)
	# 2: 곡선(웨이브)
	var c2 := _text(root, "WAVE 웨이브", 84, Rect2(_cell_origin(2) + Vector2(0, 100), body))
	_outline(c2, INK, 0.16)
	var cv := CatTextCurve.new()
	cv.enable_dynamic_curve_scale = false
	c2.add_child(cv)
	cv.set_wave_curve(0.0, 1.0)
	_v.cv = cv
	# 3: 세컨드 페이스
	var c3 := _text(root, "GRADIENT", 104, Rect2(_cell_origin(3) + Vector2(0, 100), body))
	var ol3 := _outline(c3, INK, 0.22)
	ol3.enable_second_face = true
	ol3.use_second_face_gradient = true
	ol3.second_face_dilate = -0.06
	_v.ol3 = ol3
	# 4: 임팩트
	var c4 := _text(root, "HIT!", 150, Rect2(_cell_origin(4) + Vector2(0, 100), body), AMBER)
	_outline(c4, Color("7a1410"), 0.22)
	var a4 := _anim(c4)
	a4.enable_appear = false
	a4.enable_loop = true
	a4.loop_count = -1
	a4.loop_position = Vector2.ZERO
	a4.enable_impact = true
	a4.impact_scale = Vector2(1.5, 1.5)
	a4.impact_rotation = 10.0
	a4.impact_duration = 0.2
	a4.impact_character_delay = 0.03
	a4.play()
	_v.a4 = a4
	_v.next_hit = 0.3
	# 5: 마퀴
	_make_flow(root, Rect2(_cell_origin(5) + Vector2(30, 200), Vector2(_GRID_W - 60, 120)),
			"속보  ·  BREAKING  ·  전광판  ·  ", 72, AMBER, Color("0e1119"), CatMaskFlow.FlowDirection.LEFT, 360.0)


func _cell_origin(i: int) -> Vector2:
	return Vector2((i % 3) * _GRID_W, (i / 3) * _GRID_H)


func _upd_grid(lt: float) -> void:
	(_v.gl as CatTextGlow).glow_color = Color.from_hsv(fmod(0.11 + lt * 0.4, 1.0), 0.75, 1.0, 0.65)
	(_v.cv as CatTextCurve).curve_scale = 40.0 * sin(lt * 5.0)
	var ol3: CatTextOutline = _v.ol3
	var h := lt * 0.35
	ol3.second_face_gradient_top_left = Color.from_hsv(fmod(h, 1.0), 0.7, 1.0)
	ol3.second_face_gradient_top_right = Color.from_hsv(fmod(h + 0.12, 1.0), 0.7, 1.0)
	ol3.second_face_gradient_bottom_left = Color.from_hsv(fmod(h + 0.55, 1.0), 0.75, 1.0)
	ol3.second_face_gradient_bottom_right = Color.from_hsv(fmod(h + 0.7, 1.0), 0.75, 1.0)
	if lt >= _v.next_hit:
		_v.next_hit += 0.55
		(_v.a4 as CatTextAnimation).trigger_impact()

#endregion


#region 13. 엔드카드

func _build_end(root: Control) -> void:
	var title := _text(root, "CAT Text FX", 190, Rect2(0, 230, SIZE.x, 300))
	_outline(title, INK, 0.3)
	_glow(title, Color(AMBER, 0.5), 0.32)
	var a := _anim(title)
	a.character_delay = 0.035
	a.appear_position = Vector2(0, -90)
	a.appear_scale = Vector2(0.3, 0.3)
	a.appear_duration = 0.5
	a.play()
	_end_line(root, "Godot 4.7+  ·  GDScript  ·  MIT", 54, 540, SKY, 0.35)
	var link := _end_line(root, "zzamjak-cloud.github.io/Godot_Addon", 64, 650, AMBER, 0.6)
	_outline(link, INK, 0.12)
	_end_line(root, "Unity TMPEffect → Godot", 36, 790, DIM, 0.9)


func _end_line(root: Control, s: String, font_size: int, y: float, color: Color, delay: float) -> CatText:
	var ct := _text(root, s, font_size, Rect2(0, y, SIZE.x, font_size * 1.8), color)
	var a := _anim(ct)
	a.initial_delay = delay
	a.character_delay = 0.012
	a.appear_position = Vector2(0, 30)
	a.appear_scale = Vector2.ONE
	a.appear_duration = 0.35
	a.appear_ease = CatEase.Type.OUT_CUBIC
	a.play()
	return ct


func _upd_end(_lt: float) -> void:
	pass

#endregion


## 아주 옅은 격자 배경.
class Backdrop extends Control:
	func _ready() -> void:
		size = Vector2(1920, 1080)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("161a26"))
		var c := Color(1, 1, 1, 0.025)
		var step := 60.0
		var x := 0.0
		while x <= size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), c, 1.0)
			x += step
		var y := 0.0
		while y <= size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), c, 1.0)
			y += step
