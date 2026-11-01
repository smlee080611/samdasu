extends Node3D
## 바닥에 놓는 랜턴. 불꽃이 살짝 흔들리며 빛이 깜빡인다.
## 빛 판정은 자식 Light(OmniLight3D + point_light_source.gd)가 한다.
## 놓으면 심지에 불이 옮겨붙듯 light_up_time초에 걸쳐 밝아진다. 빛의 효과(몸이 풀림, 광인 회복)도 밝기만큼만 나온다.
## 그래서 위급할 때 툭 놓는 건 통하지 않고, 미리 길목에 놓아 둬야 한다.

@onready var light: OmniLight3D = $Light
@onready var fill: OmniLight3D = $Fill
var base_fill := 0.22
@export var light_up_time := 2.5
var lit_k := 0.0          # 0 꺼짐 ~ 1 다 밝아짐
var base_power := 1.0
var dying := false
@onready var flame: MeshInstance3D = $Flame
var base_energy := 1.6
var t := 0.0

func _ready() -> void:
	base_energy = light.light_energy
	base_fill = fill.light_energy
	base_power = light.power
	light.power = 0.0
	t = randf() * 10.0
	# 랜턴 창살·뚜껑이 바닥에 진한 부채꼴 그림자를 만들지 않게
	for c in get_children():
		if c is MeshInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(dt: float) -> void:
	t += dt
	if dying:
		lit_k = maxf(0.0, lit_k - dt * 3.0)
		if lit_k <= 0.0:
			queue_free()
	else:
		lit_k = minf(1.0, lit_k + dt / light_up_time)
	var k := lit_k * lit_k
	var f := 0.9 + 0.06 * sin(t * 7.3) + 0.04 * sin(t * 17.1 + 1.3) + randf_range(-0.02, 0.02)
	if lit_k < 1.0 and not dying:
		f *= 0.7 + randf() * 0.5     # 불이 붙는 동안 지직거림
	light.light_energy = base_energy * f * k
	fill.light_energy = base_fill * f * k
	light.power = base_power * k
	flame.scale = Vector3(1.0, f * maxf(lit_k, 0.15), 1.0)

## 주울 때: 불을 끄고 사라진다
func put_out() -> void:
	dying = true
	light.power = 0.0
