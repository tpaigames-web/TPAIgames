extends TowerAbility

## 农夫 — 3弹丸散射，打空打地
##
## Path 0 终极连射：攻速/伤害/射程/多目标+减速
## Path 1 神枪手：单体穿透+暴击+护甲忽视+BOSS专克
## Path 2 霰弹之王：弹丸数量+穿透+爆炸+击退
## Path 3 终极狙杀：暴击率+眩晕+连续暴击加伤+链式眩晕

# ── Path 0 终极连射 ─────────────────────────────────────────────────────
const P0_DMG: Array[float] = [0.0, 0.10, 0.20, 0.40, 0.60, 0.80]
const P0_SPD: Array[float] = [0.0, 0.10, 0.40, 0.60, 0.80, 1.00]
const P0_RNG: Array[float] = [0.0, 0.20, 0.20, 0.60, 0.80, 0.80]
const P0_TARGETS: Array[int] = [3, 3, 3, 3, 5, 6]

# ── Path 1 神枪手 ──────────────────────────────────────────────────────
const P1_DMG: Array[float] = [0.0, 0.12, 0.24, 0.48, 0.72, 0.96]
const P1_SPD: Array[float] = [0.0, 0.0, 0.30, 0.30, 0.30, 0.30]
const P1_RNG: Array[float] = [0.0, 0.30, 0.30, 0.30, 0.30, 0.30]
const P1_CRIT_CHANCE: Array[float] = [0.0, 0.0, 0.0, 0.30, 0.40, 1.0]
const P1_CRIT_MULT: Array[float] = [1.0, 1.0, 1.0, 2.5, 2.5, 3.0]
const P1_PIERCE: Array[int] = [0, 0, 99, 99, 99, 99]   # T2+: 穿透所有

# ── Path 2 霰弹之王 ────────────────────────────────────────────────────
const P2_DMG: Array[float] = [0.0, 0.12, 0.24, 0.36, 0.48, 0.60]
const P2_SPD: Array[float] = [0.0, 0.12, 0.12, 0.12, 0.20, 0.20]
const P2_PELLETS: Array[int] = [3, 5, 5, 5, 10, 20]
const P2_PIERCE: Array[int] = [0, 0, 1, 1, 1, 1]   # T2+: 穿透1敌
const P2_SPLASH: Array[float] = [0.0, 0.0, 0.0, 30.0, 30.0, 30.0]  # T3+: 爆炸30px

# ── Path 3 终极狙杀 ────────────────────────────────────────────────────
const P3_CRIT_CHANCE: Array[float] = [0.0, 0.20, 0.35, 0.50, 0.60, 0.70]
const P3_CRIT_MULT: float = 2.0
const P3_STUN_DUR: Array[float] = [0.0, 0.3, 0.5, 0.5, 1.0, 1.5]

# ── 连续暴击追踪 ────────────────────────────────────────────────────────
var _consecutive_crits: int = 0


func _lv(path: int) -> int:
	return tower._in_game_path_levels[path] if tower._in_game_path_levels.size() > path else 0


func on_placed() -> void:
	pass


func ability_process(_delta: float) -> void:
	tower.ability_damage_bonus = P0_DMG[_lv(0)] + P1_DMG[_lv(1)] + P2_DMG[_lv(2)]
	tower.ability_speed_bonus = P0_SPD[_lv(0)] + P1_SPD[_lv(1)] + P2_SPD[_lv(2)]
	tower.ability_range_bonus = P0_RNG[_lv(0)] + P1_RNG[_lv(1)]
	# Path2 T4+: 射程+20%
	if _lv(2) >= 4:
		tower.ability_range_bonus += 0.20
	tower.apply_stat_upgrades()

	# Path1 T4: 对大型无视护甲
	if _lv(1) >= 5:
		tower.armor_penetration = 3   # 无视约50%护甲（降3级）
	elif _lv(1) >= 4:
		tower.armor_penetration = 1   # 无视约25%（降1级）
	else:
		tower.armor_penetration = 0

	# 特殊描述
	var specials: Array[String] = []
	if _lv(0) >= 3:
		specials.append("对大型：+30%%伤害")
	if _lv(0) >= 5:
		specials.append("每发附带5%%减速")
	if _lv(1) >= 2:
		specials.append("穿透所有目标")
	if _lv(1) >= 3:
		specials.append("暴击：%d%% ×%.1f" % [int(P1_CRIT_CHANCE[_lv(1)] * 100), P1_CRIT_MULT[_lv(1)]])
	if _lv(1) >= 5:
		specials.append("对BOSS无视50%%护甲")
	if _lv(2) >= 2:
		specials.append("弹丸穿透：1敌")
	if _lv(2) >= 3:
		specials.append("弹丸爆炸：30px")
	if _lv(2) >= 5:
		specials.append("弹丸击退")
	if _lv(3) >= 1:
		specials.append("暴击率：%d%% 眩晕%.1fs" % [int(P3_CRIT_CHANCE[_lv(3)] * 100), P3_STUN_DUR[_lv(3)]])
	if _lv(3) >= 3:
		specials.append("连续暴击+30%%伤害")
	if _lv(3) >= 4:
		specials.append("眩晕目标受伤+30%%")
	tower.ability_special_bonuses = specials


# ═══════════════════════════════════════════════════════════════════════
# 主攻击
# ═══════════════════════════════════════════════════════════════════════
func do_attack(_target: Area2D, damage: float, td: TowerCollectionData) -> bool:
	var enemies: Array = tower.get_enemies_in_range().duplicate()
	var gp: bool = tower.buff_giant_pierce

	# 确定弹丸数
	var pellets: int = P2_PELLETS[_lv(2)]
	if _lv(2) == 0:
		pellets = P0_TARGETS[_lv(0)]
	var count: int = mini(pellets, enemies.size())

	# 暴击参数（取 Path1 和 Path3 中更高的）
	var crit_chance: float = maxf(P1_CRIT_CHANCE[_lv(1)], P3_CRIT_CHANCE[_lv(3)])
	var crit_mult: float = P1_CRIT_MULT[_lv(1)] if _lv(1) >= 3 else P3_CRIT_MULT
	var stun_dur: float = P3_STUN_DUR[_lv(3)]

	# Path3 T5 / Path1 T5: 必定暴击
	var force_all_crit: bool = _lv(1) >= 5 or _lv(3) >= 5

	# 穿透参数
	var pierce: int = P1_PIERCE[_lv(1)] + P2_PIERCE[_lv(2)]

	# 溅射参数
	var splash_r: float = P2_SPLASH[_lv(2)]

	# 减速效果（Path0 T5）
	var slow_fx: BulletEffect = null
	if _lv(0) >= 5:
		slow_fx = BulletEffect.new()
		slow_fx.effect_type = BulletEffect.Type.SLOW
		slow_fx.potency = 0.05
		slow_fx.duration = 1.5

	for i in count:
		var enemy: Area2D = enemies[i]
		if not is_instance_valid(enemy):
			continue

		var is_crit: bool = force_all_crit or (crit_chance > 0.0 and randf() < crit_chance)

		var shot_dmg: float = damage
		if is_crit:
			shot_dmg *= crit_mult
			_consecutive_crits += 1
			# Path3 T3+: 连续暴击+30%
			if _lv(3) >= 3 and _consecutive_crits >= 2:
				shot_dmg *= 1.3
		else:
			_consecutive_crits = 0

		# Path0 T3+: 对大型+30%
		if _lv(0) >= 3:
			var ed = enemy.get("enemy_data")
			if ed and ed.get("is_giant"):
				shot_dmg *= 1.3

		# 构建效果
		var effects: Array = td.bullet_effects.duplicate()
		if slow_fx:
			effects.append(slow_fx)

		# Path3 T4: 眩晕目标受伤+30%（MARK）
		if _lv(3) >= 4 and is_crit:
			var mark := BulletEffect.new()
			mark.effect_type = BulletEffect.Type.MARK
			mark.potency = 0.30
			mark.duration = 3.0
			effects.append(mark)

		# 发射弹丸
		if td.bullet_speed > 0.0:
			var bullet: Node = tower.spawn_bullet_at(enemy, shot_dmg, td.bullet_speed, effects,
					td.bullet_emoji, splash_r, 0.5, td.bullet_scene)
			if bullet:
				bullet.pierce_count = pierce
				# Path2 T5: 击退
				if _lv(2) >= 5:
					bullet.knockback_distance = 20.0
		else:
			deal_damage(enemy, shot_dmg, effects, gp)

		# 暴击眩晕
		if is_crit and stun_dur > 0.0 and is_instance_valid(enemy):
			var stun := BulletEffect.new()
			stun.effect_type = BulletEffect.Type.STUN
			stun.duration = stun_dur
			enemy._try_apply_effect(stun, gp)

	return true
