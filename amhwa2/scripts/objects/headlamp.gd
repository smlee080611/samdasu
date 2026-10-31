extends SpotLight3D
## 헤드램프: 실제 조명 + "light_source" 그룹으로 빛 판정에 참여

@export var battery := 100.0
@export var drain_per_sec := 0.8
var on := true
var protects_body := false   # 헤드램프 빛은 내 몸이 굳는 걸 막아주지는 않는다

var base_energy := 2.6
var base_range := 14.0
var base_angle := 42.0
const FULL_COLOR := Color(1.0, 0.97, 0.9)
const LOW_COLOR := Color(1.0, 0.62, 0.32)

func _ready() -> void:
	add_to_group("light_source")
	base_energy = light_energy
	base_range = spot_range
	base_angle = spot_angle

func is_on() -> bool:
	return on and battery > 0.0

func toggle() -> void:
	if battery <= 0.0:
		GameState.say("배터리가 없다.")
		return
	on = not on
	Sfx.play("click", -6.0)

func recharge(amount: float) -> void:
	battery = min(100.0, battery + amount)

func _process(dt: float) -> void:
	if is_on() and not GameState.is_frozen():
		battery -= drain_per_sec * dt
		if battery <= 0.0:
			battery = 0.0
	visible = is_on()
	# 배터리 숫자는 화면에 없다. 대신 빛 자체가 점점 누레지고, 짧아지고, 좁아진다.
	var k := clampf(battery / 100.0, 0.0, 1.0)
	var weak := pow(k, 0.7)
	light_color = LOW_COLOR.lerp(FULL_COLOR, weak)
	spot_range = base_range * (0.5 + 0.5 * weak)
	spot_angle = base_angle * (0.78 + 0.22 * weak)
	light_energy = base_energy * (0.35 + 0.65 * weak)
	if battery < 20.0 and randf() < 0.08:   # 거의 다 닳으면 깜빡임
		light_energy = 0.1

func light_value(target: Vector3, exclude: Array[RID]) -> float:
	if not is_on():
		return 0.0
	var to := target - global_position
	var d := to.length()
	if d >= spot_range or rad_to_deg((-global_transform.basis.z).angle_to(to)) >= spot_angle * 0.65:
		return 0.0
	if not LightSystem.ray_clear(global_position, target, exclude):
		return 0.0
	return 1.0 - d / spot_range * 0.6
