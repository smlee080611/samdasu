extends Node3D
## 케미라이트(꺾으면 빛나는 막대). G로 던지면 포물선을 그리며 날아가 바닥에 떨어져 약 75초 동안 초록빛을 낸다.
## 약한 빛이라 몸을 지켜 주지는 않지만, 길을 표시하고 광인이 그 자리를 피하게 만든다.
## 자식 노드: Stick(MeshInstance3D), Light(OmniLight3D + point_light_source.gd)

@export var lifetime := 75.0
@export var fade_time := 15.0
@onready var light: OmniLight3D = $Light
@onready var stick: MeshInstance3D = $Stick
var age := 0.0
var base_energy := 0.7
var base_power := 0.5
var flying := false
var fly_t := 0.0
var fly_time := 0.5
var from := Vector3.ZERO
var to := Vector3.ZERO

func _ready() -> void:
	base_energy = light.light_energy
	base_power = light.power

## 손에서 던져서 to 지점에 떨어지게 한다 (물리 없이 포물선)
func launch(start: Vector3, land: Vector3) -> void:
	from = start
	to = land
	fly_time = clampf(start.distance_to(land) / 9.0, 0.25, 0.8)
	flying = true
	global_position = start

func _process(dt: float) -> void:
	if flying:
		fly_t += dt
		var k := minf(1.0, fly_t / fly_time)
		var p := from.lerp(to, k)
		p.y += sin(PI * k) * (0.6 + from.distance_to(to) * 0.08)
		global_position = p
		rotation = Vector3(fly_t * 9.0, fly_t * 4.0, 0)
		if k >= 1.0:
			flying = false
			rotation = Vector3(0, randf() * TAU, PI * 0.5)   # 바닥에 누움
			Sfx.play_at("toss", global_position, -6.0)
	age += dt
	var life := clampf((lifetime - age) / fade_time, 0.0, 1.0)
	light.light_energy = base_energy * life
	light.power = base_power * life
	var m := stick.get_active_material(0) as StandardMaterial3D
	if m:
		m.emission_energy_multiplier = 2.5 * life + 0.05
	if age >= lifetime:
		queue_free()
