extends CanvasLayer
## 화면 UI. 게임 로직은 모르고, GameState와 플레이어 값을 읽어서 보여주기만 한다.
## 자식 노드: Root(Control) > Flash(ColorRect), Info(Label), Hint(Label), Center(Label), Crosshair(Label)

@onready var flash: ColorRect = $Root/Flash
@onready var info: Label = $Root/Info
@onready var hint: Label = $Root/Hint
@onready var center: Label = $Root/Center

var lines: Array[String] = []
var player: Node

func _ready() -> void:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "NanumGothic", "sans-serif"])
	$Root.theme = Theme.new()
	$Root.theme.default_font = f
	$Root.theme.default_font_size = 18
	GameState.message.connect(_on_message)
	_on_message("화면을 클릭하면 마우스로 둘러본다. WASD 이동 · F 램프 · Q 랜턴 · E 문/차광막(길게) · R 다시")

func _on_message(t: String) -> void:
	lines.append(t)
	if lines.size() > 4:
		lines.pop_front()

func _process(_dt: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return
	var lamp = player.headlamp
	info.text = "굳음 %d%%   헤드램프 %d%%%s   랜턴 %d\n구출 %d/%d   차광막 %d/%d\n\n%s" % [
		int(player.stiff), int(lamp.battery), "" if lamp.is_on() else " (꺼짐)", player.lanterns_held,
		GameState.rescued, GameState.need_rescue, GameState.curtains_open, GameState.curtains_total,
		"\n".join(lines)]
	flash.color.a = clamp((player.stiff - 40.0) / 60.0, 0.0, 1.0) * 0.15 + (0.3 if player.grab_cooldown > 0.8 else 0.0)
	var t: Node = player.looking_at()
	hint.text = t.get_hint() if t and t.has_method("get_hint") else ""
	if GameState.game_over:
		center.text = "몸이 완전히 굳었다\nR로 다시 시작"
	elif GameState.won:
		center.text = "1층 확보\n구출 %d명 · R로 다시 시작" % GameState.rescued
	else:
		center.text = ""
