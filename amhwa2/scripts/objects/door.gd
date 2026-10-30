extends StaticBody3D
## 병실 문. E로 열고 닫는다. 닫힌 문은 빛과 사람을 막는 "blocker".
## 자식 노드: CollisionShape3D, Mesh(MeshInstance3D)

@export var open := false
@export var sideways := false   # 문이 동서로 놓였으면 체크(90도 회전)

@onready var mesh: Node3D = $Mesh

func _ready() -> void:
	if sideways:
		rotation.y = PI * 0.5
	_apply()

func interact(_by: Node) -> void:
	var level := get_tree().get_first_node_in_group("level") as Level
	var t := level.to_tile(global_position)
	if open:
		for p in get_tree().get_nodes_in_group("person"):
			if p.tile == t or p.target == t:
				GameState.say("문틀에 뭔가 걸려 있다.")
				return
		if level.to_tile(get_tree().get_first_node_in_group("player").global_position) == t:
			return
	open = not open
	_apply()
	Sfx.play_at("door_open" if open else "door_close", global_position + Vector3.UP * 1.5)
	level.refresh_nav()

func _apply() -> void:
	# 열리면 상호작용 레이어에만 남아서 빛·사람은 통과, E로 다시 닫을 수 있음
	collision_layer = GameState.LAYER_INTERACT if open else (GameState.LAYER_WALL | GameState.LAYER_INTERACT)
	if open:
		remove_from_group("blocker")
	else:
		add_to_group("blocker")
	mesh.rotation.y = PI * 0.5 if open else 0.0
	mesh.position = Vector3(-0.9, mesh.position.y, 0.9) if open else Vector3(0, mesh.position.y, 0)

func get_hint() -> String:
	return "E · 문 닫기" if open else "E · 문 열기"
