extends CanvasLayer
## 화면 UI. 숫자 대신 몸으로 보여준다.
##  - 굳음: 화면 가장자리가 돌로 변하고(Screen 셰이더) 금이 자란다(Cracks)
##  - 붙잡힘: 가장자리가 붉게 번진다
##  - 배터리: 숫자 없음. 헤드램프 빛이 누레지고 짧아진다(headlamp.gd)
##  - 구출 수·차광막 수: 숫자 없음. 구한 사람은 엘리베이터 홀에 모이고, 목표는 간호사실 현황판에
##  - 메시지: 주인공의 생각과 들리는 말만 아래쪽 자막으로 / 상호작용: 조준점 아래 작은 글씨
##  - 개발용: F1을 누르는 동안 왼쪽 아래에 배터리·랜턴·구출·차광막 (에디터 실행 때만)
##  - 쪽지 읽기 패널, 시작 연출
## 게임 로직은 모르고 GameState와 플레이어 값을 읽어서 보여주기만 한다.

const INTRO := [
	"새벽 2시 10분.\n병원 전체가 정전됐다.",
	"비상발전기는 돌지 않았다.",
	"불 꺼진 병동에서\n사람들이 하나둘 움직이지 않게 되었다.",
	"나는 야간 근무 간호사다.",
	"손끝이 조금씩 무거워진다.\n어둠 속에 오래 있으면 안 된다.",
	"헤드램프 하나, 랜턴 둘.",
]
const GOAL := "사람들을 깨워 현관 밖으로 내보내야 한다. 먼저 간호사실로 가 보자."
const CONTROLS := "WASD 이동 · 마우스 둘러보기 · F/우클릭 헤드램프 · 휠 초점 · 좌클릭/V 휘두르기 · Space 밀치기 · Q 랜턴 · G 케미라이트(C 확인) · E 문(누를 때마다 틈→활짝→닫힘) · E 길게 뒤지기 · Shift 달리기 · F9 다시"

@onready var screen_mat: ShaderMaterial = $Root/Screen.material
@onready var cracks = $Root/Cracks
@onready var hint: Label = $Root/Hint
@onready var subtitle: Label = $Root/Subtitle
@onready var controls: Label = $Root/Controls
@onready var status = $Root/Status
@onready var center: Label = $Root/Center
@onready var note: Control = $Root/Note
@onready var note_title: Label = $Root/Note/Margin/VBox/Title
@onready var note_body: Label = $Root/Note/Margin/VBox/Body
@onready var intro: ColorRect = $Root/Intro
@onready var intro_text: Label = $Root/Intro/Text

var player: Node
var fader: ColorRect
var subtitle_tw: Tween
var intro_tw: Tween
var stiff_shown := 0.0
var result_t := 0.0

func _ready() -> void:
	# 한글 폰트는 프로젝트에 넣은 파일을 쓴다. 웹(브라우저)에서는 시스템 폰트를 못 써서 SystemFont면 글자가 네모로 나온다
	var f: Font = load("res://fonts/Pretendard-Regular.otf")
	$Root.theme = Theme.new()
	$Root.theme.default_font = f
	$Root.theme.default_font_size = 18
	add_to_group("hud")
	# 층을 옮길 때 잠깐 화면을 덮는 검은 막 (계단을 오르내리는 동안)
	fader = ColorRect.new()
	fader.color = Color.BLACK
	fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fader.modulate.a = 0.0
	$Root.add_child(fader)
	$Root.move_child(fader, $Root/Subtitle.get_index())   # 자막(층에 올라왔을 때의 생각)은 막 위에 보이게
	GameState.message.connect(_show_subtitle)
	GameState.note_opened.connect(_open_note)
	GameState.relay.connect(_play_relay)
	note.visible = false
	subtitle.modulate.a = 0.0
	if GameState.intro_seen:
		intro.visible = false
		controls.modulate.a = 0.0
	else:
		_play_intro()

# ---------- 시작 연출 ----------
func _play_intro() -> void:
	GameState.ui_blocking = true
	intro.visible = true
	intro.modulate.a = 1.0
	intro_text.modulate.a = 0.0
	controls.modulate.a = 0.0
	intro_tw = create_tween()
	for line in INTRO:
		intro_tw.tween_callback(intro_text.set.bind("text", line))
		intro_tw.tween_property(intro_text, "modulate:a", 1.0, 0.9)
		intro_tw.tween_interval(1.6 + line.length() * 0.03)
		intro_tw.tween_property(intro_text, "modulate:a", 0.0, 0.7)
	intro_tw.tween_callback(_end_intro)

func _end_intro() -> void:
	if intro_tw:
		intro_tw.kill()
	GameState.intro_seen = true
	GameState.ui_blocking = false
	var t := create_tween()
	t.tween_property(intro, "modulate:a", 0.0, 1.5)
	t.tween_callback(intro.hide)
	_show_subtitle(GOAL, 6.0)
	var c := create_tween()
	c.tween_property(controls, "modulate:a", 0.85, 1.0)
	c.tween_interval(12.0)
	c.tween_property(controls, "modulate:a", 0.0, 2.0)

# ---------- 교대 ----------
func _play_relay(text: String) -> void:
	GameState.ui_blocking = true
	intro.visible = true
	intro.modulate.a = 0.0
	$Root/Intro/Skip.visible = false
	intro_text.text = text
	intro_text.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(intro, "modulate:a", 1.0, 0.6)
	t.tween_property(intro_text, "modulate:a", 1.0, 0.8)
	t.tween_interval(2.6)
	t.tween_callback(Sfx.play.bind("inhale", -4.0, 0.0))
	t.tween_property(intro_text, "modulate:a", 0.0, 0.6)
	t.tween_callback(func(): GameState.ui_blocking = false)
	t.tween_property(intro, "modulate:a", 0.0, 1.2)
	t.tween_callback(intro.hide)

# ---------- 쪽지 ----------
func _open_note(title: String, body: String) -> void:
	note_title.text = title
	note_body.text = body
	note.visible = true
	note.modulate.a = 0.0
	create_tween().tween_property(note, "modulate:a", 1.0, 0.25)
	Sfx.play("curtain", -14.0, 0.3)   # 종이 바스락 대용

func _close_note() -> void:
	note.visible = false
	GameState.ui_blocking = false

func _input(e: InputEvent) -> void:
	var pressed: bool = (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventMouseButton and e.pressed)
	if intro.visible and not GameState.intro_seen:
		if pressed:
			_end_intro()
			if e is InputEventMouseButton:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return
	if note.visible and pressed:
		if e.is_action_pressed("interact") or e is InputEventMouseButton \
				or (e is InputEventKey and e.physical_keycode == KEY_ESCAPE):
			_close_note()
			get_viewport().set_input_as_handled()

# ---------- 자막 ----------
func _show_subtitle(text: String, seconds := 4.0) -> void:
	subtitle.text = text
	if subtitle_tw:
		subtitle_tw.kill()
	subtitle_tw = create_tween()
	subtitle_tw.tween_property(subtitle, "modulate:a", 1.0, 0.25)
	subtitle_tw.tween_interval(seconds)
	subtitle_tw.tween_property(subtitle, "modulate:a", 0.0, 1.0)

# ---------- 해돋이 결과 ----------
## 그때까지 현관 밖으로 데려온 사람이 결과다. 햇빛에 깨어난 사람은 따로 적는다 (차광막을 걷은 보람)
func _result_text() -> String:
	var lines := ["날이 밝았다", "", "현관 밖으로 데려온 사람  %d명" % GameState.rescued]
	if GameState.dawn_cured > 0:
		lines.append("햇빛을 받고 깨어난 사람  %d명" % GameState.dawn_cured)
	if GameState.dawn_left > 0:
		lines.append("아직 어둠 속에 남은 사람  %d명" % GameState.dawn_left)
	lines.append_array(["", "F9로 다시 시작"])
	return "\n".join(lines)

# ---------- 매 프레임 ----------
func _process(dt: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return
	# 굳음: 화면이 갑자기 튀지 않게 천천히 따라간다
	stiff_shown = lerpf(stiff_shown, player.stiff / 100.0, minf(1.0, dt * 3.0))
	screen_mat.set_shader_parameter("stiff", stiff_shown)
	screen_mat.set_shader_parameter("grab", clampf(player.grab_cooldown / 1.2, 0.0, 1.0))
	screen_mat.set_shader_parameter("aspect", get_viewport().get_visible_rect().size.aspect())
	cracks.amount = stiff_shown

	# 개발용 상태 표시 (F1, 에디터에서 실행할 때만). 플레이어에게는 숫자를 보여주지 않는다
	var lamp = player.headlamp
	var tab := OS.is_debug_build() and Input.is_action_pressed("status")
	status.modulate.a = 1.0 if tab else 0.0
	status.battery = lamp.battery
	status.lamp_on = lamp.is_on()
	status.lanterns = player.lanterns_held
	status.lanterns_max = player.lanterns_held + player.placed_lanterns.size()
	status.show_counts = tab
	var cm := int(GameState.clock_minutes)
	var lv = get_tree().get_first_node_in_group("level")
	status.counts_text = ("%dF   " % GameState.floor_no) + "구출 %d/%d   차광막 %d/%d   케미 %d   초점 %d%%   %d:%02d   홀 충전 %d" % [GameState.rescued, GameState.need_rescue, GameState.curtains_open, GameState.curtains_total, player.chemlights, int(lamp.zoom * 100), cm / 60, cm % 60, int(lv.hall_reserve) if lv else 0]

	var t: Node = player.looking_at()
	hint.text = t.get_hint() if t and t.has_method("get_hint") and not GameState.ui_blocking else ""
	if GameState.night_over:
		# 해돋이: 잠깐 창밖이 밝아지는 걸 보여 준 뒤 결과가 천천히 떠오른다
		result_t += dt
		center.text = _result_text()
		center.modulate.a = clampf((result_t - 2.0) / 1.5, 0.0, 1.0)
	elif GameState.game_over:
		center.text = "몸이 완전히 굳었다\n\nF9로 다시 시작"
	elif GameState.won:
		center.text = "1층 확보\n구출 %d명\n\nF9로 다시 시작" % GameState.rescued
	else:
		center.text = ""

## 화면을 검게 덮었다(1) 걷었다(0) 한다. await로 끝날 때까지 기다릴 수 있다 (main.gd 층 이동)
func fade(to_alpha: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(fader, "modulate:a", to_alpha, seconds)
	await tw.finished
