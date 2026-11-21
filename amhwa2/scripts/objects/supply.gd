extends StaticBody3D
## 보급 선반 (1층 마당, 현관 왼쪽 벽 앞. 게임은 여기 마당에서 시작한다). 랜턴·케미라이트·붕대·경광봉이 여기 놓여 있다.
## 처음부터 주어지는 물건은 헤드램프뿐이고, 나머지는 여기서 E로 챙긴다. 한 번에 들 수 있는 만큼만 가져가고
## (player.gd max_lanterns / max_chemlights / max_bandages) 나머지는 선반에 남는다.
## 교대한 다음 사람은 빈손으로 들어와 여기 남은 것을 챙긴다. 그래서 앞사람이 얼마나 썼는지가 다음 사람의 난이도가 된다.
## 쓰다 남은 것을 도로 올려놓는 기능은 없다 (필요해지면 추가).

@export var lanterns := 3
@export var chemlights := 10
@export var bandages := 2
@export var baton := true

var _items: Node3D

func _ready() -> void:
	_items = Node3D.new()
	add_child(_items)
	_redraw()

func total() -> int:
	return lanterns + chemlights + bandages + (1 if baton else 0)

func interact(by: Node) -> void:
	var got: Array[String] = []
	var n: int = mini(lanterns, by.max_lanterns - by.lanterns_held)
	if n > 0:
		lanterns -= n
		by.lanterns_held += n
		got.append("랜턴 %d" % n)
	n = mini(chemlights, by.max_chemlights - by.chemlights)
	if n > 0:
		chemlights -= n
		by.chemlights += n
		by._update_hand_stick()
		got.append("케미라이트 %d" % n)
	n = mini(bandages, by.max_bandages - by.bandages)
	if n > 0:
		bandages -= n
		by.bandages += n
		got.append("붕대 %d" % n)
	if baton and not by.has_baton:
		baton = false
		by.set_baton(true)
		got.append("경광봉")
	if got.is_empty():
		GameState.say("선반이 비었다." if total() == 0 else "더 들 수가 없다.")
		return
	Sfx.play("rummage", -6.0)
	GameState.say(" · ".join(got) + "을(를) 챙겼다.")
	_redraw()

func get_hint() -> String:
	if total() == 0:
		return ""
	return "E · 보급품 챙기기"

## 선반 위에 남은 물건을 개수만큼 그린다 (화면 숫자 대신 눈으로 남은 양을 본다)
func _redraw() -> void:
	for c in _items.get_children():
		c.queue_free()
	var y := 0.93
	for i in lanterns:      # 랜턴: 노란 상자
		_box(Vector3(0.14, 0.22, 0.14), Vector3(-0.45 + i * 0.2, y + 0.11, 0.05), Color(0.75, 0.6, 0.2))
	for i in chemlights:    # 케미라이트: 초록 막대
		_box(Vector3(0.02, 0.02, 0.13), Vector3(0.2 + (i % 5) * 0.035, y + 0.01 + (i / 5) * 0.022, 0.05), Color(0.4, 0.95, 0.5), 0.5)
	for i in bandages:      # 붕대: 흰 롤
		_box(Vector3(0.07, 0.07, 0.07), Vector3(0.48 + i * 0.09, y + 0.035, 0.08), Color(0.92, 0.92, 0.88))
	if baton:               # 경광봉: 아래 칸에 눕혀 둔 빨간 막대
		_box(Vector3(0.5, 0.04, 0.04), Vector3(0.0, 0.5, 0.08), Color(1.0, 0.2, 0.12), 0.6)

func _box(size: Vector3, pos: Vector3, col: Color, glow := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	bm.material = m
	mi.mesh = bm
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_items.add_child(mi)
