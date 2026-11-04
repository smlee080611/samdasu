extends Node
## 게임 진행 상태. 어느 스크립트에서나 GameState.rescued 처럼 접근한다.

signal message(text: String)
signal state_changed
signal note_opened(title: String, body: String)
signal status_poke   # 상태(구출 수, 랜턴, 배터리)를 잠깐 보여줄 때
signal relay(text: String)   # 교대: 굳은 나 대신 기다리던 사람이 이어받음

const LAYER_WALL := 1
const LAYER_PERSON := 2
const LAYER_INTERACT := 4
const LAYER_PLAYER := 8

var need_rescue := 3
var floor_no := 1          # 플레이어가 있는 층 (main.gd가 바꿈)
var rescued := 0
var curtains_total := 0
var curtains_open := 0
var game_over := false
var won := false
## 하룻밤: Night 노드(night.gd)가 매 프레임 채운다. 남은 시간은 화면에 숫자로 띄우지 않고 벽시계와 창밖 하늘로만 보인다.
var night_k := 0.0          # 0 = 밤이 막 시작, 1 = 해가 뜸
var clock_minutes := 130.0  # 벽시계가 가리키는 시각(자정부터 분). 130 = 새벽 2시 10분
var night_over := false     # 해가 떠서 결과 화면을 보여 주는 중
var dawn_cured := 0         # 해가 뜰 때 햇빛이 닿아 저절로 깨어난 사람
var dawn_left := 0          # 해가 떠도 어둠 속에 남은 사람(석상·광인)
var ui_blocking := false   # 시작 연출, 쪽지 읽는 중: 플레이어와 광인이 멈춘다
var intro_seen := false    # 시작 연출은 처음 한 번만 (F9로 다시 해도 안 나옴). reset()에서 지우지 않는다

func reset() -> void:
	rescued = 0
	floor_no = 1
	curtains_total = 0
	curtains_open = 0
	game_over = false
	won = false
	ui_blocking = false
	night_k = 0.0
	clock_minutes = 130.0
	night_over = false
	dawn_cured = 0
	dawn_left = 0

func open_note(title: String, body: String) -> void:
	ui_blocking = true
	note_opened.emit(title, body)

func is_frozen() -> bool:
	return game_over or won or ui_blocking or night_over

func say(text: String) -> void:
	print(text)
	message.emit(text)

## 다른 사람이 하는 말. 플레이어 근처(약 6칸)에서만 들린다.
func speak(from: Vector3, line: String, hear_range := 12.0) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p and p.global_position.distance_to(from) < hear_range:
		say("“%s”" % line)

func add_rescued(person_name: String) -> void:
	rescued += 1   # 화면에 알리지 않는다. 엘리베이터 홀에 모여 있는 사람으로 보인다
	state_changed.emit()

func curtain_opened() -> void:
	curtains_open += 1
	state_changed.emit()

func relay_happened() -> void:
	relay.emit("몸이 완전히 굳었다.\n\n\n...밖에서 기다리던 사람이\n떨어진 헤드램프를 집어 들었다.\n\n앞사람의 물건은 굳은 자리에 남아 있다.")

func can_leave() -> bool:
	return rescued >= need_rescue and curtains_open >= curtains_total
