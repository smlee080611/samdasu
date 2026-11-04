extends Area3D
## 케미라이트 묶음. 밟으면 케미라이트가 늘어난다. (교대할 때 앞사람이 굳은 자리에 남기도 한다)

@export var amount := 3

func _ready() -> void:
	body_entered.connect(_on_body)

func _on_body(b: Node) -> void:
	if b.is_in_group("player"):
		b.chemlights += amount
		b._update_hand_stick()
		Sfx.play("snap", -10.0)
		GameState.say("케미라이트 %d개." % amount)
		queue_free()
