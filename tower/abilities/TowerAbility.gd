class_name TowerAbility extends Node

## 塔楼能力基类
## 每个具体的双向继承此类，由 Tower 在放置后自动加载。

## 自动赋值，由 Tower._attach_ability() 调用。
var tower: Area2D


## 攻击委托，返回 true 表示此能力已处理攻击（覆盖默认行为）
func do_attack(_target: Area2D, _damage: float, _td: TowerCollectionData) -> bool:
	return false


## 每帧调用，用于光环/持续/时间等自定义逻辑
func ability_process(_delta: float) -> void:
	pass


## 塔楼被放置时调用一次
func on_placed() -> void:
	pass


## 统一伤害入口：自动统计 damage / kill，并支持巨型穿透标记
func deal_damage(enemy: Area2D, dmg: float, effects: Array, pierce_giant: bool = false) -> void:
	if not is_instance_valid(enemy):
		return
	var was_alive: bool = enemy.hp > 0
	if enemy.has_method("take_damage_from_bullet"):
		enemy.take_damage_from_bullet(dmg, effects, pierce_giant, tower.armor_penetration if tower else 0)
	if is_instance_valid(tower):
		tower.notify_damage(dmg)
		if was_alive and not is_instance_valid(enemy):
			tower.notify_kill()
		elif was_alive and is_instance_valid(enemy) and enemy.hp <= 0:
			tower.notify_kill()
