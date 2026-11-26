@tool
extends Control
## 스타일 갤러리 데모. 한글 표시용 데모 전용 폰트를 모든 CatText·Label에 적용한다(애드온 코드는 폰트를 지정하지 않음).

@export var demo_font: Font:
	set(value):
		demo_font = value
		if is_inside_tree():
			_apply_font(self)


func _ready() -> void:
	_apply_font(self)


func _apply_font(node: Node) -> void:
	if demo_font == null:
		return
	for child in node.get_children():
		if child is CatText:
			(child as CatText).font = demo_font
		elif child is Label:
			(child as Label).add_theme_font_override(&"font", demo_font)
		_apply_font(child)
