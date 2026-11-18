extends StaticBody3D
## 층별 차단기 (발전기실 벽). 발전기가 돌기 시작하면 E로 올릴 수 있고, 올린 층에 불이 들어온다.
## 한꺼번에는 못 올린다(발전기 용량): 하나 올리면 generator.settle_seconds 동안 기다려야 다음 것을 올릴 수 있다.
## 어느 층부터 켤지는 플레이어의 선택. 켜진 층의 사람들은 빛을 받아 깨어나고, 한동안 광인으로 날뛴 뒤 정신이 돌아온다.

@export var floor_no := 1     ## 이 차단기가 맡은 층 (1, 2, 지하 1층 = -1)

var on := false
var _led: StandardMaterial3D

func _ready() -> void:
	add_to_group("breaker")
	var lb := get_node_or_null("Label") as Label3D
	if lb:
		lb.text = GameState.floor_label(floor_no)
	_led = StandardMaterial3D.new()
	_led.emission_enabled = true
	var led := get_node_or_null("Led") as MeshInstance3D
	if led:
		led.material_override = _led
	_show()

func _generator() -> Node:
	for g in get_tree().get_nodes_in_group("generator"):
		return g
	return null

func interact(_by: Node) -> void:
	if on:
		return
	var g := _generator()
	if g == null or not g.running:
		Sfx.play_at("click", global_position + Vector3.UP * 1.3, -8.0)
		GameState.say("올려도 반응이 없다. 발전기가 돌아야 한다.")
		return
	if g.settle_t > 0.0:
		GameState.say("발전기 소리가 아직 불안하다. 조금 기다려야 한다.")
		return
	on = true
	g.settle_t = g.settle_seconds
	Sfx.play_at("thud", global_position + Vector3.UP * 1.3, -2.0, 0.0)
	_show()
	get_tree().get_first_node_in_group("main").power_floor(floor_no)

func get_hint() -> String:
	if on:
		return ""
	var g := _generator()
	if g and g.running and g.settle_t > 0.0:
		return "%s 차단기 · 기다리는 중" % GameState.floor_label(floor_no)
	return "E · %s 차단기 올리기" % GameState.floor_label(floor_no)

func _show() -> void:
	var lever := get_node_or_null("Lever") as Node3D
	if lever:
		lever.rotation.x = deg_to_rad(-140.0) if on else 0.0   # 손잡이: 내려감(꺼짐) / 올라감(켜짐)
	_led.albedo_color = Color(0.2, 1.0, 0.35) if on else Color(0.7, 0.1, 0.05)
	_led.emission = _led.albedo_color
	_led.emission_energy_multiplier = 2.0 if on else 0.6
