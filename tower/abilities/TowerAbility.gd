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


## 统一伤害入口：通过 CombatService 处理伤害计算、效果施加、统计
func deal_damage(enemy: Area2D, dmg: float, effects: Array, pierce_giant: bool = false) -> void:
	if not is_instance_valid(enemy):
		return
	CombatService.deal_damage(
		{
			"source_tower": tower,
			"armor_penetration": tower.armor_penetration if tower else 0,
			"pierce_giant": pierce_giant,
			"ignore_dodge": false,
		},
		enemy, dmg, effects
	)
