extends Node

## 战斗伤害计算服务（Autoload）
## 统一伤害入口：闪避检查 → 标记加成 → 护甲减伤 → 暴击 → 扣血 → 施加效果 → 伤害数字


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
	if not target.has_method("take_damage"):
		return
	var ed = target.get("enemy_data")

	# 1. 闪避检查
	var ignore_dodge: bool = source_info.get("ignore_dodge", false)
	if not ignore_dodge and ed and randf() < ed.attack_immunity_chance:
		return

	# 2. 标记加成（从 EffectService 查询）
	var mark_bonus: float = EffectService.get_mark_bonus(target)
	var dmg_mult: float = 1.0 + mark_bonus
	var final_dmg: float = base_damage * dmg_mult
	var has_mark: bool = mark_bonus > 0.001

	# 3. 护甲减伤
	var armor_pen: int = source_info.get("armor_penetration", 0)
	var has_armor_pen: bool = false
	if ed and ed.armor > 0:
		var effective_armor: int = maxi(ed.armor - armor_pen, 0)
		# 检查护穿是否生效（直接穿甲 或 完全忽略护甲）
		if armor_pen > 0:
			has_armor_pen = true
		if effective_armor > 0:
			const ARMOR_REDUCTION: Array[float] = [0.0, 0.15, 0.30, 0.45, 0.60]
			var idx: int = mini(effective_armor, ARMOR_REDUCTION.size() - 1)
			var reduction: float = ARMOR_REDUCTION[idx]
			# 地形/debuff 洗甲（也算破甲效果）
			var terrain_ar: float = target.get("terrain_armor_reduction") if target.get("terrain_armor_reduction") else 0.0
			var debuff_ar: float = target.get("debuff_armor_reduction") if target.get("debuff_armor_reduction") else 0.0
			var total_ar: float = terrain_ar + debuff_ar
			if total_ar > 0.001:
				has_armor_pen = true  # 洗甲也显示破甲标记
				reduction = maxf(reduction - total_ar, 0.0)
			final_dmg *= (1.0 - reduction)

	# 4. 暴击检查
	var source_tower = source_info.get("source_tower", null)
	var is_crit: bool = false
	if is_instance_valid(source_tower):
		var crit_val = source_tower.get("global_crit_bonus")
		var crit_chance: float = float(crit_val) if crit_val != null else 0.0
		if crit_chance > 0.0 and randf() < crit_chance:
			final_dmg *= 2.0
			is_crit = true

	# 5. 记录攻击前 HP（用于击杀判定）
	var was_alive: bool = target.hp > 0

	# 6. 显示伤害数字
	if SettingsManager.damage_numbers and is_instance_valid(target):
		var color := Color.WHITE
		var prefix := ""
		var font_size: int = 24

		# 颜色优先级：暴击 > 标记 > 破甲 > 普通
		if is_crit:
			color = Color(1.0, 0.9, 0.1)  # 黄色
			prefix += "★"
			font_size = 36
		elif has_mark:
			color = Color(0.75, 0.3, 0.9)  # 紫色

		if has_armor_pen:
			prefix += "⚔"

		# 大伤害加大字体
		if ed and ed.max_hp > 0 and final_dmg > ed.max_hp * 0.1:
			font_size = maxi(font_size, 32)

		_show_damage_number(target, int(final_dmg), color, prefix, font_size)

	# 7. 扣血（走 Enemy.take_damage 处理护盾、死亡等）
	target.take_damage(final_dmg)

	# 8. 施加子弹效果
	var pierce_giant: bool = source_info.get("pierce_giant", false)
	if effects.size() > 0:
		EffectService.apply_effects(target, effects, pierce_giant)

	# 9. 统计伤害/击杀
	if is_instance_valid(source_tower):
		source_tower.notify_damage(base_damage)
		if was_alive and (not is_instance_valid(target) or target.hp <= 0):
			source_tower.notify_kill()


## ── 伤害数字显示 ────────────────────────────────────────────────────────

func _show_damage_number(target: Area2D, dmg: int, color: Color,
		prefix: String = "", font_size: int = 24) -> void:
	if dmg <= 0:
		return
	var lbl := Label.new()
	lbl.text = "%s%d" % [prefix, dmg] if prefix != "" else str(dmg)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 100

	var scene := get_tree().current_scene
	if scene == null:
		lbl.queue_free()
		return
	scene.add_child(lbl)

	# 随机水平偏移避免重叠
	var offset_x: float = randf_range(-20.0, 20.0)
	lbl.global_position = target.global_position + Vector2(offset_x - 30, -50)

	# 上浮 + 淡出动画
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 60, 0.8).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tw.tween_callback(lbl.queue_free)


## 供 EffectService 调用的 DoT 伤害数字显示
func show_dot_damage_number(target: Area2D, dmg: int, effect_type: int) -> void:
	if not SettingsManager.damage_numbers:
		return
	if not is_instance_valid(target):
		return
	var color := Color.WHITE
	match effect_type:
		BulletEffect.Type.BURN:
			color = Color(1.0, 0.55, 0.1)    # 橙色
		BulletEffect.Type.POISON:
			color = Color(0.3, 0.85, 0.3)    # 绿色
		BulletEffect.Type.BLEED:
			color = Color(0.9, 0.15, 0.15)   # 红色
	_show_damage_number(target, dmg, color, "", 20)
