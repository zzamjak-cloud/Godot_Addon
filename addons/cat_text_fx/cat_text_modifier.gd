@tool
class_name CatTextModifier
extends Node
## CatText 자식으로 붙는 효과 노드의 공통 베이스. 부모 CatText에 다시 그리기를 요청한다.


func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED or what == NOTIFICATION_UNPARENTED:
		update_configuration_warnings()


## 부모가 CatText면 반환, 아니면 null.
func get_text() -> CatText:
	return get_parent() as CatText


func _get_configuration_warnings() -> PackedStringArray:
	if get_text() == null:
		return PackedStringArray(["부모 노드가 CatText여야 합니다."])
	return PackedStringArray()


func _notify_changed() -> void:
	var text := get_text()
	if text != null:
		text.queue_redraw()
