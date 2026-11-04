extends Area3D
## 굳은 앞사람이 떨어뜨린 경광봉. 밟으면 다시 쥔다.

func _ready() -> void:
	body_entered.connect(_on_body)

func _on_body(b: Node) -> void:
	if b.is_in_group("player") and not b.has_baton:
		b.set_baton(true)
		Sfx.play("thud", -10.0)
		GameState.say("경광봉을 다시 쥐었다.")
		queue_free()
