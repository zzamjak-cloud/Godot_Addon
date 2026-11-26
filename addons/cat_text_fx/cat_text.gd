@tool
class_name CatText
extends Control
## Label을 대체하는 텍스트 노드. 글자(클러스터) 단위로 변환·외곽선·글로우를 그린다.
## 자식 CatTextOutline / CatTextGlow / CatTextCurve / CatTextAnimation이 그리기에 참여한다.

## 재셰이핑 직후 발생한다(클러스터 수가 바뀌었을 수 있음).
signal reshaped

## 시각 보정값: dilate 1.0 = 0.15em 바깥 두께.
const DILATE_EM := 0.15
## 시각 보정값: underlay offset 1.0 = 0.25em.
const UNDERLAY_OFFSET_EM := 0.25
## 시각 보정값: glow_range 1.0 = 0.3em 번짐 반경.
const GLOW_EM := 0.3
## SDF 소프트니스는 가장자리 바깥으로도 번지므로 softness 1.0당 반경을 0.5만큼 더한다.
const SOFTNESS_SPREAD := 0.5
## Inner Glow 링 반경(em).
const INNER_GLOW_RING_EM := 0.04
## TextServer 외곽선 링은 outline_size의 1/4만큼 바깥으로 나온다(측정값). 바깥 두께 px → outline_size 변환 계수.
const OUTLINE_SIZE_PER_PX := 4.0

const _GRADIENT_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 block_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 color_top_left : source_color = vec4(1.0);
uniform vec4 color_top_right : source_color = vec4(1.0);
uniform vec4 color_bottom_left : source_color = vec4(1.0);
uniform vec4 color_bottom_right : source_color = vec4(1.0);
varying vec2 local_pos;
void vertex() {
	local_pos = VERTEX;
}
void fragment() {
	vec2 t = clamp((local_pos - block_rect.xy) / max(block_rect.zw, vec2(0.001)), 0.0, 1.0);
	COLOR *= mix(mix(color_top_left, color_top_right, t.x), mix(color_bottom_left, color_bottom_right, t.x), t.y);
}
"""

static var _gradient_shader: Shader

@export_multiline var text: String = "":
	set(value):
		if text == value:
			return
		text = value
		_mark_shape_dirty()
@export var font: Font:
	set(value):
		if font == value:
			return
		if font != null and font.changed.is_connected(_mark_shape_dirty):
			font.changed.disconnect(_mark_shape_dirty)
		font = value
		if font != null:
			font.changed.connect(_mark_shape_dirty)
		_mark_shape_dirty()
## 0이면 테마(Label) font_size를 사용한다.
@export_range(0, 512, 1, "or_greater") var font_size: int = 0:
	set(value):
		if font_size == value:
			return
		font_size = maxi(value, 0)
		_mark_shape_dirty()
@export var font_color: Color = Color.WHITE:
	set(value):
		font_color = value
		queue_redraw()
@export var horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		horizontal_alignment = value
		_mark_layout_dirty()
@export var vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_TOP:
	set(value):
		vertical_alignment = value
		_mark_layout_dirty()
@export var autowrap_mode: TextServer.AutowrapMode = TextServer.AUTOWRAP_OFF:
	set(value):
		if autowrap_mode == value:
			return
		autowrap_mode = value
		_mark_shape_dirty()
@export var line_spacing: float = 0.0:
	set(value):
		line_spacing = value
		_mark_shape_dirty()
@export var uppercase: bool = false:
	set(value):
		if uppercase == value:
			return
		uppercase = value
		_mark_shape_dirty()

# 글자 상태 배열: 매 _draw에서 CatTextAnimation·CatTextCurve가 자기 배열을 참조로 넘겨주고,
# 넘겨주지 않으면 CatText 소유 배열(_own_*)을 기본값으로 채워 쓴다.
# Packed 배열은 참조로 전달되므로 남의 배열을 받은 상태에서 fill·resize하면 원본이 바뀐다.
var anim_pos := PackedVector2Array()
var anim_scale := PackedVector2Array()
var anim_rot := PackedFloat32Array()
var anim_alpha := PackedFloat32Array()
var anim_pivot := Vector2(0.5, 0.0)
var curve_offset_y := PackedFloat32Array()
var curve_angle := PackedFloat32Array()

var _own_pos := PackedVector2Array()
var _own_scale := PackedVector2Array()
var _own_rot := PackedFloat32Array()
var _own_alpha := PackedFloat32Array()
var _own_curve_y := PackedFloat32Array()
var _own_curve_angle := PackedFloat32Array()

var _para := TextParagraph.new()
# autowrap일 때 자연 크기 계산용(줄바꿈 없는 복사본)
var _natural_para := TextParagraph.new()
var _display_text := ""
var _shape_dirty := true
var _layout_dirty := true
var _reshape_pending := true
var _layout_version := 0
var _content_height := 0.0

# 클러스터 단위 데이터
var _c_char := PackedInt32Array()
var _c_visible := PackedByteArray()
var _c_origin := PackedVector2Array()
var _c_advance := PackedFloat32Array()
var _c_ascent := PackedFloat32Array()
var _c_glyph_start := PackedInt32Array()
var _c_glyph_count := PackedInt32Array()
# 글리프 단위 데이터(오프셋은 클러스터 원점 기준)
var _g_font: Array[RID] = []
var _g_size := PackedInt32Array()
var _g_index := PackedInt32Array()
var _g_offset := PackedVector2Array()

var _xf: Array[Transform2D] = []
var _text_bounds := Rect2()

# Second Face를 쓸 때만 만드는 내부 캔버스 아이템:
# F(face, second face 클립 그룹) > S(second face fill), S2(second face 링), I(inner glow)
var _face_item := RID()
var _second_item := RID()
var _second_ring_item := RID()
var _inner_item := RID()
var _gradient_material: ShaderMaterial
# self_modulate는 자식 아이템에 전파되지 않고 바뀌어도 다시 그리지 않으므로, 내부 아이템이 있을 때만 감시한다.
var _applied_self_modulate := Color.WHITE

var _anim_node: Node
var _curve_node: CatTextCurve
var _outline_node: CatTextOutline
var _glow_node: CatTextGlow


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	child_order_changed.connect(_refresh_modifiers)
	set_process(false)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_READY:
			_refresh_modifiers()
		NOTIFICATION_TRANSLATION_CHANGED, NOTIFICATION_THEME_CHANGED, NOTIFICATION_LAYOUT_DIRECTION_CHANGED:
			_mark_shape_dirty()
		NOTIFICATION_RESIZED:
			# autowrap 폭 변경은 재셰이핑 없이 줄 나눔만 다시 한다.
			if autowrap_mode != TextServer.AUTOWRAP_OFF and not _shape_dirty and _para.width != size.x:
				_para.width = size.x
				update_minimum_size()
			_mark_layout_dirty()
		NOTIFICATION_PREDELETE:
			_free_items()


func _process(_delta: float) -> void:
	if self_modulate != _applied_self_modulate:
		_apply_item_modulate()


func _get_minimum_size() -> Vector2:
	_ensure_layout()
	if autowrap_mode == TextServer.AUTOWRAP_OFF:
		return get_natural_size()
	return Vector2(0.0, _content_height)


#region 공개 읽기 API

## 줄바꿈 없는 자연 크기(가장 긴 줄 너비, 강제 줄바꿈만 적용한 높이).
func get_natural_size() -> Vector2:
	_ensure_shaped()
	if _display_text.is_empty():
		var f := _resolve_font()
		return Vector2(0.0, f.get_height(get_effective_font_size()) if f != null else 0.0)
	var p := _para if autowrap_mode == TextServer.AUTOWRAP_OFF else _natural_para
	var w := 0.0
	var h := 0.0
	var line_count := p.get_line_count()
	for l in line_count:
		w = maxf(w, p.get_line_width(l))
		h += p.get_line_ascent(l) + p.get_line_descent(l)
	h += line_spacing * maxi(line_count - 1, 0)
	return Vector2(w, h)


func get_cluster_count() -> int:
	_ensure_layout()
	return _c_char.size()


func get_cluster_char_index(k: int) -> int:
	_ensure_layout()
	return _c_char[k]


func is_cluster_visible(k: int) -> bool:
	_ensure_layout()
	return _c_visible[k] != 0


## (left, baseline - ascent, advance, ascent)
func get_cluster_rect(k: int) -> Rect2:
	_ensure_layout()
	var o := _c_origin[k]
	return Rect2(o.x, o.y - _c_ascent[k], _c_advance[k], _c_ascent[k])


func get_cluster_baseline(k: int) -> float:
	_ensure_layout()
	return _c_origin[k].y


func get_effective_font_size() -> int:
	if font_size > 0:
		return font_size
	return get_theme_font_size(&"font_size", &"Label")


## 가시 클러스터 rect의 합집합.
func get_text_bounds() -> Rect2:
	_ensure_layout()
	return _text_bounds


## 레이아웃(글자 위치)이 다시 계산될 때마다 증가한다. 모디파이어 캐시 무효화용.
func get_layout_version() -> int:
	_ensure_layout()
	return _layout_version


## 실제 표시 문자열(번역·대문자 변환 적용). char_index는 이 문자열 기준이다.
func get_display_text() -> String:
	_ensure_shaped()
	return _display_text


## 글자 최종 변환. 애니메이션(피벗 기준 회전→스케일→이동) 먼저, 곡선(베이스라인 중앙 기준) 나중.
static func compose_cluster_transform(pivot_center: Vector2, pos: Vector2, scl: Vector2, rot_deg: float,
		curve_center: Vector2, curve_y: float, curve_deg: float) -> Transform2D:
	var x := Transform2D.IDENTITY.translated(-pivot_center).rotated(deg_to_rad(rot_deg)).scaled(scl).translated(pivot_center + pos)
	var xc := Transform2D.IDENTITY.translated(-curve_center).rotated(deg_to_rad(curve_deg)).translated(curve_center + Vector2(0.0, curve_y))
	return xc * x

#endregion


#region 셰이핑

func _mark_shape_dirty() -> void:
	_shape_dirty = true
	_layout_dirty = true
	update_minimum_size()
	queue_redraw()


func _mark_layout_dirty() -> void:
	_layout_dirty = true
	queue_redraw()


func _resolve_font() -> Font:
	if font != null:
		return font
	return get_theme_font(&"font", &"Label")


func _break_flags() -> int:
	var trim := TextServer.BREAK_TRIM_START_EDGE_SPACES | TextServer.BREAK_TRIM_END_EDGE_SPACES
	match autowrap_mode:
		TextServer.AUTOWRAP_ARBITRARY:
			return TextServer.BREAK_MANDATORY | TextServer.BREAK_GRAPHEME_BOUND | trim
		TextServer.AUTOWRAP_WORD:
			return TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | trim
		TextServer.AUTOWRAP_WORD_SMART:
			return TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | trim
	return TextServer.BREAK_MANDATORY


func _ensure_shaped() -> void:
	if not _shape_dirty:
		return
	_shape_dirty = false
	_layout_dirty = true
	_reshape_pending = true
	_display_text = atr(text)
	if uppercase:
		_display_text = _display_text.to_upper()
	_para.clear()
	_para.break_flags = _break_flags()
	_para.line_spacing = line_spacing
	_para.direction = TextServer.DIRECTION_RTL if is_layout_rtl() else TextServer.DIRECTION_AUTO
	_para.width = size.x if autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0
	_natural_para.clear()
	var f := _resolve_font()
	if f != null and not _display_text.is_empty():
		_para.add_string(_display_text, f, get_effective_font_size())
		if autowrap_mode != TextServer.AUTOWRAP_OFF:
			_natural_para.break_flags = TextServer.BREAK_MANDATORY
			_natural_para.direction = _para.direction
			_natural_para.add_string(_display_text, f, get_effective_font_size())


func _ensure_layout() -> void:
	_ensure_shaped()
	if not _layout_dirty:
		return
	_layout_dirty = false
	var old_count := _c_char.size()
	_layout_clusters()
	_layout_version += 1
	var n := _c_char.size()
	if n != old_count:
		_resize_states(n)
	# 정렬·크기 변경만으로는 신호를 보내지 않는다(애니메이션 재시작 방지).
	if _reshape_pending or n != old_count:
		_reshape_pending = false
		reshaped.emit()


func _layout_clusters() -> void:
	var ts := TextServerManager.get_primary_interface()
	_c_char.clear()
	_c_visible.clear()
	_c_origin.clear()
	_c_advance.clear()
	_c_ascent.clear()
	_c_glyph_start.clear()
	_c_glyph_count.clear()
	_g_font.clear()
	_g_size.clear()
	_g_index.clear()
	_g_offset.clear()
	_text_bounds = Rect2()
	_content_height = 0.0
	if _display_text.is_empty():
		var f := _resolve_font()
		if f != null:
			_content_height = f.get_height(get_effective_font_size())
		return

	var line_count := _para.get_line_count()
	for l in line_count:
		_content_height += _para.get_line_ascent(l) + _para.get_line_descent(l)
	_content_height += line_spacing * maxi(line_count - 1, 0)

	var y := 0.0
	match vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			y = floorf((size.y - _content_height) * 0.5)
		VERTICAL_ALIGNMENT_BOTTOM:
			y = size.y - _content_height

	var has_bounds := false
	for l in line_count:
		var ascent := _para.get_line_ascent(l)
		var line_w := _para.get_line_width(l)
		var x := 0.0
		match horizontal_alignment:
			HORIZONTAL_ALIGNMENT_CENTER:
				x = floorf((size.x - line_w) * 0.5)
			HORIZONTAL_ALIGNMENT_RIGHT:
				x = size.x - line_w
		var baseline := y + ascent
		var glyphs: Array[Dictionary] = ts.shaped_text_get_glyphs(_para.get_line_rid(l))
		var i := 0
		while i < glyphs.size():
			var first: Dictionary = glyphs[i]
			var count: int = maxi(int(first.get("count", 1)), 1)
			var start: int = first["start"]
			var cluster_x := x
			var pen := 0.0
			var visible_flag := false
			_c_glyph_start.append(_g_index.size())
			for j in count:
				if i + j >= glyphs.size():
					break
				var g: Dictionary = glyphs[i + j]
				var flags: int = g["flags"]
				var idx: int = g["index"]
				var rep: int = maxi(int(g.get("repeat", 1)), 1)
				var adv: float = g["advance"]
				var goff: Vector2 = g["offset"]
				var is_blank := (flags & (TextServer.GRAPHEME_IS_SPACE | TextServer.GRAPHEME_IS_TAB | TextServer.GRAPHEME_IS_BREAK_HARD)) != 0 or idx == 0
				for r in rep:
					if not is_blank:
						_g_font.append(g["font_rid"])
						_g_size.append(g["font_size"])
						_g_index.append(idx)
						_g_offset.append(Vector2(pen, 0.0) + goff)
					pen += adv
				if not is_blank:
					visible_flag = true
			x += pen
			_c_glyph_count.append(_g_index.size() - _c_glyph_start[_c_glyph_start.size() - 1])
			if start >= 0 and start < _display_text.length() and _display_text[start].strip_edges().is_empty():
				visible_flag = false
			_c_char.append(start)
			_c_visible.append(1 if visible_flag else 0)
			_c_origin.append(Vector2(cluster_x, baseline))
			_c_advance.append(pen)
			_c_ascent.append(ascent)
			if visible_flag:
				var rect := Rect2(cluster_x, baseline - ascent, pen, ascent)
				_text_bounds = rect if not has_bounds else _text_bounds.merge(rect)
				has_bounds = true
			i += count
		y += ascent + _para.get_line_descent(l) + line_spacing


func _resize_states(n: int) -> void:
	_xf.resize(n)
	_reset_states(n)
	_reset_curve_states(n)

#endregion


#region 모디파이어

func _refresh_modifiers() -> void:
	_anim_node = null
	_curve_node = null
	_outline_node = null
	_glow_node = null
	for child in get_children():
		if _anim_node == null and child.has_method(&"fill_states"):
			_anim_node = child
		elif _curve_node == null and child is CatTextCurve:
			_curve_node = child
		elif _outline_node == null and child is CatTextOutline:
			_outline_node = child
		elif _glow_node == null and child is CatTextGlow:
			_glow_node = child
	queue_redraw()


func _reset_states(n: int) -> void:
	if _own_pos.size() != n:
		_own_pos.resize(n)
		_own_scale.resize(n)
		_own_rot.resize(n)
		_own_alpha.resize(n)
	_own_pos.fill(Vector2.ZERO)
	_own_scale.fill(Vector2.ONE)
	_own_rot.fill(0.0)
	_own_alpha.fill(1.0)
	anim_pos = _own_pos
	anim_scale = _own_scale
	anim_rot = _own_rot
	anim_alpha = _own_alpha
	anim_pivot = Vector2(0.5, 0.0)


func _reset_curve_states(n: int) -> void:
	if _own_curve_y.size() != n:
		_own_curve_y.resize(n)
		_own_curve_angle.resize(n)
	_own_curve_y.fill(0.0)
	_own_curve_angle.fill(0.0)
	curve_offset_y = _own_curve_y
	curve_angle = _own_curve_angle

#endregion


#region 그리기

func _ensure_items() -> void:
	if _face_item.is_valid():
		return
	var rs := RenderingServer
	_face_item = rs.canvas_item_create()
	rs.canvas_item_set_parent(_face_item, get_canvas_item())
	rs.canvas_item_set_draw_index(_face_item, 0)
	_second_item = rs.canvas_item_create()
	rs.canvas_item_set_parent(_second_item, _face_item)
	rs.canvas_item_set_draw_index(_second_item, 0)
	_second_ring_item = rs.canvas_item_create()
	rs.canvas_item_set_parent(_second_ring_item, _face_item)
	rs.canvas_item_set_draw_index(_second_ring_item, 1)
	_inner_item = rs.canvas_item_create()
	rs.canvas_item_set_parent(_inner_item, get_canvas_item())
	rs.canvas_item_set_draw_index(_inner_item, 1)
	# 부모(CatText)의 material을 그대로 쓴다. Second Face 그라데이션만 자체 material을 갖는다.
	for rid in [_face_item, _second_ring_item, _inner_item]:
		rs.canvas_item_set_use_parent_material(rid, true)


func _free_items() -> void:
	for rid in [_second_item, _second_ring_item, _inner_item, _face_item]:
		if rid.is_valid():
			RenderingServer.free_rid(rid)
	_face_item = RID()
	_second_item = RID()
	_second_ring_item = RID()
	_inner_item = RID()
	set_process(false)


## PARENT_NODE를 조상에서 풀어 실제 값을 얻는다. CanvasItem.TextureFilter/Repeat와 RenderingServer 열거값은
## 같은 번호이고, 0(DEFAULT)은 뷰포트 기본값을 뜻한다.
func _effective_texture_setting(prop: StringName) -> int:
	var node: Node = self
	while node is CanvasItem:
		var v := int(node.get(prop))
		if v != 0 or (node as CanvasItem).top_level:
			return v
		node = node.get_parent()
	return 0


func _apply_item_modulate() -> void:
	_applied_self_modulate = self_modulate
	RenderingServer.canvas_item_set_self_modulate(_face_item, self_modulate)
	RenderingServer.canvas_item_set_self_modulate(_inner_item, self_modulate)


func _draw() -> void:
	_ensure_layout()
	var rs := RenderingServer
	var n := _c_char.size()
	var filled := false
	if _anim_node != null and is_instance_valid(_anim_node):
		filled = bool(_anim_node.call(&"fill_states", self))
	if not filled or anim_pos.size() != n:
		_reset_states(n)
	if _curve_node != null and is_instance_valid(_curve_node):
		_curve_node.fill_offsets(self)
	else:
		_reset_curve_states(n)

	var main := get_canvas_item()
	var outline := _outline_node if _outline_node != null and is_instance_valid(_outline_node) else null
	var glow := _glow_node if _glow_node != null and is_instance_valid(_glow_node) else null
	# Second Face 클립 그룹이 필요할 때만 내부 아이템을 쓴다. 나머지는 메인 아이템에 그려
	# self_modulate·material·texture_filter 등 CanvasItem 설정이 그대로 적용되게 한다.
	var separate := n > 0 and outline != null and outline.enable_second_face
	if not separate:
		_free_items()
		if n == 0:
			return
	else:
		_ensure_items()
		rs.canvas_item_clear(_face_item)
		rs.canvas_item_clear(_second_item)
		rs.canvas_item_clear(_second_ring_item)
		rs.canvas_item_clear(_inner_item)
		var filter := _effective_texture_setting(&"texture_filter") as RenderingServer.CanvasItemTextureFilter
		var repeat := _effective_texture_setting(&"texture_repeat") as RenderingServer.CanvasItemTextureRepeat
		for rid in [_face_item, _inner_item]:
			rs.canvas_item_set_default_texture_filter(rid, filter)
			rs.canvas_item_set_default_texture_repeat(rid, repeat)
		_apply_item_modulate()
		set_process(true)
	var face_item := _face_item if separate else main
	var inner_item := _inner_item if separate else main

	for k in n:
		var left := _c_origin[k].x
		var baseline := _c_origin[k].y
		var c := Vector2(lerpf(left, left + _c_advance[k], anim_pivot.x), lerpf(baseline, baseline - _c_ascent[k], anim_pivot.y))
		var cc := Vector2(left + _c_advance[k] * 0.5, baseline)
		_xf[k] = compose_cluster_transform(c, anim_pos[k], anim_scale[k], anim_rot[k], cc, curve_offset_y[k], curve_angle[k])

	var fs := float(get_effective_font_size())

	var face_color := font_color
	if glow != null:
		face_color = Color(glow.glow_color.r, glow.glow_color.g, glow.glow_color.b, font_color.a)

	# 1. Shadow
	if outline != null and outline.enable_shadow:
		var uc := outline.underlay_color
		var shadow_color := Color(uc.r, uc.g, uc.b, uc.a * outline.shadow_alpha)
		var ring := (outline.underlay_dilate + outline.underlay_softness * SOFTNESS_SPREAD) * fs * DILATE_EM
		var off := outline.shadow_offset * fs + _underlay_offset(outline, fs)
		_draw_silhouette_pass(main, off, ring, outline.underlay_softness, shadow_color)
	# 2. Glow halo (softness 1 고정)
	if glow != null:
		var ring := (glow.glow_range + SOFTNESS_SPREAD) * fs * GLOW_EM
		_draw_silhouette_pass(main, Vector2.ZERO, ring, 1.0, glow.glow_color)
	# 3. Underlay
	if outline != null:
		var ring := (outline.underlay_dilate + outline.underlay_softness * SOFTNESS_SPREAD) * fs * DILATE_EM
		_draw_silhouette_pass(main, _underlay_offset(outline, fs), ring, outline.underlay_softness, outline.underlay_color)

	# 4. Face
	var face_dilate := 0.0
	if outline != null:
		face_dilate = outline.face_dilate
	if glow != null:
		face_dilate = maxf(face_dilate, glow.face_dilate)
	var face_ring := maxf(face_dilate, 0.0) * fs * DILATE_EM
	if face_ring > 0.0:
		_draw_ring_pass(face_item, Vector2.ZERO, face_ring, face_color)
	_draw_fill_pass(face_item, Vector2.ZERO, face_color)

	# 4b. Second Face: F의 알파로 S·S2를 잘라 안쪽 면만 남긴다.
	if separate:
		rs.canvas_item_set_canvas_group_mode(_face_item, RenderingServer.CANVAS_GROUP_MODE_CLIP_AND_DRAW)
		var off := Vector2(outline.second_face_offset_x, outline.second_face_offset_y) * fs
		if outline.use_second_face_gradient:
			_update_gradient_material(outline)
			rs.canvas_item_set_use_parent_material(_second_item, false)
			rs.canvas_item_set_material(_second_item, _gradient_material.get_rid())
			_draw_fill_pass(_second_item, off, Color.WHITE)
		else:
			rs.canvas_item_set_material(_second_item, RID())
			rs.canvas_item_set_use_parent_material(_second_item, true)
			_draw_fill_pass(_second_item, off, outline.second_face_color)
		var inset := -outline.second_face_dilate * fs * DILATE_EM
		if inset > 0.0:
			_draw_ring_pass(_second_ring_item, off, inset, face_color)

	# 5. Inner Glow
	if glow != null and glow.inner_glow_alpha > 0.0:
		var ic := Color(glow.glow_color.r, glow.glow_color.g, glow.glow_color.b, glow.inner_glow_alpha)
		_draw_silhouette_pass(inner_item, Vector2.ZERO, INNER_GLOW_RING_EM * fs, 0.5, ic)
	rs.canvas_item_add_set_transform(main, Transform2D.IDENTITY)


func _underlay_offset(outline: CatTextOutline, fs: float) -> Vector2:
	return Vector2(outline.underlay_offset_x, outline.underlay_offset_y) * fs * UNDERLAY_OFFSET_EM


## 실루엣(링 + fill)을 소프트니스 다중 패스(최대 3단계)로 그린다. 큰 링부터.
## 바깥 띠부터 누적 알파가 a/steps, 2a/steps, …, a가 되도록 단계 알파를 정한다(모든 단계가 겹치는 안쪽 = 정확히 a).
## 같은 알파를 균등 분배(1 - (1-a)^(1/steps))하면 a = 1일 때 모든 단계가 불투명해져 번짐이 사라지므로 쓰지 않는다.
## 링 두께를 1px로 양자화한 결과 같은 크기가 된 단계는 한 번에 합쳐 그린다(외곽선 글리프 캐시 수 절감).
func _draw_silhouette_pass(item: RID, offset: Vector2, ring_px: float, softness: float, color: Color) -> void:
	var steps := 1 + roundi(clampf(softness, 0.0, 1.0) * 2.0)
	var a := clampf(color.a, 0.0, 1.0)
	var prev_cum := 0.0
	var drawn := 0
	var s := steps
	while s > 0:
		var px := roundi(ring_px * float(s) / float(steps))
		var merged := 1
		while s - merged > 0 and roundi(ring_px * float(s - merged) / float(steps)) == px:
			merged += 1
		drawn += merged
		var cum := a * float(drawn) / float(steps)
		var step_color := Color(color.r, color.g, color.b, 1.0 - (1.0 - cum) / (1.0 - prev_cum))
		prev_cum = cum
		if px > 0:
			_draw_ring_pass(item, offset, px, step_color)
		_draw_fill_pass(item, offset, step_color)
		s -= merged


func _draw_fill_pass(item: RID, offset: Vector2, color: Color) -> void:
	var ts := TextServerManager.get_primary_interface()
	var rs := RenderingServer
	for k in _c_char.size():
		if _c_visible[k] == 0 or anim_alpha[k] <= 0.0:
			continue
		var col := Color(color.r, color.g, color.b, color.a * anim_alpha[k])
		rs.canvas_item_add_set_transform(item, _xf[k])
		var base := _c_origin[k] + offset
		var g0 := _c_glyph_start[k]
		for j in _c_glyph_count[k]:
			var gi := g0 + j
			var fr: RID = _g_font[gi]
			if fr.is_valid():
				ts.font_draw_glyph(fr, item, _g_size[gi], base + _g_offset[gi], _g_index[gi], col)


## 링 두께는 1px 단위(outline_size 4의 배수)로 양자화해 TextServer 외곽선 캐시 종류를 줄인다.
func _draw_ring_pass(item: RID, offset: Vector2, ring_px: float, color: Color) -> void:
	var outline_size := roundi(ring_px) * int(OUTLINE_SIZE_PER_PX)
	if outline_size <= 0:
		return
	var ts := TextServerManager.get_primary_interface()
	var rs := RenderingServer
	for k in _c_char.size():
		if _c_visible[k] == 0 or anim_alpha[k] <= 0.0:
			continue
		var col := Color(color.r, color.g, color.b, color.a * anim_alpha[k])
		rs.canvas_item_add_set_transform(item, _xf[k])
		var base := _c_origin[k] + offset
		var g0 := _c_glyph_start[k]
		for j in _c_glyph_count[k]:
			var gi := g0 + j
			var fr: RID = _g_font[gi]
			if fr.is_valid():
				ts.font_draw_glyph_outline(fr, item, _g_size[gi], outline_size, base + _g_offset[gi], _g_index[gi], col)


func _update_gradient_material(outline: CatTextOutline) -> void:
	if _gradient_shader == null:
		_gradient_shader = Shader.new()
		_gradient_shader.code = _GRADIENT_SHADER_CODE
	if _gradient_material == null:
		_gradient_material = ShaderMaterial.new()
		_gradient_material.shader = _gradient_shader
	var b := _text_bounds
	_gradient_material.set_shader_parameter(&"block_rect", Vector4(b.position.x, b.position.y, b.size.x, b.size.y))
	_gradient_material.set_shader_parameter(&"color_top_left", outline.second_face_gradient_top_left)
	_gradient_material.set_shader_parameter(&"color_top_right", outline.second_face_gradient_top_right)
	_gradient_material.set_shader_parameter(&"color_bottom_left", outline.second_face_gradient_bottom_left)
	_gradient_material.set_shader_parameter(&"color_bottom_right", outline.second_face_gradient_bottom_right)

#endregion
