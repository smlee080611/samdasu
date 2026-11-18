extends Node3D
## 지하의 낡은 전구. 평소엔 꺼져 있다. 발전기 크랭크를 돌리는 동안 전기가 찔끔찔끔 들어와 껌뻑인다.
## 이 깜빡임이 지하의 "웨이브"를 만든다: 잠깐씩 비치는 빛에 어둠 속 석상들이 몸만 풀려 광인이 된다
## (정신이 돌아올 만큼 오래 비추지는 못한다). 가까운 전구 밑의 사람부터 먼저 깨어난다.
## 그 층에 불이 들어오면(차단기) 꺼진 것처럼 묻힌다. 빛 판정 약속은 다른 빛과 같다(light_source 그룹 + light_value).

@export var reach := 5.0          ## 비추는 범위(m)
@export var on_time := 0.7        ## 한 번 켜져 있는 시간
@export var gap_min := 1.2        ## 다음 깜빡임까지 (짧을수록 석상이 빨리 깨어남)
@export var gap_max := 2.6
@export var strength := 0.55      ## 켜져 있을 때의 밝기 판정값
@export var energy := 1.6         ## 화면에 보이는 밝기

var protects_body := false        # 껌뻑이는 약한 빛: 몸이 굳는 걸 막아 주지 못한다
var lit := false
var _t := 0.0
var _light: OmniLight3D
var _bulb: MeshInstance3D
var _mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("light_source")
	_t = randf_range(0.0, gap_max)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.75, 0.45)
	_light.omni_range = reach * 1.3
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	_bulb = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.14
	_bulb.mesh = sm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.5, 0.45, 0.35)
	_mat.emission = Color(1.0, 0.7, 0.4)
	_bulb.material_override = _mat
	add_child(_bulb)

func _process(dt: float) -> void:
	var g: Node = null
	for x in get_tree().get_nodes_in_group("generator"):
		g = x
	var active: bool = g != null and g.cranking
	if not active:
		_switch(false)
		return
	_t -= dt
	if _t <= 0.0:
		_switch(not lit)
		_t = on_time * randf_range(0.6, 1.2) if lit else randf_range(gap_min, gap_max)

func _switch(v: bool) -> void:
	if lit == v:
		return
	lit = v
	_light.light_energy = energy if v else 0.0
	_mat.emission_enabled = v
	_mat.emission_energy_multiplier = 3.0

func light_value(target: Vector3, exclude: Array[RID]) -> float:
	if not lit:
		return 0.0
	var d := global_position.distance_to(target)
	if d >= reach:
		return 0.0
	if not LightSystem.ray_clear(global_position, target, exclude):
		return 0.0
	return strength * (1.0 - d / reach * 0.5)
