@tool
extends StaticBody3D
class_name SurgicalLight
## 수술등(무영등)·중환자실 천장등. 정전으로 꺼져 있다.
## 벽에 붙은 비상 배터리함(이 노드)에 대고 E를 길게 누르면, 누르는 동안 헤드램프 배터리를 이쪽으로 옮겨 꽂는다.
## 옮긴 만큼 등이 켜져 있다가 닳으면 꺼진다. 한 번 꽂은 배터리는 다시 빼지 못한다.
##  - 등 아래는 밝아서 석상이 풀리고, 광인은 정신이 돌아오고, 내 몸도 굳지 않는다(protects_body).
##  - 한 빛 아래 여럿을 같이 풀 수 있어서, 같은 배터리로 헤드램프보다 많은 사람을 구할 수 있다.
##    대신 헤드램프가 어두워지고, 깨어난 광인은 빛을 피해 문으로 달아난다. 문을 닫아 두면 빛 속에 남는다.
## 2층(창이 없는 층)의 핵심 선택: 배터리를 내 헤드램프에 쓸 것인가, 이 방의 등에 꽂을 것인가.
## 빛 판정은 다른 빛과 같은 약속("light_source" 그룹 + light_value)으로 한다.
## 에디터에서도 돈다(@tool): 층 씬을 열면 fixtures 자리에 등갓이 보인다 (켜진 모습은 게임에서만).

@export var fixtures: PackedVector3Array = PackedVector3Array()  ## 등이 달린 곳 (층 기준 좌표). 보통 천장 바로 아래 y = 2.75
@export var reach := 3.4             ## 등 하나가 비추는 범위 (등 바로 아래에서 바닥을 따라 잰 거리, m)
@export var drain_per_sec := 1.5     ## 켜져 있을 때 초당 닳는 양 (헤드램프 배터리 %와 같은 단위)
@export var feed_rate := 25.0        ## E를 누르고 있을 때 초당 옮겨 꽂는 양
@export var capacity := 100.0        ## 배터리함에 들어가는 최대량
@export var energy := 3.0            ## 등 하나의 밝기 (화면에 보이는 것만, 판정과 무관)
@export var room_name := "수술실"    ## 처음 꽂을 때의 생각 대사에 씀

var charge := 0.0
var protects_body := true   # 고정된 강한 빛: 이 아래에선 몸이 굳지 않는다
var _last_hold := 0.0
var _said := false
var _was_on := false
var _lights: Array[SpotLight3D] = []
var _heads: Array[MeshInstance3D] = []
var _head_mat: StandardMaterial3D
var _led_mat: StandardMaterial3D
var _flick := 1.0

func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("light_source")
		add_to_group("surgical_light")
	else:
		set_process(false)
	_head_mat = StandardMaterial3D.new()
	_head_mat.albedo_color = Color(0.8, 0.82, 0.8)
	_head_mat.roughness = 0.4
	_head_mat.emission = Color(1.0, 0.97, 0.9)
	var arm_mat := StandardMaterial3D.new()
	arm_mat.albedo_color = Color(0.55, 0.57, 0.58)
	arm_mat.metallic = 0.5
	arm_mat.roughness = 0.4
	var led := get_node_or_null("Led") as MeshInstance3D
	if led:
		_led_mat = StandardMaterial3D.new()
		_led_mat.emission_enabled = true
		led.material_override = _led_mat
	var first := true
	for f in fixtures:
		# 등갓(원반) + 천장에 매다는 팔. 실제 위치는 층 기준 좌표라 이 노드가 돌아가 있어도 상관없다
		var head := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.22
		cm.bottom_radius = 0.42
		cm.height = 0.16
		cm.radial_segments = 16
		head.mesh = cm
		head.material_override = _head_mat
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(head)
		head.global_position = f
		head.global_rotation = Vector3.ZERO
		_heads.append(head)
		var arm := MeshInstance3D.new()
		var am := CylinderMesh.new()
		am.top_radius = 0.03
		am.bottom_radius = 0.03
		am.height = maxf(0.05, 3.0 - f.y - 0.08)
		arm.mesh = am
		arm.material_override = arm_mat
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(arm)
		arm.global_position = f + Vector3(0, 0.08 + am.height * 0.5, 0)
		arm.global_rotation = Vector3.ZERO
		var l := SpotLight3D.new()
		l.light_color = Color(1.0, 0.97, 0.92)
		l.spot_angle = 68.0
		l.spot_range = reach * 2.2
		l.spot_attenuation = 0.6
		l.light_energy = 0.0
		l.shadow_enabled = first     # 그림자는 등 하나만 (가벼운 렌더러라 여러 개는 무거움)
		first = false
		add_child(l)
		l.global_position = f - Vector3(0, 0.1, 0)
		l.global_rotation = Vector3(-PI / 2, 0, 0)   # 바로 아래를 비춘다
		_lights.append(l)
	_apply(0.0)

func is_on() -> bool:
	return charge > 0.0

## E를 누르고 있는 동안 매 프레임 불림 (seconds = 누른 시간). 누르는 동안 조금씩 옮겨 꽂는다
func hold(seconds: float) -> bool:
	var dt := maxf(0.0, seconds - _last_hold)
	_last_hold = seconds
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return false
	var amount := minf(feed_rate * dt, minf(p.headlamp.battery, capacity - charge))
	if amount <= 0.0:
		return false
	if not _said:
		_said = true
		GameState.say("헤드램프 배터리를 하나씩 빼서 %s 등 배터리함에 옮겨 꽂는다." % room_name)
	p.headlamp.battery -= amount
	charge += amount
	return false

func release(_seconds: float) -> void:
	_last_hold = 0.0

func get_hint() -> String:
	var p = get_tree().get_first_node_in_group("player")
	if p and p.headlamp.battery <= 0.0:
		return "옮길 배터리가 없다"
	if charge >= capacity - 0.5:
		return "배터리함이 가득 찼다"
	return "E 길게 · 배터리 옮겨 꽂기"

func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	if charge > 0.0 and not GameState.is_frozen():
		charge = maxf(0.0, charge - drain_per_sec * dt)
	var on := charge > 0.0
	if on != _was_on:
		_was_on = on
		if on:
			Sfx.play_at("elevator_buzz", global_position + Vector3.UP, -6.0, 0.0)
		else:
			Sfx.play_at("click", global_position + Vector3.UP, -4.0, 0.0)
	# 거의 다 닳으면 깜빡인다 (꺼지기 전에 알 수 있게)
	_flick = 1.0
	if on and charge < 8.0 and randf() < 0.12:
		_flick = 0.15
	_apply(charge)

func _apply(c: float) -> void:
	var on := c > 0.0
	var k := clampf(c / 15.0, 0.35, 1.0) * _flick if on else 0.0
	for l in _lights:
		l.light_energy = energy * k
		l.visible = on
	_head_mat.emission_enabled = on
	_head_mat.emission_energy_multiplier = 2.5 * k
	if _led_mat:
		# 배터리함 표시등: 비었으면 희미한 빨강, 차 있으면 초록 (밝기 = 남은 양)
		if on:
			_led_mat.albedo_color = Color(0.2, 1.0, 0.35)
			_led_mat.emission = Color(0.2, 1.0, 0.35)
			_led_mat.emission_energy_multiplier = 0.6 + 2.0 * clampf(c / capacity, 0.0, 1.0)
		else:
			_led_mat.albedo_color = Color(0.6, 0.08, 0.05)
			_led_mat.emission = Color(1.0, 0.1, 0.05)
			_led_mat.emission_energy_multiplier = 0.5

## 빛 판정: 등 바로 아래에서 reach 안이고, 등에서 그 사람까지 가리는 것이 없으면 밝다
func light_value(target: Vector3, exclude: Array[RID]) -> float:
	if charge <= 0.0:
		return 0.0
	var best := 0.0
	for f in fixtures:
		var flat := Vector2(target.x - f.x, target.z - f.z).length()
		if flat >= reach:
			continue
		var v := 1.0 - flat / reach * 0.45
		if v <= best:
			continue
		if LightSystem.ray_clear(f - Vector3(0, 0.25, 0), target, exclude):
			best = v
	return best
