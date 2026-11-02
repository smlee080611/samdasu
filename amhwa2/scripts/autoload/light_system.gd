extends Node
## 모든 빛을 한곳에서 판정한다.
## 빛을 내는 노드는 "light_source" 그룹에 들어가고 light_value(target, exclude) 함수를 가진다.
## 새 종류의 빛(손전등, 촛불, 발전기 등)을 추가해도 이 파일은 고칠 필요가 없다.

const LIT_THRESHOLD := 0.2

## 해당 위치가 얼마나 밝은지 0~1. safety_only면 헤드램프처럼 "몸을 지켜주지 않는 빛"은 뺀다.
func light_at(pos: Vector3, exclude: Array[RID] = [], safety_only := false) -> float:
	var target := pos + Vector3(0, 1.0, 0)
	var best := 0.0
	var level = get_tree().get_first_node_in_group("level")
	if level and level.is_outdoor(level.to_tile(pos)):
		best = 0.75   # 야외: 달빛 아래는 늘 밝다 (몸도 풀림)
	for src in get_tree().get_nodes_in_group("light_source"):
		if src.get("neutral"):
			continue
		if safety_only and not src.get("protects_body"):
			continue
		best = max(best, src.light_value(target, exclude))
	return best

## 경광봉 같은 "변화 없음" 빛이 닿는가
func in_neutral(pos: Vector3, exclude: Array[RID] = []) -> bool:
	var target := pos + Vector3(0, 1.0, 0)
	for src in get_tree().get_nodes_in_group("light_source"):
		if src.get("neutral") and src.light_value(target, exclude) > 0.05:
			return true
	return false

func is_lit(pos: Vector3, exclude: Array[RID] = []) -> bool:
	return light_at(pos, exclude) > LIT_THRESHOLD

## from에서 to까지 벽이나 사람에 가리지 않았는지
func ray_clear(from: Vector3, to: Vector3, exclude: Array[RID]) -> bool:
	var world := get_tree().root.get_world_3d()
	var q := PhysicsRayQueryParameters3D.create(from, to, GameState.LAYER_WALL | GameState.LAYER_PERSON, exclude)
	return world.direct_space_state.intersect_ray(q).is_empty()
