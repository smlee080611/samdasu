extends Node3D
## 게임 시작·재시작만 담당. 실제 내용은 자식 씬(Level, Player, HUD)에 있다.

func _enter_tree() -> void:
	GameState.reset()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("restart"):
		get_tree().reload_current_scene()

func _ready() -> void:
	if "selftest" in OS.get_cmdline_user_args():
		var t := Node.new()
		t.set_script(load("res://scripts/tests/selftest.gd"))
		add_child(t)
