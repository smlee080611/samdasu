extends Control
## 화면 왼쪽 아래 작은 상태 표시: 헤드램프 배터리, 들고 있는 랜턴, (Tab일 때) 구출·차광막.
## 평소에는 숨어 있고 hud.gd가 alpha를 올릴 때만 보인다.

var battery := 100.0
var lamp_on := true
var lanterns := 2
var lanterns_max := 2
var show_counts := false
var counts_text := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	var ink := Color(0.92, 0.9, 0.84)
	var low := battery < 20.0
	# 배터리
	var b := Rect2(0, 8, 46, 20)
	draw_rect(b, ink, false, 2.0)
	draw_rect(Rect2(47, 13, 4, 10), ink)
	var fill_col := Color(0.9, 0.3, 0.2) if low else ink
	if not lamp_on:
		fill_col = Color(ink, 0.35)
	draw_rect(Rect2(3, 11, 40.0 * battery / 100.0, 14), fill_col)
	# 랜턴: 들고 있으면 채움, 놓아둔 것은 테두리만
	for i in lanterns_max:
		var x := 70.0 + i * 26.0
		var held := i < lanterns
		var body := Rect2(x, 10, 14, 18)
		if held:
			draw_rect(body, Color(1.0, 0.75, 0.35))
		draw_rect(body, ink, false, 2.0)
		draw_arc(Vector2(x + 7, 10), 6, PI, TAU, 10, ink, 2.0)
	if show_counts:
		var font := get_theme_default_font()
		draw_string(font, Vector2(0, 58), counts_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
