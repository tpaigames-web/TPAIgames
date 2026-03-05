extends Area2D

enum TargetMode { FIRST, CLOSEST, STRONGEST, LAST }

var enemies_in_range: Array = []

func _ready():
	monitoring = true
	monitorable = false
	connect("area_entered", _on_area_entered)
	connect("area_exited", _on_area_exited)

func _on_area_entered(area):
	if area.is_in_group("enemy"):
		enemies_in_range.append(area)
		# 敌人死亡时主动移除，避免 get_target() 每帧 filter
		area.tree_exiting.connect(func(): enemies_in_range.erase(area), CONNECT_ONE_SHOT)

func _on_area_exited(area):
	if area in enemies_in_range:
		enemies_in_range.erase(area)

func get_target(mode: int = TargetMode.FIRST) -> Area2D:
	if enemies_in_range.is_empty():
		return null
	match mode:
		TargetMode.FIRST:
			return enemies_in_range.reduce(func(a, b): return a if _prog(a) >= _prog(b) else b)
		TargetMode.CLOSEST:
			return enemies_in_range.reduce(func(a, b): return a if _dist(a) <= _dist(b) else b)
		TargetMode.STRONGEST:
			return enemies_in_range.reduce(func(a, b): return a if a.hp >= b.hp else b)
		TargetMode.LAST:
			return enemies_in_range.reduce(func(a, b): return a if _prog(a) <= _prog(b) else b)
	return enemies_in_range[0]

func _prog(e: Area2D) -> float:
	var p = e.get_parent()
	return p.progress_ratio if p is PathFollow2D else 0.0

func _dist(e: Area2D) -> float:
	return global_position.distance_to(e.global_position)
