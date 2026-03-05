extends Node

## HP 变化时发出（HUD 监听此信号更新显示）
signal hp_changed(new_hp: int)
## 战斗金币变化时发出
signal gold_changed(new_gold: int)

## 游戏结束后可带出的金币上限
const MAX_CARRY_OUT_GOLD: int = 2000

@export var player_life: int = 100

## 初始战斗金币（可在编辑器各场景节点中覆盖，如教学关设为 500）
@export var start_gold: int = 100

var gold: int = 100

func _ready() -> void:
	gold = start_gold

func damage_player(amount: int) -> void:
	player_life -= amount
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
	# 将战斗金币（上限2000）并入全局金币
	UserManager.add_gold(get_carry_out_gold())
	# 后续：弹出游戏结束 UI（失败/胜利面板）
	print("游戏结束，带出金币:", get_carry_out_gold())
