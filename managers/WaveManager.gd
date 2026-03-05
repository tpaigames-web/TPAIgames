extends Node

## 所有波次（含召唤子单位）全部消灭后发出，供外部场景连接胜利逻辑
signal all_waves_cleared

@export var spawn_interval: float = 0.6

## 对应地图的 Path2D 路径（在编辑器中为每个场景单独配置）
@export var map_path_node: NodePath = NodePath("../TutorialMap/Path2D")

var current_wave: int = 0
var active_enemies: int = 0

var wave_data = [
	# Wave 1 — 热身：小鼠 ≈60金
	[
		{ "type": "rat_small", "count": 12 }
	],
	# Wave 2 — 肥鼠登场 ≈90金
	[
		{ "type": "rat_small", "count": 10 },
		{ "type": "rat_fat",   "count": 5  }
	],
	# Wave 3 — 松鼠加入 ≈128金
	[
		{ "type": "rat_small", "count": 8 },
		{ "type": "rat_fat",   "count": 8 },
		{ "type": "squirrel",  "count": 4 }
	],
	# Wave 4 — 蚁群压阵 ≈136金
	[
		{ "type": "rat_fat",   "count": 10 },
		{ "type": "squirrel",  "count": 6  },
		{ "type": "ant_swarm", "count": 10 }
	],
	# Wave 5 — 野猪冲锋 ≈157金
	[
		{ "type": "rat_fat",   "count": 8 },
		{ "type": "squirrel",  "count": 6 },
		{ "type": "ant_swarm", "count": 8 },
		{ "type": "boar",      "count": 3 }
	],
	# Wave 6 — 地鼠 + 大兔子 ≈172金
	[
		{ "type": "ant_swarm",    "count": 10 },
		{ "type": "mole",         "count": 6  },
		{ "type": "boar",         "count": 4  },
		{ "type": "giant_rabbit", "count": 2  }
	],
	# Wave 7 — 蚁后召唤 + 蛇 ≈199金
	[
		{ "type": "boar",         "count": 5 },
		{ "type": "giant_rabbit", "count": 4 },
		{ "type": "snake",        "count": 5 },
		{ "type": "ant_queen",    "count": 2 }
	],
	# Wave 8 — 装甲野猪 + 巨型地鼠 ≈274金
	[
		{ "type": "armored_boar", "count": 5 },
		{ "type": "snake",        "count": 5 },
		{ "type": "giant_mole",   "count": 3 }
	],
	# Wave 9 — 狐狸首领 + 蚁后 ≈310金
	[
		{ "type": "armored_boar", "count": 4 },
		{ "type": "giant_mole",   "count": 4 },
		{ "type": "fox_leader",   "count": 3 },
		{ "type": "ant_queen",    "count": 2 }
	],
	# Wave 10 — Boss：森林之王（带护盾）≈278金
	[
		{ "type": "giant_mole",  "count": 4 },
		{ "type": "fox_leader",  "count": 3 },
		{ "type": "forest_king", "count": 1 }
	]
]

# 🔥 敌人场景字典（所有类型共用同一个 Enemy.tscn）
var enemy_scenes: Dictionary = {
	"rat_small":    preload("res://enemy/Enemy.tscn"),
	"rat_fat":      preload("res://enemy/Enemy.tscn"),
	"squirrel":     preload("res://enemy/Enemy.tscn"),
	"crow":         preload("res://enemy/Enemy.tscn"),
	"ant_swarm":    preload("res://enemy/Enemy.tscn"),
	"boar":         preload("res://enemy/Enemy.tscn"),
	"locust":       preload("res://enemy/Enemy.tscn"),
	"mole":         preload("res://enemy/Enemy.tscn"),
	"giant_rabbit": preload("res://enemy/Enemy.tscn"),
	"snake":        preload("res://enemy/Enemy.tscn"),
	"crow_king":    preload("res://enemy/Enemy.tscn"),
	"armored_boar": preload("res://enemy/Enemy.tscn"),
	"ant_queen":    preload("res://enemy/Enemy.tscn"),
	"giant_mole":   preload("res://enemy/Enemy.tscn"),
	"fox_leader":   preload("res://enemy/Enemy.tscn"),
	"forest_king":  preload("res://enemy/Enemy.tscn"),
}

# 🔥 敌人数据字典
var enemy_data_map: Dictionary = {
	"rat_small":    preload("res://data/enemies/rat_small.tres"),
	"rat_fat":      preload("res://data/enemies/rat_fat.tres"),
	"squirrel":     preload("res://data/enemies/squirrel.tres"),
	"crow":         preload("res://data/enemies/crow.tres"),
	"ant_swarm":    preload("res://data/enemies/ant_swarm.tres"),
	"boar":         preload("res://data/enemies/boar.tres"),
	"locust":       preload("res://data/enemies/locust.tres"),
	"mole":         preload("res://data/enemies/mole.tres"),
	"giant_rabbit": preload("res://data/enemies/giant_rabbit.tres"),
	"snake":        preload("res://data/enemies/snake.tres"),
	"crow_king":    preload("res://data/enemies/crow_king.tres"),
	"armored_boar": preload("res://data/enemies/armored_boar.tres"),
	"ant_queen":    preload("res://data/enemies/ant_queen.tres"),
	"giant_mole":   preload("res://data/enemies/giant_mole.tres"),
	"fox_leader":   preload("res://data/enemies/fox_leader.tres"),
	"forest_king":  preload("res://data/enemies/forest_king.tres"),
}

var spawn_queue: Array = []
var spawn_timer: Timer


func _ready():
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer)
	add_child(spawn_timer)

	start_next_wave()


func start_next_wave():

	if current_wave >= wave_data.size():
		print("全部波次完成")
		all_waves_cleared.emit()
		return

	current_wave += 1
	print("开始 Wave ", current_wave)

	spawn_queue.clear()

	for group in wave_data[current_wave - 1]:
		for i in range(group["count"]):
			spawn_queue.append(group["type"])

	spawn_timer.start()


func _on_spawn_timer():

	if spawn_queue.is_empty():
		spawn_timer.stop()
		return

	var enemy_type = spawn_queue.pop_front()
	spawn_enemy(enemy_type)


func spawn_enemy(enemy_type: String) -> void:

	if not enemy_scenes.has(enemy_type):
		print("未找到敌人类型: ", enemy_type)
		return

	var path_node: Node = get_node_or_null(map_path_node)
	if path_node == null:
		push_error("WaveManager: 找不到 Path2D，路径: " + str(map_path_node))
		return

	var path_follow = PathFollow2D.new()
	path_follow.loop = false   # 禁止循环，走到终点停在 progress_ratio=1.0
	path_node.add_child(path_follow)
	path_follow.progress = 0

	var enemy = enemy_scenes[enemy_type].instantiate()
	enemy.enemy_data = enemy_data_map.get(enemy_type, enemy_data_map["rat_small"])
	enemy.apply_enemy_data()

	# 连接召唤信号（用于蚁后、乌鸦王、森林之王等）
	if enemy.has_signal("want_spawn"):
		enemy.want_spawn.connect(_on_enemy_want_spawn)

	path_follow.add_child(enemy)

	active_enemies += 1
	enemy.tree_exited.connect(_on_enemy_dead)


## 处理敌人召唤的子单位
func _on_enemy_want_spawn(etype: String, count: int, prog: float) -> void:
	var path_node: Node = get_node_or_null(map_path_node)
	if path_node == null:
		return

	for i in count:
		var path_follow = PathFollow2D.new()
		path_follow.loop = false   # 禁止循环
		path_node.add_child(path_follow)
		path_follow.progress = prog

		var scene = enemy_scenes.get(etype, enemy_scenes["rat_small"])
		var enemy = scene.instantiate()
		enemy.enemy_data = enemy_data_map.get(etype, enemy_data_map["rat_small"])
		enemy.apply_enemy_data()

		if enemy.has_signal("want_spawn"):
			enemy.want_spawn.connect(_on_enemy_want_spawn)

		path_follow.add_child(enemy)

		active_enemies += 1
		enemy.tree_exited.connect(_on_enemy_dead)


func _on_enemy_dead():
	active_enemies -= 1

	if active_enemies <= 0 and spawn_queue.is_empty():
		start_next_wave()
