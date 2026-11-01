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
		# 주인공이 알 만한 것만 생각으로 말한다
		if GameState.rescued < GameState.need_rescue:
			GameState.say("혼자 올라갈 순 없다. 아직 이 층에 사람들이 있다.")
		else:
			GameState.say("현황판에 적힌 병실들... 아직 다 둘러보지 못했다.")
