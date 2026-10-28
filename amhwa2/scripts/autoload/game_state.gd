extends Node
## 게임 진행 상태. 어느 스크립트에서나 GameState.rescued 처럼 접근한다.

signal message(text: String)
signal state_changed

const LAYER_WALL := 1
const LAYER_PERSON := 2
const LAYER_INTERACT := 4
const LAYER_PLAYER := 8

var need_rescue := 3
var rescued := 0
var curtains_total := 0
var curtains_open := 0
var game_over := false
var won := false

func reset() -> void:
	rescued = 0
	curtains_total = 0
	curtains_open = 0
	game_over = false
	won = false

func say(text: String) -> void:
	print(text)
	message.emit(text)

func add_rescued(person_name: String) -> void:
	rescued += 1
	say("%s이(가) 입구에 도착했다. 구출 %d명." % [person_name, rescued])
	state_changed.emit()

func curtain_opened() -> void:
	curtains_open += 1
	say("차광막을 걷었다. 달빛이 병실을 비춘다.")
	state_changed.emit()

func can_leave() -> bool:
	return rescued >= need_rescue and curtains_open >= curtains_total
