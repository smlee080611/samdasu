extends Area3D
## 다음 층 계단. 조건(구출 수, 차광막)을 채우고 밟으면 클리어.

func _ready() -> void:
	body_entered.connect(_on_body)

func _on_body(b: Node) -> void:
	if not b.is_in_group("player"):
		return
	if GameState.can_leave():
		GameState.won = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		GameState.state_changed.emit()
	else:
		GameState.say("계단: 구출 %d/%d, 차광막 %d/%d 필요" % [GameState.rescued, GameState.need_rescue, GameState.curtains_open, GameState.curtains_total])
