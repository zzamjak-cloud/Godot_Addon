@tool
extends EditorPlugin
## 에디터 전용: 도구 메뉴에서 바다 세트·강 세트를 편집 중인 씬에 추가한다(Undo 가능).
## 런타임 노드는 class_name 으로 등록되므로 플러그인을 끄더라도 동작한다.

const MENU_OCEAN_SET := "CAT Ocean Flow: 바다 세트 만들기"
const MENU_RIVER_SET := "CAT Ocean Flow: 강 세트 만들기"


func _enter_tree() -> void:
	add_tool_menu_item(MENU_OCEAN_SET, _add_set.bind(true))
	add_tool_menu_item(MENU_RIVER_SET, _add_set.bind(false))


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_OCEAN_SET)
	remove_tool_menu_item(MENU_RIVER_SET)


func _add_set(ocean: bool) -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		push_warning("[CatOceanFlow] 편집 중인 씬이 없습니다. 씬을 먼저 여세요.")
		return
	var set_root: Node3D = CatOceanFlowSurface.create_ocean_set() if ocean else CatOceanFlowRiver.create_river_set()
	var undo := get_undo_redo()
	# 플러그인 객체에 등록한 do 메서드가 있어도 씬 히스토리에 남도록 문맥을 씬 루트로 준다
	undo.create_action("바다 세트 만들기" if ocean else "강 세트 만들기", UndoRedo.MERGE_DISABLE, scene_root)
	undo.add_do_method(scene_root, "add_child", set_root, true)
	undo.add_do_method(self, "_set_owner_recursive", set_root, scene_root)
	undo.add_do_reference(set_root)
	undo.add_undo_method(scene_root, "remove_child", set_root)
	undo.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(set_root)


func _set_owner_recursive(node: Node, scene_owner: Node) -> void:
	node.owner = scene_owner
	for child in node.get_children():
		_set_owner_recursive(child, scene_owner)
