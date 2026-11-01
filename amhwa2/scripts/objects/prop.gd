extends StaticBody3D
## 병원 소품(침대, 휠체어, 링거대, 칸막이, 카트) 공통.
## blocks_path를 켜면 그 칸은 광인·구출된 사람이 지나가지 못한다(길찾기에서 막힘).
## 소품은 벽 레이어라 빛을 가리고 그림자를 만든다.

@export var blocks_path := false

func _ready() -> void:
	if blocks_path:
		add_to_group("blocker")
	MeshMerge.merge(self)
