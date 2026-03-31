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

## ── 外部加载的波次数据 ────────────────────────────────────────────────
const WAVE_DIR := "res://data/waves/"
const TUTORIAL_WAVE_DIR := "res://data/waves/tutorial/"
const DIFFICULTY_DIR := "res://data/difficulty/"

var _wave_configs: Array[WaveConfig] = []
var _tutorial_configs: Array[WaveConfig] = []
var _difficulty_tiers: Array[DifficultyTier] = []
var _using_tutorial: bool = false

## 根据关卡日数设置难度参数（从外部 DifficultyTier 资源加载）
func apply_day_difficulty(day: int) -> void:
	if _difficulty_tiers.is_empty():
		_load_difficulty_tiers()
	for tier in _difficulty_tiers:
		if day >= tier.day_min and day <= tier.day_max:
			hp_multiplier    = tier.hp_multiplier
			speed_multiplier = tier.speed_multiplier
			spawn_interval   = tier.spawn_interval
			break
	if spawn_timer:
		spawn_timer.wait_time = spawn_interval

## 波次完成奖励（按阶段：P1=+35, P2=+45, P3=+55, P4=+65）
const WAVE_PHASE_BONUS: Array[int] = [40, 50, 60, 75]

func _get_wave_bonus(wave_num: int) -> int:
	if wave_num <= 10: return WAVE_PHASE_BONUS[0]
	if wave_num <= 20: return WAVE_PHASE_BONUS[1]
	if wave_num <= 30: return WAVE_PHASE_BONUS[2]
	return WAVE_PHASE_BONUS[3]

## 获取波次名称
func get_wave_name(wave_num: int) -> String:
	var configs := _get_active_configs()
	var idx: int = wave_num - 1
	if idx >= 0 and idx < configs.size():
		return configs[idx].wave_name
	return ""

## 获取总波次数
func get_total_waves() -> int:
	return _get_active_configs().size()

## 切换到教学波次数据
func use_tutorial_waves() -> void:
	_using_tutorial = true
	if _tutorial_configs.is_empty():
		_load_wave_configs(TUTORIAL_WAVE_DIR, _tutorial_configs)

## 返回当前使用的波次配置列表
func _get_active_configs() -> Array[WaveConfig]:
	if _using_tutorial:
		return _tutorial_configs
	return _wave_configs

# 所有敌人类型共用同一个 Enemy.tscn，数据由 enemy_data_map 区分
const ENEMY_SCENE: PackedScene = preload("res://enemy/Enemy.tscn")

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
	"treasure_runner": preload("res://data/enemies/treasure_runner.tres"),
}

## 宝箱敌人出现控制
signal treasure_enemy_spawned(enemy: Node)  ## BattleScene 连接此信号处理掉落
var _games_since_treasure: int = 0  ## 距离上次出现宝箱敌人的局数
const TREASURE_MIN_GAMES: int = 3   ## 最少间隔局数
const TREASURE_MAX_GAMES: int = 5   ## 最多间隔局数
var _treasure_wave_target: int = -1 ## 本局在哪波插入宝箱敌人（-1=本局不出现）

var spawn_queue: Array = []
var spawn_timer: Timer


func _ready():
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer)
	add_child(spawn_timer)
	# 预加载主线波次
	_load_wave_configs(WAVE_DIR, _wave_configs)

## 决定本局是否出现宝箱敌人（在 start 前调用）
func _decide_treasure_spawn() -> void:
	_games_since_treasure += 1
	if _games_since_treasure >= TREASURE_MIN_GAMES:
		# 达到最小间隔后按概率出现（间隔越长概率越高）
		var chance: float = float(_games_since_treasure - TREASURE_MIN_GAMES + 1) / float(TREASURE_MAX_GAMES - TREASURE_MIN_GAMES + 1)
		if randf() < chance or _games_since_treasure >= TREASURE_MAX_GAMES:
			# 随机选一个中间波次（避免第 1 波和最后 5 波）
			var total: int = get_total_waves()
			var min_wave: int = maxi(3, total / 4)
			var max_wave: int = maxi(min_wave + 1, total - 5)
			_treasure_wave_target = randi_range(min_wave, max_wave)
			_games_since_treasure = 0


## 由 BattleScene 在玩家点击播放按钮后调用
func start() -> void:
	_decide_treasure_spawn()
	start_next_wave()

## 从指定波次开始（用于战局存档恢复）
func start_from(wave_num: int) -> void:
	current_wave = wave_num - 1   # start_next_wave() 内部会 +1
	start_next_wave()


func start_next_wave():
	var configs := _get_active_configs()

	if not is_endless and current_wave >= configs.size():
		all_waves_cleared.emit()
		return

	current_wave += 1
	wave_started.emit(current_wave)

	spawn_queue.clear()

	var groups: Array = []
	if is_endless and current_wave > endless_wave_offset:
		groups = _generate_endless_wave(current_wave)
	elif current_wave >= 1 and current_wave <= configs.size():
		groups = configs[current_wave - 1].groups
	else:
		push_error("WaveManager: current_wave %d 越界（configs.size=%d）" % [current_wave, configs.size()])
		return

	for group in groups:
		for i in range(group["count"]):
			spawn_queue.append(group["type"])

	# 宝箱敌人：在目标波次的队列中间插入
	if _treasure_wave_target == current_wave:
		var insert_pos: int = spawn_queue.size() / 2
		spawn_queue.insert(insert_pos, "treasure_runner")
		_treasure_wave_target = -1  # 已使用

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
	path_follow.loop = false
	path_node.add_child(path_follow)
	path_follow.progress = 0

	var enemy = ENEMY_SCENE.instantiate()
	enemy.set("enemy_data", enemy_data_map.get(enemy_type, enemy_data_map["rat_small"]))
	enemy.call("apply_enemy_data")
	_apply_difficulty_scaling(enemy)

	if enemy.has_signal("want_spawn"):
		enemy.want_spawn.connect(_on_enemy_want_spawn)

	# 宝箱敌人：连接掉落信号
	if enemy.enemy_data and enemy.enemy_data.is_treasure_runner:
		treasure_enemy_spawned.emit(enemy)

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
		path_follow.loop = false
		path_node.add_child(path_follow)
		path_follow.progress = prog

		var enemy = ENEMY_SCENE.instantiate()
		enemy.set("enemy_data", enemy_data_map.get(etype, enemy_data_map["rat_small"]))
		enemy.call("apply_enemy_data")
		enemy.set("is_summoned", true)
		_apply_difficulty_scaling(enemy)

		if enemy.has_signal("want_spawn"):
			enemy.want_spawn.connect(_on_enemy_want_spawn)

		path_follow.add_child(enemy)

		# 召唤出生动画：从小缩放+透明 → 正常（类似死亡反转）
		enemy.scale = Vector2(0.3, 0.3)
		enemy.modulate = Color(1, 1, 1, 0)
		var spawn_tw := enemy.create_tween()
		spawn_tw.set_parallel(true)
		spawn_tw.tween_property(enemy, "scale", Vector2(1, 1), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		spawn_tw.tween_property(enemy, "modulate:a", 1.0, 0.2)

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
	if is_endless and current_wave > endless_wave_offset:
		var extra_waves: int = current_wave - endless_wave_offset
		var extra_mult: float = pow(1.3, float(extra_waves) / 5.0)
		mult *= extra_mult
		spd_mult *= minf(1.0 + float(extra_waves) * 0.01, 1.5)
	enemy.hp    = int(float(enemy.hp) * mult)
	enemy.speed = enemy.speed * spd_mult

## ── 无限模式 ─────────────────────────────────────────────────────────

func enter_endless() -> void:
	is_endless = true
	endless_wave_offset = current_wave
	start_next_wave()

func _generate_endless_wave(wave_num: int) -> Array:
	var extra: int = wave_num - endless_wave_offset
	var base_count: int = 10 + extra * 2

	var pool: Array[String] = ["rat_small", "rat_fat", "squirrel", "mole", "snake"]
	if extra >= 3:
		pool.append_array(["crow", "boar", "giant_rabbit"])
	if extra >= 6:
		pool.append_array(["locust", "ant_queen", "fox_leader"])
	if extra >= 10:
		pool.append_array(["armored_boar", "giant_mole", "crow_king"])

	var groups: Array = []
	var type_counts: Dictionary = {}
	for _i in base_count:
		var t: String = pool[randi() % pool.size()]
		type_counts[t] = type_counts.get(t, 0) + 1
	for t in type_counts:
		groups.append({"type": t, "count": type_counts[t]})

	if extra % 10 == 0 and extra > 0:
		groups.append({"type": "crow_king", "count": 1 + extra / 20})
	if extra % 20 == 0 and extra > 0:
		groups.append({"type": "forest_king", "count": 1})

	return groups

## ── 数据加载 ─────────────────────────────────────────────────────────

func _load_wave_configs(dir_path: String, target: Array[WaveConfig]) -> void:
	target.clear()
	# 先尝试目录扫描（编辑器中有效），失败则用硬编码列表（导出后 res:// 不可枚举）
	var files: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				files.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	# DirAccess 失败时（导出后 res:// 打包），使用硬编码列表
	if files.is_empty():
		var count: int = 40 if dir_path == WAVE_DIR else 10
		for i in range(1, count + 1):
			files.append("wave_%02d.tres" % i)
	files.sort()
	for fname in files:
		var res = load(dir_path + fname)
		if res is WaveConfig:
			target.append(res)
	if target.is_empty():
		push_warning("WaveManager: 目录 %s 中没有找到 WaveConfig 资源" % dir_path)

func _load_difficulty_tiers() -> void:
	_difficulty_tiers.clear()
	var files: Array[String] = []
	var dir := DirAccess.open(DIFFICULTY_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				files.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	# DirAccess 失败时用硬编码列表
	if files.is_empty():
		for i in range(1, 6):
			files.append("tier_%d.tres" % i)
	files.sort()
	for fname in files:
		var res = load(DIFFICULTY_DIR + fname)
		if res is DifficultyTier:
			_difficulty_tiers.append(res)
