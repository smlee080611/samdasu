extends Area3D
## 예비 배터리. 밟으면 헤드램프 배터리가 찬다.

@export var amount := 50.0

func _ready() -> void:
	body_entered.connect(_on_body)

func _on_body(b: Node) -> void:
	if b.is_in_group("player"):
		b.headlamp.recharge(amount)
		GameState.say("예비 배터리를 끼웠다.")
		queue_free()
