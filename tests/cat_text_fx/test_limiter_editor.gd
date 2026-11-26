extends SceneTree
## 에디터(@tool)에서 CatLayoutLimiter가 부모 속성을 바꾸지 않는지 확인한다(씬 저장 오염 방지).
## 실행: $GODOT --headless --editor --path . -s tests/cat_text_fx/test_limiter_editor.gd

const Limiter := preload("res://addons/cat_text_fx/cat_layout_limiter.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not Engine.is_editor_hint():
		printerr("FAIL: --editor로 실행해야 합니다")
		quit(1)
		return
	var label := Label.new()
	label.text = "This is a very long line of text that should exceed the three hundred pixel limit for sure, really."
	var limiter: Node = Limiter.new()
	limiter.max_width = 100.0
	limiter.max_height = 10.0
	label.add_child(limiter)
	root.add_child(label)
	await process_frame
	limiter.refresh()
	await process_frame
	var ok := label.autowrap_mode == TextServer.AUTOWRAP_OFF and label.custom_minimum_size == Vector2.ZERO and not label.clip_text
	if not ok:
		printerr("FAIL: 에디터에서 부모 속성 변경 (autowrap=%d, min=%s, clip=%s)" % [label.autowrap_mode, label.custom_minimum_size, label.clip_text])
	else:
		print("test_limiter_editor: PASS")
	label.free()
	quit(0 if ok else 1)
