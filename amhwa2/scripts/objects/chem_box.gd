extends Area3D
## 케미라이트 상자. 밟으면 케미라이트가 늘어난다.

@export var amount := 3

func _ready() -> void:
	body_entered.connect(_on_body)

func _on_body(b: Node) -> void:
	if b.is_in_group("player"):
		b.chemlights += amount
		Sfx.play("snap", -10.0)
		GameState.say("케미라이트 한 묶음.")
		queue_free()
