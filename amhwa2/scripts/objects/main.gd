extends Node3D
## 게임 시작·재시작만 담당. 실제 내용은 자식 씬(Level, Player, HUD)에 있다.

func _enter_tree() -> void:
	GameState.reset()
	var args := OS.get_cmdline_user_args()
	if ("selftest" in args or "shot" in args) and not "intro" in args:
		GameState.intro_seen = true   # 자동 점검·스크린샷에서는 시작 연출 건너뜀

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("restart"):
		get_tree().reload_current_scene()

func _ready() -> void:
	if "selftest" in OS.get_cmdline_user_args():
		var t := Node.new()
		t.set_script(load("res://scripts/tests/selftest.gd"))
		add_child(t)
	if "shot" in OS.get_cmdline_user_args():
		var t2 := Node.new()
		t2.set_script(load("res://scripts/tests/shot.gd"))
		add_child(t2)
