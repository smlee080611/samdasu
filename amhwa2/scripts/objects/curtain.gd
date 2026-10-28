extends StaticBody3D
## 차광막. E를 길게 눌러 걷으면 Moonlight(자식 OmniLight3D)가 켜진다.
## 자식 노드: CollisionShape3D, Mesh, Moonlight(OmniLight3D + point_light_source.gd)

@export var hold_seconds := 1.5
@export var open_material: StandardMaterial3D

@onready var mesh: MeshInstance3D = $Mesh
@onready var moon = $Moonlight
var open := false
var progress := 0.0

func _ready() -> void:
	GameState.curtains_total += 1
	moon.set_active(false)

## 플레이어가 E를 누르고 있는 동안 매 프레임 호출. 다 걷었으면 true
func hold(seconds: float) -> bool:
	if open:
		return false
	progress = seconds / hold_seconds
	if progress < 1.0:
		return false
	open = true
	mesh.material_override = open_material
	moon.set_active(true)
	GameState.curtain_opened()
	return true

func get_hint() -> String:
	return "" if open else "E 길게 · 차광막 걷기"
