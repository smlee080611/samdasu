extends StaticBody3D
## 바닥이나 침대 위의 기록물. 바라보고 E를 누르면 화면에 펼쳐진다.

@export var title := "쪽지"
@export_multiline var body := ""

func _ready() -> void:
	add_to_group("note")

func interact(_by: Node) -> void:
	GameState.open_note(title, body)

func get_hint() -> String:
	return "E · 읽기"
