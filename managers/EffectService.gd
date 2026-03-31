extends Node

## 效果生命周期管理服务（Autoload）
## 管理：效果施加、叠加规则、免疫检查、DoT tick、减速计算
## 效果数据存储在 Enemy._active_effects（Array[Dictionary]）中


## ── 施加效果 ──────────────────────────────────────────────────────────

## 批量施加子弹携带的效果
func apply_effects(enemy: Area2D, effects: Array, pierce_giant: bool = false) -> void:
	for effect in effects:
		apply_single_effect(enemy, effect, pierce_giant)


## 施加单个效果（检查免疫 → 叠加规则 → 加入激活列表）
func apply_single_effect(enemy: Area2D, effect: BulletEffect, pierce_giant: bool = false) -> void:
	if not is_instance_valid(enemy):
		return
	if not enemy.get("enemy_data"):
		return

	var t: int = effect.effect_type
	var is_control: bool = (t == BulletEffect.Type.SLOW or t == BulletEffect.Type.STUN)
	var is_dot: bool = (t == BulletEffect.Type.BURN or t == BulletEffect.Type.POISON or t == BulletEffect.Type.BLEED)
	var ed = enemy.enemy_data

	# 控制免疫检查
	if is_control and ed:
		if ed.is_control_immune:
			return
		if ed.get("shield_grants_control_immune") and enemy.get("_shield_active"):
			return
		if ed.is_giant and not effect.affects_giant and not pierce_giant:
			return

	# DoT 免疫检查
	if is_dot and ed and ed.is_dot_immune:
		return

	var active_effects: Array = enemy._active_effects

	# 叠加规则
	if t != BulletEffect.Type.BLEED:
		for existing in active_effects:
			if existing.type == t:
				existing.remaining = maxf(existing.remaining, effect.duration)
				if t == BulletEffect.Type.SLOW or t == BulletEffect.Type.MARK:
					existing.potency = maxf(existing.potency, effect.potency)
				else:
					existing.potency = effect.potency
				return
	else:
		# BLEED 叠加上限 8 层
		var bleed_count: int = 0
		var oldest_idx: int = -1
		var oldest_rem: float = INF
		for i in active_effects.size():
			if active_effects[i].type == BulletEffect.Type.BLEED:
				bleed_count += 1
				if active_effects[i].remaining < oldest_rem:
					oldest_rem = active_effects[i].remaining
					oldest_idx = i
		if bleed_count >= 8 and oldest_idx >= 0:
			active_effects.remove_at(oldest_idx)

	active_effects.append({
		type            = t,
		remaining       = effect.duration,
		potency         = effect.potency,
		damage_per_tick = effect.damage_per_tick,
		tick_interval   = effect.tick_interval,
		tick_timer      = 0.0,
	})
	enemy._effects_dirty = true


## ── 效果 Tick 处理 ──────────────────────────────────────────────────

## 每帧处理目标身上的所有效果（倒计时、DoT tick）
func process_tick(enemy: Area2D, delta: float) -> void:
	if not is_instance_valid(enemy):
		return
	# 地鼠挖洞中暂停所有效果计时和DoT
	if enemy.get("is_burrowed"):
		return
	var active_effects: Array = enemy._active_effects
	var i: int = active_effects.size() - 1
	while i >= 0:
		var eff: Dictionary = active_effects[i]
		eff.remaining -= delta
		var tick_iv: float = eff.get("tick_interval", 0.0)
		if tick_iv > 0.0:
			eff.tick_timer += delta
			if eff.tick_timer >= tick_iv:
				eff.tick_timer -= tick_iv
				# DoT 伤害直接扣 HP（绕过护盾）
				var dot_dmg: float = eff.get("damage_per_tick", 0.0)
				if dot_dmg > 0.0:
					CombatService.show_dot_damage_number(enemy, int(dot_dmg), eff.type)
					enemy.hp -= int(dot_dmg)
					enemy._update_hp_bar()
					if enemy.hp <= 0:
						enemy.die()
						return
		if eff.remaining <= 0.0:
			active_effects.remove_at(i)
			enemy._effects_dirty = true
		i -= 1
	# 狂暴检查
	_check_berserk(enemy)


## ── 速度查询 ──────────────────────────────────────────────────────────

## 获取受效果影响后的实际移动速度
func get_effective_speed(enemy: Area2D, base_speed: float) -> float:
	if not is_instance_valid(enemy):
		return base_speed
	for eff in enemy._active_effects:
		if eff.type == BulletEffect.Type.STUN:
			return 0.0
	var s: float = base_speed
	for eff in enemy._active_effects:
		if eff.type == BulletEffect.Type.SLOW:
			s *= (1.0 - eff.potency)
	var terrain_slow: float = enemy.get("terrain_slow")
	if terrain_slow and terrain_slow > 0.0:
		s *= (1.0 - terrain_slow)
	return maxf(s, 0.0)


## ── 效果查询 ──────────────────────────────────────────────────────────

func has_effect_type(enemy: Area2D, type: int) -> bool:
	if not is_instance_valid(enemy):
		return false
	for eff in enemy._active_effects:
		if eff.type == type:
			return true
	return false

func get_mark_bonus(enemy: Area2D) -> float:
	if not is_instance_valid(enemy):
		return 0.0
	var bonus: float = 0.0
	for eff in enemy._active_effects:
		if eff.type == BulletEffect.Type.MARK:
			bonus += eff.potency
	return bonus

func clear_enemy(enemy: Area2D) -> void:
	if is_instance_valid(enemy) and enemy.get("_active_effects"):
		enemy._active_effects.clear()


## ── 内部辅助 ──────────────────────────────────────────────────────────

func _check_berserk(enemy: Area2D) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.get("_berserk_triggered"):
		return
	var ed = enemy.get("enemy_data")
	if not ed or not ed.get("is_berserk"):
		return
	if ed.max_hp > 0 and float(enemy.hp) / float(ed.max_hp) < ed.berserk_threshold:
		enemy._berserk_triggered = true
		enemy.speed *= (1.0 + ed.berserk_speed_bonus)
