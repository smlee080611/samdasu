@tool
extends Node3D
## 병실 번호·안내 표지판. 인스펙터에서 Text와 Width만 바꾸면 된다.

@export var text := "101":
	set(v):
		text = v
		_apply()
@export var width := 0.7:
	set(v):
		width = v
		_apply()

func _ready() -> void:
	_apply()

func _apply() -> void:
	if not is_inside_tree():
		return
	$Label.text = text
	var plate: MeshInstance3D = $Plate
	plate.scale.x = width / 0.7
	var lines := text.count("\n") + 1
	plate.scale.y = 1.0 + (lines - 1) * 0.85
