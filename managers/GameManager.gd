extends Node

## HP 变化时发出（HUD 监听此信号更新显示）
signal hp_changed(new_hp: int)
## 战斗金币变化时发出
signal gold_changed(new_gold: int)

## 游戏结束后可带出的金币上限
const MAX_CARRY_OUT_GOLD: int = 2000

@export var player_life: int = 100

## 初始战斗金币（可在编辑器各场景节点中覆盖，如教学关设为 500）
@export var start_gold: int = 600

var gold: int = 600

## 地鼠地洞节点列表（所有地鼠共享，波次结束时清空）
var burrow_holes: Array = []

func clear_burrow_holes() -> void:
	for hole in burrow_holes:
		if is_instance_valid(hole):
			hole.queue_free()
	burrow_holes.clear()

## 地图测试模式：非空时 BattleScene 从此路径加载 JSON 自定义地图，用完即清空
var custom_map_path: String = ""

## 地图测试模式标志：true 时 BattleScene 解锁全部炮台并允许刷敌人
var test_mode: bool = false

## 当前关卡编号（Day 1 ~ Day 15）
var current_day: int = 1

## 挑战模式：true 时禁用兵工厂的免费升级配额（所有升级须花金币）
var challenge_mode: bool = false

## 战局恢复标志：true 时 BattleScene 从 battle_save.json 恢复战局
var resume_battle: bool = false

func _ready() -> void:
	gold = start_gold

func damage_player(amount: int) -> void:
	if player_life <= 0:
		return  # 已经归零，忽略后续伤害（防止多敌人同帧重复触发结束逻辑）
	player_life = maxi(player_life - amount, 0)
	hp_changed.emit(player_life)
	if player_life <= 0:
		_on_game_over()

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

## 消费战斗金币；余额不足返回 false
func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

## 返回可带出的金币量（上限 MAX_CARRY_OUT_GOLD）
func get_carry_out_gold() -> int:
	return min(gold, MAX_CARRY_OUT_GOLD)

func _on_game_over() -> void:
	# 金币由各场景（BattleScene 等）在广告/复活流程结束后统一发放
	# 此处仅做 debug 日志，不直接操作 UserManager
	#print("游戏结束，带出金币:", get_carry_out_gold())
	pass

## 每帧敌人列表缓存（避免多塔重复扫描场景树）
var _enemy_cache: Array = []
var _enemy_cache_frame: int = -1

func get_all_enemies() -> Array:
	var f := Engine.get_process_frames()
	if f != _enemy_cache_frame:
		_enemy_cache = get_tree().get_nodes_in_group("enemy")
		_enemy_cache_frame = f
	return _enemy_cache
