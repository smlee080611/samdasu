extends Node
## 효과음. 어디서나 Sfx.play("click") 또는 Sfx.play_at("stone_crack", 위치)로 쓴다.
## 소리 파일은 res://sounds/ 에 있다. 파일을 같은 이름으로 바꿔 끼우면 그대로 적용된다.

var streams := {}

func _ready() -> void:
	for n in ["step_0", "step_1", "step_2", "stone_crack", "petrify", "mad_step_0", "mad_step_1",
			"grab", "door_open", "door_close", "curtain", "lantern", "click", "cured"]:
		streams[n] = load("res://sounds/%s.wav" % n)

## 3D 위치에서 나는 소리 (멀수록 작고, 좌우로 들림)
func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.unit_size = 4.0
	p.max_distance = 30.0
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()

## 내 몸에서 나는 소리 (위치 없음)
func play(sound: String, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
