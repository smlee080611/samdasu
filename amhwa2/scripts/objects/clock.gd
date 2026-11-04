extends Node3D
## 벽시계. 정전돼도 건전지로 가는 시계라 계속 돈다.
## 남은 밤 시간은 화면 숫자 대신 이 시계(간호사실, 엘리베이터 홀)와 창밖 하늘로만 보인다.
## GameState.clock_minutes(자정부터 분)를 읽어 바늘을 돌린다. 시각은 Night 노드(night.gd)가 정한다.
## 이 노드의 +Z 쪽이 시계 앞면이다 (벽에 붙일 때 앞면이 방 안을 보게 돌린다).

@export var radius := 0.22

var hour_hand: Node3D
var minute_hand: Node3D

func _ready() -> void:
	var face_m := StandardMaterial3D.new()
	face_m.albedo_color = Color(0.86, 0.85, 0.8)
	var dark_m := StandardMaterial3D.new()
	dark_m.albedo_color = Color(0.08, 0.08, 0.08)
	# 둥근 판 (원기둥을 눕혀서 앞면이 +Z를 보게)
	var rim := _mesh(_cyl(radius + 0.02, 0.03, dark_m), Vector3(0, 0, 0.015))
	rim.rotation.x = PI * 0.5
	var face := _mesh(_cyl(radius, 0.032, face_m), Vector3(0, 0, 0.018))
	face.rotation.x = PI * 0.5
	# 눈금 12개 (3·6·9·12시는 굵게)
	for i in 12:
		var a := TAU * i / 12.0
		var big := i % 3 == 0
		var b := BoxMesh.new()
		b.size = Vector3(0.012 if big else 0.006, 0.04 if big else 0.025, 0.004)
		b.material = dark_m
		var t := _mesh(b, Vector3(sin(a), cos(a), 0) * (radius - 0.035) + Vector3(0, 0, 0.036))
		t.rotation.z = -a
	hour_hand = _hand(radius * 0.5, 0.014, dark_m, 0.038)
	minute_hand = _hand(radius * 0.8, 0.008, dark_m, 0.041)
	_update()

func _process(_dt: float) -> void:
	_update()

func _update() -> void:
	var m := fmod(GameState.clock_minutes, 720.0)
	# 앞(+Z)에서 볼 때 시계 방향 = Z축 음의 회전
	minute_hand.rotation.z = -TAU * fmod(m, 60.0) / 60.0
	hour_hand.rotation.z = -TAU * m / 720.0

func _hand(length: float, width: float, mat: Material, z: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0, z)
	add_child(pivot)
	var b := BoxMesh.new()
	b.size = Vector3(width, length, 0.004)
	b.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.position = Vector3(0, length * 0.4, 0)   # 중심 뒤로 조금 튀어나오게
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mi)
	return pivot

func _cyl(r: float, h: float, mat: Material) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 32
	c.material = mat
	return c

func _mesh(m: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
