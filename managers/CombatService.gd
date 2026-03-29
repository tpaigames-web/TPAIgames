extends Node

## 战斗伤害计算服务（Autoload）
## 统一伤害入口：闪避检查 → 标记加成 → 护甲减伤 → 扣血 → 施加效果


## 通用伤害入口
## source_info: {
##   "source_tower": Area2D or null,       # 伤害来源炮台
##   "armor_penetration": int,              # 护穿等级
##   "pierce_giant": bool,                  # 效果穿透巨型单位
##   "ignore_dodge": bool,                  # 无视闪避
## }
func deal_damage(source_info: Dictionary, target: Area2D,
		base_damage: float, effects: Array) -> void:
	if not is_instance_valid(target):
		return
	var ed = target.get("enemy_data")

	# 1. 闪避检查
	var ignore_dodge: bool = source_info.get("ignore_dodge", false)
	if not ignore_dodge and ed and randf() < ed.attack_immunity_chance:
		return

	# 2. 标记加成（从 EffectService 查询）
	var dmg_mult: float = 1.0 + EffectService.get_mark_bonus(target)
	var final_dmg: float = base_damage * dmg_mult

	# 3. 护甲减伤
	var armor_pen: int = source_info.get("armor_penetration", 0)
	if ed and ed.armor > 0:
		var effective_armor: int = maxi(ed.armor - armor_pen, 0)
		if effective_armor > 0:
			# 护甲减免表（与 Enemy.gd ARMOR_REDUCTION 一致）
			const ARMOR_REDUCTION: Array[float] = [0.0, 0.15, 0.30, 0.45, 0.60]
			var idx: int = mini(effective_armor, ARMOR_REDUCTION.size() - 1)
			var reduction: float = ARMOR_REDUCTION[idx]
			# 地形 + debuff 叠加减甲
			var terrain_ar: float = target.get("terrain_armor_reduction") if target.get("terrain_armor_reduction") else 0.0
			var debuff_ar: float = target.get("debuff_armor_reduction") if target.get("debuff_armor_reduction") else 0.0
			var total_ar: float = terrain_ar + debuff_ar
			if total_ar > 0.0:
				reduction = maxf(reduction - total_ar, 0.0)
			final_dmg *= (1.0 - reduction)

	# 4. 记录攻击前 HP（用于击杀判定）
	var was_alive: bool = target.hp > 0
	var source_tower = source_info.get("source_tower", null)

	# 5. 扣血（走 Enemy.take_damage 处理护盾、死亡等）
	target.take_damage(final_dmg)

	# 6. 施加子弹效果
	var pierce_giant: bool = source_info.get("pierce_giant", false)
	if effects.size() > 0:
		EffectService.apply_effects(target, effects, pierce_giant)

	# 7. 统计伤害/击杀
	if is_instance_valid(source_tower):
		source_tower.notify_damage(base_damage)
		if was_alive and (not is_instance_valid(target) or target.hp <= 0):
			source_tower.notify_kill()
