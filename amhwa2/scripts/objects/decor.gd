extends Node3D
## 충돌이 필요 없는 장식(손잡이, 엘리베이터 문, 소화기). 부품 메시만 합친다.

func _ready() -> void:
	MeshMerge.merge(self)
