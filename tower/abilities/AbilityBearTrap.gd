extends TowerAbility

## 捕兽夹 — 单次高伤+眩晕，冷却后重新触发
##
## Path 0 永不停歇：极短冷却+金币回复+连击加伤
## Path 1 终极钢咬：超高单次伤害+出血+爆炸+毒素+大型专克
## Path 2 毒液炸弹：毒素+扩散+毒爆
## Path 3 范围钢夹：AOE触发+爆炸+多目标+减速

@export var stun_duration: float = 3.0

# ── Path 0 冷却缩短 ─────────────────────────────────────────────────────
const P0_SPD: Array[float] = [0.0, 0.43, 1.0, 1.5, 2.33, 3.0]

# ── Path 1 伤害加成 ─────────────────────────────────────────────────────
const P1_DMG: Array[float] = [0.0, 0.30, 0.60, 0.60, 0.90, 0.90]

# ── Path 2 毒素参数 ─────────────────────────────────────────────────────
const P2_POISON_DPS: Array[float] = [0.0, 20.0, 35.0, 35.0, 35.0, 35.0]
const P2_POISON_DUR: Array[float] = [0.0, 4.0,  5.0,  5.0,  5.0,  5.0]
const P2_SPREAD_R:   Array[float] = [0.0, 0.0,  0.0,  100.0, 100.0, 150.0]

# ── Path 3 AOE + 攻速 ──────────────────────────────────────────────────
const P3_DMG: Array[float] = [0.0, 0.30, 0.50, 0.70, 0.90, 1.10]
const P3_SPD: Array[float] = [0.0, 0.30, 0.60, 0.60, 0.60, 0.60]
const P3_AOE: Array[float] = [0.0, 60.0, 90.0, 150.0, 150.0, 200.0]

# ── 连击追踪（Path0 T5）─────────────────────────────────────────────────
var _consecutive_hits: int = 0
var _triggered: bool = false   # 是否已触发（冷却中）
var _cd_elapsed: float = 0.0   # 触发后经过的时间（自行计时，不依赖 tower.attack_timer）
var _open_tex: Texture2D = null
var _half_tex: Texture2D = null
var _close_tex: Texture2D = null
var _cd_bar: ProgressBar = null


func _lv(path: int) -> int:
	return tower._in_game_path_levels[path] if tower._in_game_path_levels.size() > path else 0


func on_placed() -> void:
	# 缓存纹理引用
	var td := tower.tower_data as TowerCollectionData
	if td:
		_open_tex = td.base_texture      # Trap_Open
		_close_tex = td.shoot_texture     # Trap_Close
		_half_tex = td.ready_texture      # Trap_Half
	# 初始状态：打开
	_set_texture(_open_tex)
	# 完全禁用 Tower 默认纹理切换（由能力脚本接管）
	tower._ready_texture = null
	tower._shoot_texture = null
	tower._idle_texture = _open_tex
	# 创建冷却条
	_create_cd_bar()


func ability_process(delta: float) -> void:
	# 注入伤害加成（攻速不需要了，自行管理冷却）
	tower.ability_damage_bonus = P1_DMG[_lv(1)] + P3_DMG[_lv(3)]

	# ── 冷却计时 ──
	var cooldown: float = _get_cooldown()
	if _triggered:
		_cd_elapsed += delta
		if _cd_elapsed >= cooldown:
			# 冷却完成 → 就绪
			_triggered = false
			_cd_elapsed = 0.0
			_set_texture(_open_tex)
		elif _cd_elapsed >= cooldown * 0.9:
			_set_texture(_half_tex)
		else:
			_set_texture(_close_tex)
	else:
		# 就绪：检测范围内敌人，立即触发
		_set_texture(_open_tex)
		_check_and_trigger()

	_update_cd_bar()

	# 更新特殊描述
	var specials: Array[String] = []
	if _lv(0) >= 4:
		specials.append("每次触发回复5金币")
	if _lv(0) >= 5:
		specials.append("连续触发伤害+50%%")
	if _lv(1) >= 2:
		specials.append("出血：5dps/5s")
	if _lv(1) >= 3:
		specials.append("触发爆炸：80px")
	if _lv(1) >= 4:
		specials.append("强效毒素：30dps/6s")
	if _lv(1) >= 5:
		specials.append("对大型：×3伤害  普通：×2伤害")
	if _lv(2) >= 1:
		specials.append("毒素：%.0fdps/%.0fs" % [P2_POISON_DPS[_lv(2)], P2_POISON_DUR[_lv(2)]])
	if _lv(2) >= 4:
		specials.append("中毒减速：25%%")
	if _lv(2) >= 5:
		specials.append("毒爆：150px+眩晕3s")
	if _lv(3) >= 1:
		specials.append("AOE触发：%.0fpx" % P3_AOE[_lv(3)])
	if _lv(3) >= 5:
		specials.append("触发时全体减速40%% 5s")
	tower.ability_special_bonuses = specials


# ═══════════════════════════════════════════════════════════════════════
# 主攻击（Tower 冷却到后调用）
# ═══════════════════════════════════════════════════════════════════════
## 创建冷却进度条
func _create_cd_bar() -> void:
	_cd_bar = ProgressBar.new()
	_cd_bar.max_value = 1.0
	_cd_bar.value = 1.0
	_cd_bar.show_percentage = false
	_cd_bar.custom_minimum_size = Vector2(50, 6)
	_cd_bar.size = Vector2(50, 6)
	_cd_bar.position = Vector2(-25, -45)
	_cd_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cd_bar.visible = true   # 始终显示

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bg.corner_radius_top_left = 2
	bg.corner_radius_top_right = 2
	bg.corner_radius_bottom_left = 2
	bg.corner_radius_bottom_right = 2
	_cd_bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.7, 1.0)   # 蓝色 = 冷却中
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	_cd_bar.add_theme_stylebox_override("fill", fill)

	tower.add_child(_cd_bar)


## 更新冷却进度条（始终显示）
func _update_cd_bar() -> void:
	if not is_instance_valid(_cd_bar):
		return
	var fill := _cd_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if _triggered:
		var cooldown: float = _get_cooldown()
		var progress: float = _cd_elapsed / maxf(cooldown, 0.1)
		_cd_bar.value = clampf(progress, 0.0, 1.0)
		if fill:
			if progress >= 0.8:
				fill.bg_color = Color(0.2, 0.9, 0.3)
			else:
				fill.bg_color = Color(0.2, 0.7, 1.0)
	else:
		_cd_bar.value = 1.0
		if fill:
			fill.bg_color = Color(0.2, 0.9, 0.3)
	_cd_bar.rotation = -tower.global_rotation
	_cd_bar.position = Vector2(-25, -45).rotated(-tower.global_rotation)


## 计算当前冷却时间
func _get_cooldown() -> float:
	var base_cd: float = 10.0
	var spd_bonus: float = P0_SPD[_lv(0)] + P3_SPD[_lv(3)]
	return base_cd / maxf(1.0 + spd_bonus, 0.5)


## 就绪时检测敌人并立即触发
func _check_and_trigger() -> void:
	var enemies: Array = tower.get_enemies_in_range().duplicate()
	if enemies.is_empty():
		return
	# 找第一个非鼹鼠的敌人
	var target: Area2D = null
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var ed = enemy.get("enemy_data")
		if ed and ed.get("can_bypass_traps"):
			continue
		target = enemy
		break
	if target == null:
		return
	# 触发攻击
	var dmg: float = tower._get_effective_damage()
	do_attack(target, dmg, tower.tower_data as TowerCollectionData)


## 设置捕兽夹纹理（同步影子）
func _set_texture(tex: Texture2D) -> void:
	if not tex:
		return
	var spr: Sprite2D = tower.get_node_or_null("BaseSprite")
	if spr:
		spr.texture = tex
	var shadow: Sprite2D = tower.get_node_or_null("ShadowSprite")
	if shadow and shadow.visible:
		shadow.texture = tex


func do_attack(target: Area2D, damage: float, td: TowerCollectionData) -> bool:
	if not is_instance_valid(target):
		return true
	# 冷却中不触发
	if _triggered:
		return true
	# 鼹鼠免疫
	var ed_check = target.get("enemy_data")
	if ed_check and ed_check.get("can_bypass_traps"):
		return true

	# 触发：关闭
	_set_texture(_close_tex)
	_triggered = true
	_cd_elapsed = 0.0
	tower.flash_attack_range(Color(1.0, 0.6, 0.2))
	var gp: bool = tower.buff_giant_pierce
	var dmg: float = damage

	# ── Path0 T5: 连击加伤 ──
	if _lv(0) >= 5:
		_consecutive_hits += 1
		if _consecutive_hits >= 2:
			dmg *= 1.5

	# ── Path1 T5: 大型×3 普通×2 ──
	if _lv(1) >= 5:
		var ed = target.get("enemy_data")
		if ed and ed.get("is_giant"):
			dmg *= 3.0
		else:
			dmg *= 2.0

	# ── Path0 T4: 触发回复5金币 ──
	if _lv(0) >= 4:
		GameManager.add_gold(5)

	# ── 确定 AOE 范围 ──
	var aoe_r: float = P3_AOE[_lv(3)]

	if aoe_r > 0.0:
		# Path3: AOE 模式
		for enemy in tower.get_enemies_in_range().duplicate():
			if not is_instance_valid(enemy):
				continue
			var ed = enemy.get("enemy_data")
			if ed and ed.get("can_bypass_traps"):
				continue
			var e_dmg: float = dmg
			# Path3 T3: 爆炸 50% 原始伤（远处敌人）
			if _lv(3) >= 3 and enemy != target:
				if enemy.global_position.distance_to(target.global_position) > P3_AOE[mini(_lv(3) - 1, 5)]:
					e_dmg *= 0.5
			_hit_enemy(enemy, e_dmg, gp)

		# Path3 T5: 全体减速40% 5s
		if _lv(3) >= 5:
			var slow_fx := BulletEffect.new()
			slow_fx.effect_type = BulletEffect.Type.SLOW
			slow_fx.potency = 0.40
			slow_fx.duration = 5.0
			for enemy in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(enemy) and not enemy.finished:
					if enemy.global_position.distance_to(tower.global_position) <= aoe_r:
						enemy._try_apply_effect(slow_fx, gp)
	else:
		# 单体模式
		var ed = target.get("enemy_data")
		if not (ed and ed.get("can_bypass_traps")):
			_hit_enemy(target, dmg, gp)

	# ── Path2 T3+: 毒气扩散 ──
	var spread_r: float = P2_SPREAD_R[_lv(2)]
	if spread_r > 0.0:
		_spread_poison(target.global_position if is_instance_valid(target) else tower.global_position, spread_r, gp)

	# ── Path2 T5: 毒爆 + 眩晕3s ──
	if _lv(2) >= 5:
		_poison_explosion(target.global_position if is_instance_valid(target) else tower.global_position, 150.0, gp)

	return true


## 命中单个敌人：伤害 + 眩晕 + Path1效果 + Path2毒素
func _hit_enemy(enemy: Area2D, dmg: float, gp: bool) -> void:
	if not is_instance_valid(enemy):
		return

	deal_damage(enemy, dmg, [])

	# 基础眩晕
	var stun := BulletEffect.new()
	stun.effect_type = BulletEffect.Type.STUN
	stun.duration = stun_duration
	enemy._try_apply_effect(stun, gp)

	# Path1 T2: 出血
	if _lv(1) >= 2:
		var bleed := BulletEffect.new()
		bleed.effect_type = BulletEffect.Type.BLEED
		bleed.damage_per_tick = 5.0
		bleed.tick_interval = 1.0
		bleed.duration = 5.0
		bleed.affects_giant = true   # 出血对大型也生效
		enemy._try_apply_effect(bleed, gp)
		enemy._effects_dirty = true

	# Path1 T3: 小范围爆炸80px（对周围其他敌人）
	if _lv(1) >= 3:
		for other in get_tree().get_nodes_in_group("enemy"):
			if other == enemy or not is_instance_valid(other) or other.finished:
				continue
			if other.global_position.distance_to(enemy.global_position) <= 80.0:
				deal_damage(other, dmg * 0.5, [])

	# Path1 T4: 强效毒素
	if _lv(1) >= 4:
		var poison := BulletEffect.new()
		poison.effect_type = BulletEffect.Type.POISON
		poison.damage_per_tick = 30.0
		poison.tick_interval = 1.0
		poison.duration = 6.0
		enemy._try_apply_effect(poison, gp)

	# Path2: 毒素
	if _lv(2) >= 1:
		var poison := BulletEffect.new()
		poison.effect_type = BulletEffect.Type.POISON
		poison.damage_per_tick = P2_POISON_DPS[_lv(2)]
		poison.tick_interval = 1.0
		poison.duration = P2_POISON_DUR[_lv(2)]
		enemy._try_apply_effect(poison, gp)

	# Path2 T4: 中毒减速25%
	if _lv(2) >= 4:
		var slow := BulletEffect.new()
		slow.effect_type = BulletEffect.Type.SLOW
		slow.potency = 0.25
		slow.duration = P2_POISON_DUR[_lv(2)]
		enemy._try_apply_effect(slow, gp)


## 毒气扩散（Path2 T3+）
func _spread_poison(center: Vector2, radius: float, gp: bool) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		if enemy.global_position.distance_to(center) <= radius:
			var poison := BulletEffect.new()
			poison.effect_type = BulletEffect.Type.POISON
			poison.damage_per_tick = P2_POISON_DPS[_lv(2)]
			poison.tick_interval = 1.0
			poison.duration = P2_POISON_DUR[_lv(2)]
			enemy._try_apply_effect(poison, gp)


## 毒爆（Path2 T5）
func _poison_explosion(center: Vector2, radius: float, gp: bool) -> void:
	var stun := BulletEffect.new()
	stun.effect_type = BulletEffect.Type.STUN
	stun.duration = 3.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		if enemy.global_position.distance_to(center) <= radius:
			enemy._try_apply_effect(stun, gp)
	# 爆炸视觉
	var lbl := Label.new()
	lbl.text = "💥☠"
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.global_position = center - Vector2(18, 18)
	lbl.z_index = 50
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().current_scene.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(2.5, 2.5), 0.25).from(Vector2(0.5, 0.5))
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)
