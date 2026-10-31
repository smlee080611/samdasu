extends Node
## 게임 진행 상태. 어느 스크립트에서나 GameState.rescued 처럼 접근한다.

signal message(text: String)
signal state_changed
signal note_opened(title: String, body: String)
signal status_poke   # 상태(구출 수, 랜턴, 배터리)를 잠깐 보여줄 때

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
var ui_blocking := false   # 시작 연출, 쪽지 읽는 중: 플레이어와 광인이 멈춘다
var intro_seen := false    # 시작 연출은 처음 한 번만 (R로 다시 해도 안 나옴). reset()에서 지우지 않는다

func reset() -> void:
	rescued = 0
	curtains_total = 0
	curtains_open = 0
	game_over = false
	won = false
	ui_blocking = false

func open_note(title: String, body: String) -> void:
	ui_blocking = true
	note_opened.emit(title, body)

func is_frozen() -> bool:
	return game_over or won or ui_blocking

func say(text: String) -> void:
	print(text)
	message.emit(text)

## 다른 사람이 하는 말. 플레이어 근처(약 6칸)에서만 들린다.
func speak(from: Vector3, line: String) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p and p.global_position.distance_to(from) < 12.0:
		say("“%s”" % line)

func add_rescued(person_name: String) -> void:
	rescued += 1   # 화면에 알리지 않는다. 엘리베이터 홀에 모여 있는 사람으로 보인다
	state_changed.emit()

func curtain_opened() -> void:
	curtains_open += 1
	state_changed.emit()

func can_leave() -> bool:
	return rescued >= need_rescue and curtains_open >= curtains_total
