extends Node3D
## 바닥에 놓는 랜턴. 불꽃이 살짝 흔들리며 빛이 깜빡인다.
## 빛 판정은 자식 Light(OmniLight3D + point_light_source.gd)가 한다.

@onready var light: OmniLight3D = $Light
@onready var flame: MeshInstance3D = $Flame
var base_energy := 1.6
var t := 0.0

func _ready() -> void:
	base_energy = light.light_energy
	t = randf() * 10.0

func _process(dt: float) -> void:
	t += dt
	var f := 0.9 + 0.06 * sin(t * 7.3) + 0.04 * sin(t * 17.1 + 1.3) + randf_range(-0.02, 0.02)
	light.light_energy = base_energy * f
	flame.scale = Vector3(1.0, f, 1.0)
