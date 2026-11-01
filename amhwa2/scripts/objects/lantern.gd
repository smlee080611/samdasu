extends Node3D
## 바닥에 놓는 랜턴. 불꽃이 살짝 흔들리며 빛이 깜빡인다.
## 빛 판정은 자식 Light(OmniLight3D + point_light_source.gd)가 한다.

@onready var light: OmniLight3D = $Light
@onready var fill: OmniLight3D = $Fill
var base_fill := 0.22
@onready var flame: MeshInstance3D = $Flame
var base_energy := 1.6
var t := 0.0

func _ready() -> void:
	base_energy = light.light_energy
	base_fill = fill.light_energy
	t = randf() * 10.0
	# 랜턴 창살·뚜껑이 바닥에 진한 부채꼴 그림자를 만들지 않게
	for c in get_children():
		if c is MeshInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(dt: float) -> void:
	t += dt
	var f := 0.9 + 0.06 * sin(t * 7.3) + 0.04 * sin(t * 17.1 + 1.3) + randf_range(-0.02, 0.02)
	light.light_energy = base_energy * f
	fill.light_energy = base_fill * f
	flame.scale = Vector3(1.0, f, 1.0)
