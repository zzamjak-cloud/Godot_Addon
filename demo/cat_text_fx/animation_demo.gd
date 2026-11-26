extends Control
## CatTextAnimation 번들 프리셋 데모. 버튼으로 재시작과 Impact를 확인한다.

@onready var _anims: Array[CatTextAnimation] = [
	$TitleText/Animation, $SubText/Animation, $WaveText/Animation,
]


func _on_restart_pressed() -> void:
	for a in _anims:
		a.restart()


func _on_impact_pressed() -> void:
	for a in _anims:
		a.trigger_impact()
