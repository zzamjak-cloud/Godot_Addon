extends Control
## 정사각(1080x1080) 트레일러의 배경 틀. 가운데(y 236~844)에 1080 폭으로 줄인 본편이 얹힌다.
## tools/record_trailer.sh가 한 프레임만 PNG로 찍어 ffmpeg overlay 바탕으로 쓴다.

const SIZE := Vector2(1080, 1080)
const VIDEO_TOP := 236.0
const VIDEO_H := 608.0


func _ready() -> void:
	position = Vector2.ZERO
	size = SIZE
	var base := SystemFont.new()
	base.font_names = PackedStringArray(["Apple SD Gothic Neo", "Noto Sans CJK KR", "Malgun Gothic"])
	# SystemFont의 font_weight가 .ttc에서 굵은 face를 고르지 못해 embolden으로 굵힌다.
	var sans := FontVariation.new()
	sans.base_font = base
	sans.variation_embolden = 0.9
	var bg := ColorRect.new()
	bg.color = Color("161a26")
	bg.size = SIZE
	add_child(bg)
	var title := _text(sans, "CAT Text FX", 84, Rect2(0, 40, SIZE.x, 160), Color("f4f6fb"))
	var ol := CatTextOutline.new()
	ol.set_outline(Color("0d1018"), 0.3)
	title.add_child(ol)
	var gl := CatTextGlow.new()
	gl.set_glow(Color(Color("ffb13b"), 0.5), 0.32)
	title.add_child(gl)
	var bottom := VIDEO_TOP + VIDEO_H
	_text(sans, "zzamjak-cloud.github.io/Godot_Addon", 44, Rect2(0, bottom + 40, SIZE.x, 80), Color("ffb13b"))
	_text(sans, "Godot 4.7+  ·  GDScript  ·  MIT", 32, Rect2(0, bottom + 120, SIZE.x, 60), Color("8fd3ff"))


func _text(f: Font, s: String, font_size: int, rect: Rect2, color: Color) -> CatText:
	var ct := CatText.new()
	ct.font = f
	ct.font_size = font_size
	ct.font_color = color
	ct.text = s
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ct.position = rect.position
	ct.size = rect.size
	add_child(ct)
	return ct
