@tool
class_name CatTextAnimationPreset
extends Resource
## CatTextAnimation 설정 묶음. play_on_ready와 preset 자신은 저장하지 않는다.
## 좌표는 Godot 기준(y 아래 +, 회전 양수 = 시계 방향)이다.

enum LoopType { RESTART = 0, YOYO = 1 }

# apply_to/copy_from이 1:1로 옮기는 속성 이름. CatTextAnimation도 같은 이름을 쓴다.
const FIELDS: PackedStringArray = [
	"character_delay", "initial_delay", "pivot",
	"enable_appear", "appear_relative", "appear_position", "appear_scale", "appear_rotation",
	"appear_alpha", "appear_duration", "appear_ease", "appear_curve", "appear_to_loop_blend",
	"appear_use_position_curve", "appear_position_curve_offset",
	"enable_loop", "loop_relative", "loop_position", "loop_scale", "loop_rotation",
	"loop_duration", "loop_ease", "loop_curve", "loop_count", "loop_type", "loop_to_disappear_blend",
	"loop_use_position_curve", "loop_position_curve_offset",
	"enable_disappear", "disappear_relative", "disappear_position", "disappear_scale",
	"disappear_rotation", "disappear_alpha", "disappear_duration", "disappear_ease", "disappear_curve",
	"disappear_use_position_curve", "disappear_position_curve_offset",
	"enable_impact", "impact_scale", "impact_position", "impact_rotation", "impact_duration",
	"impact_ease", "impact_curve", "impact_character_delay",
]

@export_multiline var description: String = ""

@export_group("Timing")
@export_range(0.0, 0.5, 0.001) var character_delay: float = 0.05
@export_range(0.0, 5.0, 0.01) var initial_delay: float = 0.0
@export var pivot: Vector2 = Vector2(0.5, 0.0)

@export_group("Appear")
@export var enable_appear: bool = true
@export var appear_relative: bool = true
@export var appear_position: Vector2 = Vector2(0, -50)
@export var appear_scale: Vector2 = Vector2(0.5, 0.5)
@export var appear_rotation: float = 0.0
@export_range(0.0, 1.0, 0.01) var appear_alpha: float = 0.0
@export var appear_duration: float = 0.5
@export var appear_ease: CatEase.Type = CatEase.Type.OUT_BACK
@export var appear_curve: Curve
@export_range(0.0, 0.5, 0.01) var appear_to_loop_blend: float = 0.0
@export var appear_use_position_curve: bool = false
@export var appear_position_curve_offset: Vector2 = Vector2.ZERO

@export_group("Loop")
@export var enable_loop: bool = false
@export var loop_relative: bool = true
@export var loop_position: Vector2 = Vector2(0, -20)
@export var loop_scale: Vector2 = Vector2.ONE
@export var loop_rotation: float = 0.0
@export var loop_duration: float = 1.0
@export var loop_ease: CatEase.Type = CatEase.Type.IN_OUT_SINE
@export var loop_curve: Curve
## 0 = 비활성, N = N회, -1 = 무한(무한이면 Disappear는 무시)
@export var loop_count: int = 1
@export var loop_type: LoopType = LoopType.YOYO
@export_range(0.0, 0.5, 0.01) var loop_to_disappear_blend: float = 0.0
@export var loop_use_position_curve: bool = false
@export var loop_position_curve_offset: Vector2 = Vector2.ZERO

@export_group("Disappear")
@export var enable_disappear: bool = false
@export var disappear_relative: bool = true
@export var disappear_position: Vector2 = Vector2(0, 50)
@export var disappear_scale: Vector2 = Vector2(0.5, 0.5)
@export var disappear_rotation: float = 0.0
@export_range(0.0, 1.0, 0.01) var disappear_alpha: float = 0.0
@export var disappear_duration: float = 0.5
@export var disappear_ease: CatEase.Type = CatEase.Type.IN_BACK
@export var disappear_curve: Curve
@export var disappear_use_position_curve: bool = false
@export var disappear_position_curve_offset: Vector2 = Vector2.ZERO

@export_group("Impact")
@export var enable_impact: bool = false
@export var impact_scale: Vector2 = Vector2(1.2, 1.2)
@export var impact_position: Vector2 = Vector2.ZERO
@export var impact_rotation: float = 0.0
@export_range(0.05, 1.0, 0.01) var impact_duration: float = 0.15
@export var impact_ease: CatEase.Type = CatEase.Type.OUT_QUAD
@export var impact_curve: Curve
@export_range(0.0, 0.1, 0.001) var impact_character_delay: float = 0.02


## 프리셋 값을 node(CatTextAnimation 등 같은 속성 이름을 가진 객체)에 복사한다.
func apply_to(node: Object) -> void:
	for f in FIELDS:
		node.set(f, get(f))


## node의 현재 값을 이 프리셋으로 복사한다.
func copy_from(node: Object) -> void:
	for f in FIELDS:
		set(f, node.get(f))


static func create_bounce_appear() -> CatTextAnimationPreset:
	var p := CatTextAnimationPreset.new()
	p.description = "바운스 등장"
	p.appear_position = Vector2(0, -100)
	p.appear_scale = Vector2(0.5, 0.5)
	p.appear_duration = 0.6
	p.appear_ease = CatEase.Type.OUT_BOUNCE
	p.character_delay = 0.05
	return p


static func create_wave_loop() -> CatTextAnimationPreset:
	var p := CatTextAnimationPreset.new()
	p.description = "물결 루프"
	p.enable_appear = false
	p.enable_loop = true
	p.loop_position = Vector2(0, -30)
	p.loop_duration = 0.8
	p.loop_ease = CatEase.Type.IN_OUT_SINE
	p.loop_count = -1
	p.loop_type = LoopType.YOYO
	return p


static func create_scale_disappear() -> CatTextAnimationPreset:
	var p := CatTextAnimationPreset.new()
	p.description = "축소 퇴장"
	p.enable_appear = false
	p.enable_loop = false
	p.enable_disappear = true
	p.disappear_scale = Vector2.ZERO
	p.disappear_alpha = 0.0
	p.disappear_duration = 0.5
	p.disappear_ease = CatEase.Type.IN_BACK
	return p


static func create_rotate_appear() -> CatTextAnimationPreset:
	var p := CatTextAnimationPreset.new()
	p.description = "회전 등장"
	p.appear_rotation = -180.0
	p.appear_scale = Vector2(0.5, 0.5)
	p.appear_duration = 0.5
	p.appear_ease = CatEase.Type.OUT_BACK
	return p


static func create_fade_in_out() -> CatTextAnimationPreset:
	var p := CatTextAnimationPreset.new()
	p.description = "페이드 인/아웃"
	p.appear_position = Vector2.ZERO
	p.appear_scale = Vector2.ONE
	p.appear_alpha = 0.0
	p.appear_duration = 0.3
	p.appear_ease = CatEase.Type.OUT_QUAD
	p.enable_disappear = true
	p.disappear_position = Vector2.ZERO
	p.disappear_scale = Vector2.ONE
	p.disappear_alpha = 0.0
	p.disappear_duration = 0.3
	p.disappear_ease = CatEase.Type.IN_QUAD
	return p
