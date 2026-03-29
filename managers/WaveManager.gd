extends Node

## 所有波次（含召唤子单位）全部消灭后发出，供外部场景连接胜利逻辑
signal all_waves_cleared
signal wave_started(wave_num: int)
signal wave_cleared(wave_num: int)   ## 当前波次所有敌人消灭后发出

@export var spawn_interval: float = 0.6

## 对应地图的 Path2D 路径（在编辑器中为每个场景单独配置）
@export var map_path_node: NodePath = NodePath("../TutorialMap/Path2D")

var current_wave: int = 0
var active_enemies: int = 0

## ── 难度缩放（按 Day 设置）─────────────────────────────────────────────
var hp_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var is_endless: bool = false
var endless_wave_offset: int = 0   ## 无限模式起始偏移（40）

## 根据关卡日数设置难度参数
func apply_day_difficulty(day: int) -> void:
	if day <= 3:
		hp_multiplier    = 1.0
		speed_multiplier = 1.0
		spawn_interval   = 0.7
	elif day <= 6:
		hp_multiplier    = 1.3
		speed_multiplier = 1.05
		spawn_interval   = 0.6
	elif day <= 9:
		hp_multiplier    = 1.6
		speed_multiplier = 1.1
		spawn_interval   = 0.55
	elif day <= 12:
		hp_multiplier    = 2.0
		speed_multiplier = 1.15
		spawn_interval   = 0.5
	else:
		hp_multiplier    = 2.5
		speed_multiplier = 1.2
		spawn_interval   = 0.45
	if spawn_timer:
		spawn_timer.wait_time = spawn_interval

## 波次完成奖励（按阶段：P1=+35, P2=+45, P3=+55, P4=+65）
const WAVE_PHASE_BONUS: Array[int] = [35, 45, 55, 65]

func _get_wave_bonus(wave_num: int) -> int:
	if wave_num <= 10: return WAVE_PHASE_BONUS[0]
	if wave_num <= 20: return WAVE_PHASE_BONUS[1]
	if wave_num <= 30: return WAVE_PHASE_BONUS[2]
	return WAVE_PHASE_BONUS[3]

## 波次名称（与 wave_data 一一对应）
var wave_names: Array[String] = [
	"热身·小鼠来袭", "肥鼠登场", "松鼠与蚁群", "地鼠偷袭",
	"★蛇群涌现", "毒蛙首现", "巨兔野猪蚁后", "潜地突击",
	"狐狸狂奔", "★精英合围",
	"乌鸦先锋", "蝗虫过境", "空地双线", "毒蛙蜂拥",
	"★铁翼重甲", "潜地空袭", "钢背犰狳首现", "暗影双线",
	"蚁后大军", "★乌鸦之王",
	"精英起势", "钢铁洪流", "毒免军团", "空中大军",
	"★全面攻势", "毒巢狂潮", "暗翼风暴", "铁血精英",
	"黑夜突袭", "★乌鸦王强化",
	"末日序幕", "召唤洪潮", "空中死神", "穿甲极限",
	"★巅峰军团", "怒潮席卷", "终极蚁群", "暗夜飞翼",
	"绝境守护", "★森林之王",
]

func get_wave_name(wave_num: int) -> String:
	var idx: int = wave_num - 1
	if idx >= 0 and idx < wave_names.size():
		return wave_names[idx]
	return ""

var wave_data = [
	# ── Phase 1：农场入侵（波 1-10，奖励+35）────────────────────────────
	# Wave 1 — 热身·小鼠来袭
	[{ "type": "rat_small", "count": 14 }],
	# Wave 2 — 肥鼠登场
	[{ "type": "rat_small", "count": 13 }, { "type": "rat_fat", "count": 4 }],
	# Wave 3 — 松鼠与蚁群
	[{ "type": "squirrel", "count": 6 }, { "type": "ant_swarm", "count": 20 }, { "type": "rat_small", "count": 6 }],
	# Wave 4 — 地鼠偷袭
	[{ "type": "mole", "count": 4 }, { "type": "squirrel", "count": 6 }, { "type": "ant_swarm", "count": 18 }],
	# Wave 5 — ★蛇群涌现（强化波）
	[{ "type": "snake", "count": 6 }, { "type": "mole", "count": 5 }, { "type": "rat_fat", "count": 5 }, { "type": "ant_swarm", "count": 12 }],
	# Wave 6 — 毒蛙首现
	[{ "type": "toad", "count": 4 }, { "type": "snake", "count": 5 }, { "type": "squirrel", "count": 8 }, { "type": "mole", "count": 4 }],
	# Wave 7 — 巨兔野猪蚁后
	[{ "type": "giant_rabbit", "count": 3 }, { "type": "boar", "count": 2 }, { "type": "snake", "count": 5 }, { "type": "ant_queen", "count": 1 }, { "type": "ant_swarm", "count": 8 }],
	# Wave 8 — 潜地突击
	[{ "type": "mole", "count": 6 }, { "type": "giant_mole", "count": 2 }, { "type": "giant_rabbit", "count": 3 }, { "type": "rat_fat", "count": 4 }, { "type": "squirrel", "count": 4 }],
	# Wave 9 — 狐狸狂奔
	[{ "type": "fox_leader", "count": 4 }, { "type": "boar", "count": 3 }, { "type": "ant_queen", "count": 2 }, { "type": "giant_rabbit", "count": 3 }, { "type": "ant_swarm", "count": 6 }],
	# Wave 10 — ★精英合围（P1决战+强化波）
	[{ "type": "armored_boar", "count": 4 }, { "type": "giant_mole", "count": 3 }, { "type": "fox_leader", "count": 3 }, { "type": "ant_queen", "count": 2 }, { "type": "snake", "count": 4 }],
	# ── Phase 2：空中威胁（波 11-20，奖励+45）───────────────────────────
	# Wave 11 — 乌鸦先锋
	[{ "type": "crow", "count": 12 }, { "type": "snake", "count": 6 }, { "type": "mole", "count": 4 }],
	# Wave 12 — 蝗虫过境
	[{ "type": "locust", "count": 20 }, { "type": "crow", "count": 8 }, { "type": "squirrel", "count": 8 }],
	# Wave 13 — 空地双线
	[{ "type": "crow", "count": 14 }, { "type": "locust", "count": 10 }, { "type": "armored_boar", "count": 2 }, { "type": "giant_mole", "count": 2 }],
	# Wave 14 — 毒蛙蜂拥
	[{ "type": "toad", "count": 6 }, { "type": "mole", "count": 5 }, { "type": "crow", "count": 12 }, { "type": "locust", "count": 8 }],
	# Wave 15 — ★铁翼重甲（强化波）
	[{ "type": "armored_boar", "count": 4 }, { "type": "crow", "count": 16 }, { "type": "locust", "count": 12 }, { "type": "ant_queen", "count": 2 }],
	# Wave 16 — 潜地空袭
	[{ "type": "giant_mole", "count": 4 }, { "type": "crow", "count": 14 }, { "type": "locust", "count": 8 }, { "type": "fox_leader", "count": 3 }],
	# Wave 17 — 钢背犰狳首现
	[{ "type": "armadillo", "count": 2 }, { "type": "armored_boar", "count": 3 }, { "type": "crow", "count": 14 }, { "type": "toad", "count": 4 }],
	# Wave 18 — 暗影双线
	[{ "type": "fox_leader", "count": 5 }, { "type": "armored_boar", "count": 4 }, { "type": "giant_mole", "count": 3 }, { "type": "crow", "count": 12 }],
	# Wave 19 — 蚁后大军
	[{ "type": "ant_queen", "count": 4 }, { "type": "armadillo", "count": 1 }, { "type": "armored_boar", "count": 3 }, { "type": "crow", "count": 10 }, { "type": "locust", "count": 8 }],
	# Wave 20 — ★乌鸦之王（P2 BOSS）
	[{ "type": "crow_king", "count": 1 }, { "type": "armored_boar", "count": 4 }, { "type": "giant_mole", "count": 4 }, { "type": "crow", "count": 12 }],
	# ── Phase 3：精英强袭（波 21-30，奖励+55）───────────────────────────
	# Wave 21 — 精英起势
	[{ "type": "armored_boar", "count": 5 }, { "type": "giant_mole", "count": 4 }, { "type": "fox_leader", "count": 4 }, { "type": "crow", "count": 10 }],
	# Wave 22 — 钢铁洪流
	[{ "type": "armored_boar", "count": 6 }, { "type": "armadillo", "count": 2 }, { "type": "giant_mole", "count": 4 }, { "type": "crow_king", "count": 1 }],
	# Wave 23 — 毒免军团
	[{ "type": "toad", "count": 8 }, { "type": "armadillo", "count": 2 }, { "type": "armored_boar", "count": 4 }, { "type": "locust", "count": 12 }],
	# Wave 24 — 空中大军
	[{ "type": "crow_king", "count": 2 }, { "type": "crow", "count": 15 }, { "type": "locust", "count": 15 }, { "type": "armored_boar", "count": 4 }, { "type": "ant_queen", "count": 2 }],
	# Wave 25 — ★全面攻势（强化波）
	[{ "type": "armored_boar", "count": 6 }, { "type": "giant_mole", "count": 5 }, { "type": "fox_leader", "count": 4 }, { "type": "crow_king", "count": 1 }, { "type": "armadillo", "count": 1 }],
	# Wave 26 — 毒巢狂潮
	[{ "type": "ant_queen", "count": 5 }, { "type": "giant_mole", "count": 5 }, { "type": "armored_boar", "count": 4 }, { "type": "fox_leader", "count": 3 }],
	# Wave 27 — 暗翼风暴
	[{ "type": "crow_king", "count": 3 }, { "type": "crow", "count": 15 }, { "type": "locust", "count": 18 }, { "type": "giant_mole", "count": 4 }],
	# Wave 28 — 铁血精英
	[{ "type": "armored_boar", "count": 6 }, { "type": "armadillo", "count": 3 }, { "type": "fox_leader", "count": 5 }, { "type": "crow", "count": 10 }],
	# Wave 29 — 黑夜突袭
	[{ "type": "crow_king", "count": 2 }, { "type": "armored_boar", "count": 6 }, { "type": "giant_mole", "count": 5 }, { "type": "ant_queen", "count": 3 }],
	# Wave 30 — ★乌鸦王强化（P3 BOSS）
	[{ "type": "crow_king", "count": 3 }, { "type": "armored_boar", "count": 5 }, { "type": "giant_mole", "count": 5 }, { "type": "fox_leader", "count": 4 }],
	# ── Phase 4：最终决战（波 31-40，奖励+65）───────────────────────────
	# Wave 31 — 末日序幕
	[{ "type": "armored_boar", "count": 8 }, { "type": "fox_leader", "count": 5 }, { "type": "giant_mole", "count": 4 }, { "type": "armadillo", "count": 2 }],
	# Wave 32 — 召唤洪潮
	[{ "type": "ant_queen", "count": 5 }, { "type": "armored_boar", "count": 7 }, { "type": "giant_mole", "count": 5 }, { "type": "crow", "count": 8 }],
	# Wave 33 — 空中死神
	[{ "type": "crow_king", "count": 4 }, { "type": "crow", "count": 18 }, { "type": "locust", "count": 20 }, { "type": "armored_boar", "count": 4 }, { "type": "armadillo", "count": 2 }],
	# Wave 34 — 穿甲极限
	[{ "type": "armadillo", "count": 4 }, { "type": "armored_boar", "count": 8 }, { "type": "giant_mole", "count": 6 }, { "type": "crow_king", "count": 1 }],
	# Wave 35 — ★巅峰军团（强化波）
	[{ "type": "armored_boar", "count": 7 }, { "type": "giant_mole", "count": 6 }, { "type": "fox_leader", "count": 6 }, { "type": "ant_queen", "count": 3 }, { "type": "crow_king", "count": 1 }],
	# Wave 36 — 怒潮席卷
	[{ "type": "crow_king", "count": 4 }, { "type": "armored_boar", "count": 7 }, { "type": "giant_mole", "count": 6 }, { "type": "fox_leader", "count": 4 }],
	# Wave 37 — 终极蚁群
	[{ "type": "ant_queen", "count": 6 }, { "type": "armored_boar", "count": 7 }, { "type": "giant_mole", "count": 6 }, { "type": "crow_king", "count": 2 }],
	# Wave 38 — 暗夜飞翼
	[{ "type": "crow_king", "count": 5 }, { "type": "crow", "count": 18 }, { "type": "armored_boar", "count": 7 }, { "type": "fox_leader", "count": 4 }],
	# Wave 39 — 绝境守护
	[{ "type": "armadillo", "count": 3 }, { "type": "armored_boar", "count": 8 }, { "type": "giant_mole", "count": 7 }, { "type": "fox_leader", "count": 5 }, { "type": "crow_king", "count": 2 }],
	# Wave 40 — ★森林之王（最终BOSS）
	[{ "type": "forest_king", "count": 1 }, { "type": "giant_mole", "count": 5 }, { "type": "armored_boar", "count": 4 }, { "type": "fox_leader", "count": 4 }, { "type": "ant_queen", "count": 2 }, { "type": "crow_king", "count": 1 }],
]

## 教学关专用 10 波数据（仅 rat_small/rat_fat/squirrel/crow/boar/armored_boar）
var tutorial_wave_data = [
	# Wave 1 — 小老鼠热身
	[{ "type": "rat_small", "count": 8 }],
	# Wave 2 — 乌鸦（飞行教学）
	[{ "type": "crow", "count": 6 }],
	# Wave 3 — 胖老鼠登场
	[{ "type": "rat_small", "count": 6 }, { "type": "rat_fat", "count": 4 }],
	# Wave 4 — 松鼠加入
	[{ "type": "rat_small", "count": 5 }, { "type": "squirrel", "count": 5 }],
	# Wave 5 — 混合波
	[{ "type": "rat_fat", "count": 6 }, { "type": "squirrel", "count": 4 }, { "type": "crow", "count": 4 }],
	# Wave 6
	[{ "type": "rat_small", "count": 8 }, { "type": "rat_fat", "count": 5 }, { "type": "crow", "count": 3 }],
	# Wave 7
	[{ "type": "squirrel", "count": 6 }, { "type": "rat_fat", "count": 6 }, { "type": "crow", "count": 4 }],
	# Wave 8 — 野猪登场
	[{ "type": "rat_small", "count": 5 }, { "type": "boar", "count": 3 }, { "type": "crow", "count": 5 }],
	# Wave 9
	[{ "type": "rat_fat", "count": 6 }, { "type": "squirrel", "count": 5 }, { "type": "boar", "count": 3 }, { "type": "crow", "count": 4 }],
	# Wave 10 — 装甲野猪 BOSS
	[{ "type": "rat_small", "count": 5 }, { "type": "rat_fat", "count": 5 }, { "type": "squirrel", "count": 4 }, { "type": "boar", "count": 2 }, { "type": "armored_boar", "count": 1 }],
]

## 切换到教学波次数据
func use_tutorial_waves() -> void:
	wave_data = tutorial_wave_data

# 所有敌人类型共用同一个 Enemy.tscn，数据由 enemy_data_map 区分
const ENEMY_SCENE: PackedScene = preload("res://enemy/Enemy.tscn")

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
	"toad":         preload("res://data/enemies/toad.tres"),
	"armadillo":    preload("res://data/enemies/armadillo.tres"),
}

var spawn_queue: Array = []
var spawn_timer: Timer


func _ready():
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer)
	add_child(spawn_timer)
	# 不自动开始，等待 BattleScene 调用 start()

## 由 BattleScene 在玩家点击播放按钮后调用
func start() -> void:
	start_next_wave()

## 从指定波次开始（用于战局存档恢复）
func start_from(wave_num: int) -> void:
	current_wave = wave_num - 1   # start_next_wave() 内部会 +1
	start_next_wave()


func start_next_wave():

	if not is_endless and current_wave >= wave_data.size():
		#print("全部波次完成")
		all_waves_cleared.emit()
		return

	current_wave += 1
	#print("开始 Wave ", current_wave)
	wave_started.emit(current_wave)

	spawn_queue.clear()

	var groups: Array = []
	if is_endless and current_wave > endless_wave_offset:
		# 无限模式：动态生成
		groups = _generate_endless_wave(current_wave)
	elif current_wave >= 1 and current_wave <= wave_data.size():
		groups = wave_data[current_wave - 1]
	else:
		push_error("WaveManager: current_wave %d 越界（wave_data.size=%d）" % [current_wave, wave_data.size()])
		return

	for group in groups:
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

	if not enemy_data_map.has(enemy_type):
		push_warning("未找到敌人类型: " + str(enemy_type))
		return

	var path_node: Node = get_node_or_null(map_path_node)
	if path_node == null:
		push_error("WaveManager: 找不到 Path2D，路径: " + str(map_path_node))
		return

	var path_follow = PathFollow2D.new()
	path_follow.loop = false   # 禁止循环，走到终点停在 progress_ratio=1.0
	path_node.add_child(path_follow)
	path_follow.progress = 0

	var enemy = ENEMY_SCENE.instantiate()
	enemy.enemy_data = enemy_data_map.get(enemy_type, enemy_data_map["rat_small"])
	enemy.apply_enemy_data()
	# 难度缩放：HP 和速度
	_apply_difficulty_scaling(enemy)

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

		var enemy = ENEMY_SCENE.instantiate()
		enemy.enemy_data = enemy_data_map.get(etype, enemy_data_map["rat_small"])
		enemy.apply_enemy_data()
		enemy.is_summoned = true   # 召唤单位不掉金币
		_apply_difficulty_scaling(enemy)

		if enemy.has_signal("want_spawn"):
			enemy.want_spawn.connect(_on_enemy_want_spawn)

		path_follow.add_child(enemy)

		active_enemies += 1
		enemy.tree_exited.connect(_on_enemy_dead)


func _on_enemy_dead():
	active_enemies -= 1
	if active_enemies < 0:
		push_warning("WaveManager: active_enemies 变为负数，已夹零（可能有重复的 tree_exited 信号）")
		active_enemies = 0
		return
	if active_enemies == 0 and spawn_queue.is_empty():
		GameManager.add_gold(_get_wave_bonus(current_wave))
		wave_cleared.emit(current_wave)
		start_next_wave()

## 难度缩放：修改敌人实例的 HP 和速度
func _apply_difficulty_scaling(enemy: Node) -> void:
	var mult := hp_multiplier
	var spd_mult := speed_multiplier
	# 无限模式额外缩放：每 5 波 HP ×1.3
	if is_endless and current_wave > endless_wave_offset:
		var extra_waves: int = current_wave - endless_wave_offset
		var extra_mult: float = pow(1.3, float(extra_waves) / 5.0)
		mult *= extra_mult
		spd_mult *= minf(1.0 + float(extra_waves) * 0.01, 1.5)   # 速度上限 1.5×
	enemy.hp    = int(float(enemy.hp) * mult)
	enemy.speed = enemy.speed * spd_mult

## ── 无限模式 ─────────────────────────────────────────────────────────

## 进入无限模式（从第 41 波开始）
func enter_endless() -> void:
	is_endless = true
	endless_wave_offset = current_wave
	start_next_wave()

## 无限模式动态生成波次数据
func _generate_endless_wave(wave_num: int) -> Array:
	var extra: int = wave_num - endless_wave_offset
	var base_count: int = 10 + extra * 2   # 每波多 2 个敌人

	# 敌人池随波次扩大
	var pool: Array[String] = ["rat_small", "rat_fat", "squirrel", "mole", "snake"]
	if extra >= 3:
		pool.append_array(["crow", "boar", "giant_rabbit"])
	if extra >= 6:
		pool.append_array(["locust", "ant_queen", "fox_leader"])
	if extra >= 10:
		pool.append_array(["armored_boar", "giant_mole", "crow_king"])

	var groups: Array = []
	# 随机分配敌人
	var type_counts: Dictionary = {}
	for _i in base_count:
		var t: String = pool[randi() % pool.size()]
		type_counts[t] = type_counts.get(t, 0) + 1
	for t in type_counts:
		groups.append({"type": t, "count": type_counts[t]})

	# 每 10 波加 boss
	if extra % 10 == 0 and extra > 0:
		groups.append({"type": "crow_king", "count": 1 + extra / 20})
	# 每 20 波加森林之王
	if extra % 20 == 0 and extra > 0:
		groups.append({"type": "forest_king", "count": 1})

	return groups
