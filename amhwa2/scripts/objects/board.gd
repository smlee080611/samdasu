@tool
extends Node3D
## 간호사실 현황판(화이트보드). 인스펙터의 Text만 바꾸면 된다.
## 플레이어는 화면 숫자 대신 이 판을 읽고 무엇을 해야 하는지 안다.

@export_multiline var text := "":
	set(v):
		text = v
		if is_inside_tree():
			$Label.text = v

func _ready() -> void:
	$Label.text = text
