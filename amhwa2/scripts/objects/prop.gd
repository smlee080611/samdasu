extends StaticBody3D
## 병원 소품(침대, 휠체어, 링거대, 칸막이, 카트, 사물함, 책상, 선반) 공통.
## blocks_path를 켜면 그 칸은 광인·구출된 사람이 지나가지 못한다(길찾기에서 막힘).
## 소품은 벽 레이어라 빛을 가리고 그림자를 만든다.
## loot가 비어 있지 않으면 E를 길게 눌러 뒤질 수 있다 (뒤지는 동안 움직일 수 없음):
##   "battery" 헤드램프 배터리, "chem" 케미라이트 2개, "empty" 아무것도 없음

@export var blocks_path := false
@export var loot := ""   ## "", "empty", "battery", "chem"
@export var search_seconds := 1.4
var searched := false
var _rummage_played := false

func _ready() -> void:
	if blocks_path:
		add_to_group("blocker")
	MeshMerge.merge(self)

func hold(seconds: float) -> bool:
	if loot == "" or searched:
		return false
	if not _rummage_played:
		_rummage_played = true
		Sfx.play_at("rummage", global_position + Vector3.UP * 0.6, -4.0)
	if seconds < search_seconds:
		return false
	searched = true
	var p = get_tree().get_first_node_in_group("player")
	match loot:
		"battery":
			var level := get_tree().get_first_node_in_group("level") as Level
			p.headlamp.recharge(level.battery_amount if level else 50.0)
			Sfx.play("click")
			GameState.say("예비 배터리. 램프가 다시 밝아진다.")
		"chem":
			p.chemlights += 2
			p._update_hand_stick()
			Sfx.play("snap", -10.0)
			GameState.say("케미라이트 두 개.")
		_:
			GameState.say("아무것도 없다.")
	return true

func release(_seconds: float) -> void:
	_rummage_played = false

func get_hint() -> String:
	if loot == "" or searched:
		return ""
	return "E 길게 · 뒤지기"
