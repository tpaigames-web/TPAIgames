class_name PathTile extends Area2D

## 路径瓷砖 — 放在地图中标记敌人路径区域
## 自动加入 "path" group，阻止玩家在路径上放塔
## 碰撞区域自动匹配瓷砖图片大小

func _ready() -> void:
	add_to_group("path")
	collision_layer = 1024   # 路径层（和 PathArea 一样）
	collision_mask  = 0      # 不检测任何东西
	z_index = -9             # 显示在背景(-10)上面，但在所有游戏对象下面
	z_as_relative = false    # 绝对 z_index，不受父节点影响
