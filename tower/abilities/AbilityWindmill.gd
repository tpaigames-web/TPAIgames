extends TowerAbility

## 风车 — 单体攻击（重构：从AoE改为单体），打地面+空中
##
## Path 0 龙卷风：击退+减速+眩晕+AOE龙卷
## Path 1 终极旋风：伤害+攻速+穿透+360°AOE
## Path 2 永动风车：攻速+每N次全场AOE
## Path 3 全场飓风：射程+减速控制

# ── 各路线各层累计加成（下标 = 层级 0-5）────────────────────────────────
# P0 无数值加成，纯效果
const P0_KNOCKBACK: Array[float] = [0.0, 60.0, 80.0, 80.0, 160.0, 120.0]
const P0_SLOW: Array[float]      = [0.0, 0.0, 0.25, 0.25, 0.25, 0.40]

const P1_DMG: Array[float] = [0.0, 0.15, 0.30, 0.45, 0.65, 0.65]
const P1_SPD: Array[float] = [0.0, 0.15, 0.30, 0.45, 0.65, 0.65]
const P1_RNG: Array[float] = [0.0, 0.0,  0.0,  0.0,  0.20, 0.20]
const P1_PIERCE: Array[int] = [0, 2, 3, 999, 999, 999]

const P2_SPD: Array[float] = [0.0, 0.20, 0.40, 0.60, 0.80, 0.80]
const P2_RNG: Array[float] = [0.0, 0.20, 0.40, 0.60, 0.80, 0.80]
const P2_GLOBAL_EVERY: Array[int] = [0, 0, 0, 4, 3, 2]

const P3_RNG: Array[float]  = [0.0, 0.20, 0.40, 0.60, 0.80, 0.80]
const P3_SLOW: Array[float] = [0.0, 0.0,  0.0,  0.15, 0.25, 0.35]

# ── 效果对象 ────────────────────────────────────────────────────────────
var _slow_fx: BulletEffect = null
var _stun_fx: BulletEffect = null
var _p3_slow_fx: BulletEffect = null

# ── P2 全场AOE计数器 ────────────────────────────────────────────────────
var _attack_count: int = 0


func on_placed() -> void:
	_slow_fx = BulletEffect.new()
	_slow_fx.effect_type = BulletEffect.Type.SLOW
	_slow_fx.duration = 1.5

	_stun_fx = BulletEffect.new()
	_stun_fx.effect_type = BulletEffect.Type.STUN
	_stun_fx.duration = 0.8

	_p3_slow_fx = BulletEffect.new()
	_p3_slow_fx.effect_type = BulletEffect.Type.SLOW
	_p3_slow_fx.duration = 2.0


func _lv(path: int) -> int:
	return tower._in_game_path_levels[path] if tower._in_game_path_levels.size() > path else 0


# ═══════════════════════════════════════════════════════════════════════
# 被动处理
# ═══════════════════════════════════════════════════════════════════════
func ability_process(_delta: float) -> void:
	tower.ability_damage_bonus = P1_DMG[_lv(1)]
	tower.ability_speed_bonus = P1_SPD[_lv(1)] + P2_SPD[_lv(2)]
	tower.ability_range_bonus = P1_RNG[_lv(1)] + P2_RNG[_lv(2)] + P3_RNG[_lv(3)]
	tower.apply_stat_upgrades()


# ═══════════════════════════════════════════════════════════════════════
# 主攻击 — 单体（根据升级变化为穿透/AOE）
# ═══════════════════════════════════════════════════════════════════════
func do_attack(target: Area2D, damage: float, td: TowerCollectionData) -> bool:
	if not is_instance_valid(target):
		return true

	tower.flash_attack_range(Color(0.9, 0.95, 1.0))
	var dmg: float = damage
	var effects: Array = td.bullet_effects.duplicate()
	var gp: bool = tower.buff_giant_pierce

	# ── P3 减速效果 ──
	if _lv(3) >= 3:
		_p3_slow_fx.potency = P3_SLOW[_lv(3)]
		effects.append(_p3_slow_fx)

	# ── 确定目标列表 ──
	var targets: Array = _get_attack_targets(target)

	# ── 对每个目标造成伤害 + 效果 ──
	for enemy in targets:
		if not is_instance_valid(enemy):
			continue
		var fd: float = _apply_dmg_mods(dmg, enemy)
		deal_damage(enemy, fd, effects, gp)

		# P0: 击退
		if _lv(0) >= 1 and is_instance_valid(enemy):
			var kb: float = P0_KNOCKBACK[_lv(0)]
			# P0 T4: 轻型翻倍，大型-50%
			if _lv(0) >= 4:
				var ed = enemy.get("enemy_data")
				if ed:
					if not ed.get("is_giant"):
						kb *= 2.0
					else:
						kb *= 0.5
			enemy.apply_knockback(kb)

		# P0 T2+: 减速
		if _lv(0) >= 2 and is_instance_valid(enemy):
			_slow_fx.potency = P0_SLOW[_lv(0)]
			enemy._try_apply_effect(_slow_fx, gp)

		# P0 T3: 25%概率眩晕0.8s
		if _lv(0) >= 3 and is_instance_valid(enemy):
			if randf() < 0.25:
				enemy._try_apply_effect(_stun_fx, gp)

	# ── P2: 全场AOE计数 ──
	_attack_count += 1
	var global_every: int = P2_GLOBAL_EVERY[_lv(2)]
	if global_every > 0 and _attack_count % global_every == 0:
		_do_global_aoe(dmg, effects, gp)

	return true


# ═══════════════════════════════════════════════════════════════════════
# 目标选择
# ═══════════════════════════════════════════════════════════════════════
func _get_attack_targets(primary: Area2D) -> Array:
	# P0 T5: 龙卷风AOE 120px（以目标为中心）
	if _lv(0) >= 5:
		var result: Array = []
		for enemy in GameManager.get_all_enemies():
			if not is_instance_valid(enemy) or enemy.finished:
				continue
			if enemy.global_position.distance_to(primary.global_position) <= 120.0:
				result.append(enemy)
		return result

	# P1 T5: 360° AOE全范围
	if _lv(1) >= 5:
		return tower.get_enemies_in_range().duplicate()

	# P1 T1-4: 穿透（最多 pierce_count 个目标）
	if _lv(1) >= 1:
		var pierce_max: int = P1_PIERCE[_lv(1)]
		if pierce_max >= 999:
			return tower.get_enemies_in_range().duplicate()
		var result: Array = [primary]
		var count: int = 1
		for enemy in tower.get_enemies_in_range():
			if enemy == primary or not is_instance_valid(enemy):
				continue
			if count >= pierce_max:
				break
			result.append(enemy)
			count += 1
		return result

	# 默认：单体
	return [primary]


# ═══════════════════════════════════════════════════════════════════════
# P2 全场AOE
# ═══════════════════════════════════════════════════════════════════════
func _do_global_aoe(base_dmg: float, effects: Array, gp: bool) -> void:
	var aoe_dmg: float = base_dmg * (0.5 if _lv(2) >= 5 else 1.0)
	tower.flash_attack_range(Color(0.5, 0.8, 1.0))
	for enemy in GameManager.get_all_enemies():
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		deal_damage(enemy, aoe_dmg, effects, gp)


# ═══════════════════════════════════════════════════════════════════════
# 伤害修正
# ═══════════════════════════════════════════════════════════════════════
func _apply_dmg_mods(base_dmg: float, enemy: Area2D) -> float:
	var d: float = base_dmg
	# P0 T5: 龙卷风伤害×2
	if _lv(0) >= 5:
		d *= 2.0
	return d
