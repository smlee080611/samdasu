extends Control
## 스태미나 막대 (PEAK식). 화면 왼쪽 아래. 막대는 하나고, 최대치를 깎는 것들이 오른쪽 끝부터 덮는다:
##   [ 스태미나(밝은 색) | 빈칸 | 굳음(회색 돌, 빗금) | 부상(붉은색) ]
## 굳음·부상이 늘수록 쓸 수 있는 길이가 짧아진다. 숨이 차서 못 달리는 동안은 채운 부분이 주황색으로 깜빡인다.
## 막대 위에는 가진 물건 수량(랜턴·케미라이트·붕대·열쇠)이 작은 글씨로. 붕대를 감는 동안은 막대 위에 진행 줄.
## 스태미나가 가득 차 있고 깎인 것도 없으면 흐리게 둔다 (화면을 덜 가리게).
## 값은 hud.gd가 플레이어에서 읽어 넣는다. 게임 로직은 모른다.

@export var bar_size := Vector2(450, 18)
@export var fill_color := Color(0.95, 0.92, 0.78)
@export var winded_color := Color(1.0, 0.55, 0.25)
@export var stone_color := Color(0.5, 0.52, 0.55)
@export var injury_color := Color(0.75, 0.16, 0.12)
@export var idle_alpha := 0.55

var stamina := 100.0
var max_stamina := 100.0
var stiff_part := 0.0      # 굳음이 깎은 양 (스태미나 단위)
var injury := 0.0
var winded := false
var bandages := 0
var items_text := ""       # "랜턴 2 · 케미라이트 5 · 붕대 1 · 열쇠"
@export var items_font_size := 14
var bandage_k := 0.0       # 붕대 감는 진행 0~1
var _t := 0.0
var _last_items := ""
var _items_t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(dt: float) -> void:
	_t += dt
	var busy := stamina < max_stamina - 0.5 or stiff_part > 0.5 or injury > 0.5 or bandage_k > 0.0 or items_text != _last_items
	if items_text != _last_items:
		_items_t = 3.0   # 수량이 바뀌면 잠깐 또렷하게
		_last_items = items_text
	_items_t = maxf(0.0, _items_t - dt)
	busy = busy or _items_t > 0.0
	modulate.a = move_toward(modulate.a, 1.0 if busy else idle_alpha, dt * (4.0 if busy else 0.8))
	queue_redraw()

func _draw() -> void:
	var w := bar_size.x
	var h := bar_size.y
	var u := w / 100.0
	draw_rect(Rect2(-2, -2, w + 4, h + 4), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.06))
	# 오른쪽 끝부터: 부상, 그 왼쪽에 굳음
	var inj_w := clampf(injury, 0.0, 100.0) * u
	var stone_w := clampf(stiff_part, 0.0, 100.0 - injury) * u
	if inj_w > 0.0:
		draw_rect(Rect2(w - inj_w, 0, inj_w, h), injury_color)
	if stone_w > 0.0:
		var x0 := w - inj_w - stone_w
		draw_rect(Rect2(x0, 0, stone_w, h), stone_color)
		var x := x0 - h
		while x < x0 + stone_w:   # 돌 느낌의 빗금
			var a := Vector2(maxf(x, x0), h - maxf(0.0, x0 - x))
			var b := Vector2(minf(x + h, x0 + stone_w), maxf(0.0, x + h - (x0 + stone_w)))
			draw_line(a, b, Color(0.32, 0.33, 0.35), 1.5)
			x += 7.0
	# 스태미나
	var col := fill_color
	if winded:
		col = winded_color.lerp(fill_color, 0.5 + 0.5 * sin(_t * 9.0))
	draw_rect(Rect2(0, 0, clampf(stamina, 0.0, 100.0) * u, h), col)
	draw_rect(Rect2(0, 0, w, h), Color(0.95, 0.92, 0.85, 0.5), false, 1.0)
	# 붕대 감는 중
	if bandage_k > 0.0:
		draw_rect(Rect2(0, -9, w * bandage_k, 4), Color(1, 1, 1, 0.9))
	# 소지품: 막대 위에 작은 글씨로 늘 보인다 (11/18 회의. 개발용 F1 표시를 줄여서 상시로)
	if items_text != "":
		var f := get_theme_default_font()
		draw_string(f, Vector2(0, -8 - (6 if bandage_k > 0.0 else 0)), items_text, HORIZONTAL_ALIGNMENT_LEFT, -1, items_font_size, Color(0.92, 0.9, 0.82, 0.85))
