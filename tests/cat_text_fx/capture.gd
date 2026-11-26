extends SceneTree
## 창 모드로 씬을 띄워 몇 프레임 뒤 화면을 PNG로 저장하고 종료한다.
## 실행: $GODOT --path . -s tests/cat_text_fx/capture.gd -- <scene_path> <out_png> [width] [height]

const FRAMES := 3


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("사용법: -s tests/cat_text_fx/capture.gd -- <scene_path> <out_png> [width] [height]")
		quit(1)
		return
	var w := int(args[2]) if args.size() > 2 else 1280
	var h := int(args[3]) if args.size() > 3 else 720
	var packed := load(args[0]) as PackedScene
	if packed == null:
		printerr("씬을 불러올 수 없습니다: ", args[0])
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(w, h))
	root.size = Vector2i(w, h)
	root.add_child(packed.instantiate())
	_capture.call_deferred(args[1])


func _capture(out_path: String) -> void:
	for i in FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(out_path)
	if err != OK:
		printerr("PNG 저장 실패(%d): %s" % [err, out_path])
		quit(1)
		return
	print("captured ", img.get_size(), " -> ", out_path)
	quit(0)
