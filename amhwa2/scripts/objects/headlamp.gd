extends SpotLight3D
## 헤드램프: 실제 조명 + "light_source" 그룹으로 빛 판정에 참여

@export var battery := 100.0
@export var drain_per_sec := 0.8
## 석상을 풀 때 드는 추가 소모(초당). 빛으로 사람의 몸과 정신을 되돌리는 건 램프를 가장 세게 쓰는 일이다.
## 한 사람을 끝까지(석상 → 광인 → 회복) 비추는 데 약 12~15초 → 이것만으로 배터리 절반 가까이 든다.
## 여럿을 한 빛에 같이 비추면 한 번만 닳는다 (모아서 푸는 것도 요령).
@export var wake_drain_per_sec := 4.0
var waking_t := 0.0     # 사람이 이 빛으로 풀리는 중이면 잠깐 켜진다 (person.gd가 mark_waking으로 알림)
var on := true
var blackout_t := 0.0   # 붙잡혔을 때 잠깐 꺼짐
var protects_body := false   # 헤드램프 빛은 내 몸이 굳는 걸 막아주지는 않는다

var base_energy := 2.6
## 초점: 헤드를 돌려 빛을 모으거나 퍼뜨린다 (실제 줌 헤드램프처럼). 마우스 휠로 조절.
## 0 = 넓게(56도, 10m, 조금 어둡게) ~ 1 = 좁게(24도, 20m, 밝게). 배터리 소모는 같다.
var zoom := 0.4
const WIDE_ANGLE := 56.0
const NARROW_ANGLE := 24.0
const WIDE_RANGE := 10.0
const NARROW_RANGE := 20.0
const FULL_COLOR := Color(1.0, 0.97, 0.9)
const LOW_COLOR := Color(1.0, 0.62, 0.32)

func _ready() -> void:
	add_to_group("light_source")
	base_energy = light_energy

func is_on() -> bool:
	return on and battery > 0.0 and blackout_t <= 0.0

func toggle() -> void:
	if battery <= 0.0:
		GameState.say("배터리가 없다.")
		return
	on = not on
	Sfx.play("click", -6.0)

func adjust_zoom(delta: float) -> void:
	var before := zoom
	zoom = clampf(zoom + delta, 0.0, 1.0)
	if zoom != before:
		Sfx.play("click", -22.0, 0.3)

## 이 램프 빛이 지금 누군가를 풀고 있다 (석상의 몸, 광인의 정신)
func mark_waking() -> void:
	waking_t = 0.1

## 사람에게 닿는 빛 중 이 램프 몫이 충분한가: 랜턴·달빛만으로 풀리는 사람 때문에 배터리가 닳지 않게
func lights_person(target: Vector3, exclude: Array[RID]) -> bool:
	return light_value(target + Vector3(0, 1.0, 0), exclude) > LightSystem.LIT_THRESHOLD

func recharge(amount: float) -> void:
	battery = min(100.0, battery + amount)

func _process(dt: float) -> void:
	blackout_t = maxf(0.0, blackout_t - dt)
	waking_t = maxf(0.0, waking_t - dt)
	if is_on() and not GameState.is_frozen():
		battery -= (drain_per_sec + (wake_drain_per_sec if waking_t > 0.0 else 0.0)) * dt
		if battery <= 0.0:
			battery = 0.0
	visible = is_on()
	# 배터리 숫자는 화면에 없다. 대신 빛 자체가 점점 누레지고, 짧아지고, 좁아진다.
	var k := clampf(battery / 100.0, 0.0, 1.0)
	var weak := pow(k, 0.7)
	light_color = LOW_COLOR.lerp(FULL_COLOR, weak)
	spot_range = lerpf(WIDE_RANGE, NARROW_RANGE, zoom) * (0.5 + 0.5 * weak)
	spot_angle = lerpf(WIDE_ANGLE, NARROW_ANGLE, zoom) * (0.78 + 0.22 * weak)
	light_energy = base_energy * lerpf(0.75, 1.45, zoom) / 1.03 * (0.35 + 0.65 * weak)
	if battery < 20.0 and randf() < 0.08:   # 거의 다 닳으면 깜빡임
		light_energy = 0.1

func light_value(target: Vector3, exclude: Array[RID]) -> float:
	if not is_on():
		return 0.0
	var to := target - global_position
	var d := to.length()
	# 가까이 있는 사람은 빛 원뿔 가장자리에 걸쳐도 몸이 비친다 (바로 앞 1~2m는 넓게)
	var lim := spot_angle * 0.65 + clampf((3.0 - d) * 12.0, 0.0, 28.0)
	if d >= spot_range or rad_to_deg((-global_transform.basis.z).angle_to(to)) >= lim:
		return 0.0
	if not LightSystem.ray_clear(global_position, target, exclude):
		return 0.0
	return 1.0 - d / spot_range * 0.6
