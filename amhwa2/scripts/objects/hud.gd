extends CanvasLayer
## 화면 UI. 숫자 대신 몸으로 보여준다.
##  - 굳음: 화면 가장자리가 돌로 변하고(Screen 셰이더) 금이 자란다(Cracks)
##  - 붙잡힘: 가장자리가 붉게 번진다
##  - 배터리·랜턴: 바뀔 때, 배터리가 적을 때, Tab을 누를 때만 왼쪽 아래에 잠깐
##  - 메시지: 아래쪽 자막 / 상호작용: 조준점 아래 작은 글씨
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
const GOAL := "병실의 차광막을 걷고, 세 사람을 입구로 데려가자."
const CONTROLS := "WASD 이동 · 클릭 후 마우스로 둘러보기 · F 헤드램프 · Q 랜턴 놓기/줍기 · E 상호작용 · Tab 상태 · R 다시"

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
var status_t := 0.0        # 상태 표시 남은 시간
var subtitle_tw: Tween
var intro_tw: Tween
var stiff_shown := 0.0

func _ready() -> void:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "NanumGothic", "sans-serif"])
	$Root.theme = Theme.new()
	$Root.theme.default_font = f
	$Root.theme.default_font_size = 18
	GameState.message.connect(_show_subtitle)
	GameState.note_opened.connect(_open_note)
	GameState.status_poke.connect(func(): status_t = 3.0)
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

	# 상태 표시
	var lamp = player.headlamp
	status_t = maxf(0.0, status_t - dt)
	var tab := Input.is_action_pressed("status")
	var low: bool = lamp.battery < 25.0 and lamp.is_on()
	var a := 0.0
	if status_t > 0.0 or tab:
		a = minf(1.0, status_t * 2.0) if not tab else 1.0
	if low:
		a = maxf(a, 0.55 + 0.45 * sin(Time.get_ticks_msec() / 180.0))
	status.modulate.a = lerpf(status.modulate.a, a, minf(1.0, dt * 8.0))
	status.battery = lamp.battery
	status.lamp_on = lamp.is_on()
	status.lanterns = player.lanterns_held
	status.lanterns_max = player.lanterns_held + player.placed_lanterns.size()
	status.show_counts = tab
	status.counts_text = "구출 %d/%d   차광막 %d/%d" % [GameState.rescued, GameState.need_rescue, GameState.curtains_open, GameState.curtains_total]
	if tab and controls.modulate.a < 0.6:
		controls.modulate.a = 0.6

	var t: Node = player.looking_at()
	hint.text = t.get_hint() if t and t.has_method("get_hint") and not GameState.ui_blocking else ""
	if GameState.game_over:
		center.text = "몸이 완전히 굳었다\n\nR로 다시 시작"
	elif GameState.won:
		center.text = "1층 확보\n구출 %d명\n\nR로 다시 시작" % GameState.rescued
	else:
		center.text = ""
