extends Area2D

## 路径终点触发区：敌人 Area2D 进入时调用 _reach_goal()
## 放置于路径末端附近，作为 progress_ratio 判断的可靠替代方案

func _ready() -> void:
	monitoring = true
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy") and area.has_method("_reach_goal"):
		area._reach_goal()
