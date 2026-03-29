extends TowerAbility

## 稻草人 — 近程单体攻击（重构：从AoE改为单体）
##
## Path 0 终极收割：穿透 + 护甲忽视 + 出血 + 大型克制
## Path 1 稻草旋风：攻速 + 近程旋转伤害区域 + 多目标
## Path 2 缠绕领域：减速 + 对空解锁 + 大型专克 + AOE减速
## Path 3 丰收诅咒：标记增伤 + 扩散 + 死亡爆炸

# ── 各路线各层累计加成（下标 = 层级 0-5）────────────────────────────────
const P0_DMG: Array[float] = [0.0, 0.15, 0.30, 0.45, 0.45, 0.90]
const P0_PIERCE: Array[int] = [0, 0, 1, 2, 2, 2]

const P1_SPD: Array[float] = [0.0, 0.15, 0.30, 0.60, 0.80, 0.80]
const P1_DMG: Array[float] = [0.0, 0.0,  0.0,  0.0,  0.25, 0.25]
const P1_RNG: Array[float] = [0.0, 0.0,  0.0,  0.0,  0.0,  0.50]

const P2_DMG: Array[float] = [0.0, 0.0,  0.20, 0.20, 0.20, 0.20]
const P2_RNG: Array[float] = [0.0, 0.0,  0.0,  0.0,  0.20, 0.20]
const P2_SLOW: Array[float] = [0.0, 0.15, 0.25, 0.25, 0.40, 0.50]

const P3_SPD: Array[float] = [0.0, 0.0,  0.0,  0.15, 0.15, 0.15]
const P3_RNG: Array[float] = [0.0, 0.0,  0.0,  0.0,  0.15, 0.15]

# ── 旋转攻击基础半径 ────────────────────────────────────────────────────
@export var spin_base_radius: float = 80.0

# ── 效果对象 ────────────────────────────────────────────────────────────
var _slow_fx: BulletEffect = null
var _bleed_fx: BulletEffect = null
var _mark_fx: BulletEffect = null

# ── 旋转攻击计时 ────────────────────────────────────────────────────────
var _spin_timer: float = 0.0


func on_placed() -> void:
	_slow_fx = BulletEffect.new()
	_slow_fx.effect_type = BulletEffect.Type.SLOW
	_slow_fx.duration = 1.5

	_bleed_fx = BulletEffect.new()
	_bleed_fx.effect_type = BulletEffect.Type.BLEED
	_bleed_fx.damage_per_tick = 3.0
	_bleed_fx.tick_interval = 1.0
	_bleed_fx.duration = 4.0

	_mark_fx = BulletEffect.new()
	_mark_fx.effect_type = BulletEffect.Type.MARK
	_mark_fx.duration = 3.0
	_mark_fx.potency = 0.10


func _lv(path: int) -> int:
	return tower._in_game_path_levels[path] if tower._in_game_path_levels.size() > path else 0


## 同步能力加成到 Tower（Tower 自动用 ability_*_bonus 计算）
func _sync_ability_bonuses() -> void:
	tower.ability_damage_bonus = P0_DMG[_lv(0)] + P1_DMG[_lv(1)] + P2_DMG[_lv(2)]
	tower.ability_speed_bonus = P1_SPD[_lv(1)] + P3_SPD[_lv(3)]
	tower.ability_range_bonus = P1_RNG[_lv(1)] + P2_RNG[_lv(2)] + P3_RNG[_lv(3)]
	# Path2 T3+: 解锁对空攻击
	tower.ability_attack_type = 2 if _lv(2) >= 3 else -1
	tower.apply_stat_upgrades()   # 刷新射程


# ═══════════════════════════════════════════════════════════════════════
# 主攻击
# ═══════════════════════════════════════════════════════════════════════
func do_attack(target: Area2D, damage: float, td: TowerCollectionData) -> bool:
	tower.flash_attack_range(Color(0.6, 0.3, 0.8))

	var dmg: float = damage   # Tower 已通过 ability_damage_bonus 计算
	var effects: Array = td.bullet_effects.duplicate()
	var gp: bool = tower.buff_giant_pierce

	# ── Path 0 T4+: 护甲穿透 ──
	tower.armor_penetration = 1 if _lv(0) >= 4 else 0

	# ── Path 0 T5: 出血 ──
	if _lv(0) >= 5:
		effects.append(_bleed_fx)

	# ── Path 2: 减速 ──
	if _lv(2) >= 1:
		_slow_fx.potency = P2_SLOW[_lv(2)]
		_slow_fx.affects_giant = _lv(2) >= 4
		effects.append(_slow_fx)

	# ── Path 3: 标记 ──
	if _lv(3) >= 1:
		_mark_fx.potency = 0.35 if _lv(3) >= 5 else 0.10
		_mark_fx.duration = 8.0 if _lv(3) >= 5 else 3.0
		effects.append(_mark_fx)

	# ── 攻击类型（Path2 T3+ 对空）──
	var atk_type: int = 2 if _lv(2) >= 3 else 0

	# ── Path2 T5: AOE 150px ──
	if _lv(2) >= 5:
		for enemy in tower.get_enemies_in_range(atk_type):
			if is_instance_valid(enemy):
				var fd: float = _apply_dmg_mods(dmg, enemy)
				deal_damage(enemy, fd, effects, gp)
		return true

	# ── 单体 + 穿透 ──
	var pierce_count: int = P0_PIERCE[_lv(0)]
	var max_hits: int = 1 + pierce_count
	var hit: int = 0

	for enemy in tower.get_enemies_in_range(atk_type):
		if not is_instance_valid(enemy) or hit >= max_hits:
			break
		var fd: float = _apply_dmg_mods(dmg, enemy)
		deal_damage(enemy, fd, effects, gp)
		hit += 1

		# Path 3 T2: 标记扩散至1邻敌
		if _lv(3) == 2:
			_spread_mark(enemy, 1)
		# Path 3 T3+: 标记 AOE 100px
		elif _lv(3) >= 3:
			_mark_aoe(enemy.global_position, 100.0)

		# Path 3 T4+: 死亡爆炸
		if _lv(3) >= 4 and is_instance_valid(enemy) and enemy.hp <= 0:
			_death_explode(enemy.global_position)

	return true


## 伤害修正（大型克制、减速增伤）
func _apply_dmg_mods(base_dmg: float, enemy: Area2D) -> float:
	var d: float = base_dmg
	# Path 0 T5: 对大型 +50%
	if _lv(0) >= 5:
		var ed = enemy.get("enemy_data")
		if ed and ed.get("is_giant"):
			d *= 1.5
	# Path 2 T2+: 对已减速目标 +20%
	if _lv(2) >= 2 and _is_slowed(enemy):
		d *= 1.2
	return d


# ═══════════════════════════════════════════════════════════════════════
# 被动处理（旋转攻击 + 射程/攻速同步）
# ═══════════════════════════════════════════════════════════════════════
func ability_process(delta: float) -> void:
	_sync_ability_bonuses()

	# Path1 T3+: 近程旋转伤害区域
	if _lv(1) >= 3:
		_spin_timer += delta
		var interval: float = tower._get_effective_attack_interval()
		if _spin_timer >= interval:
			_spin_timer = 0.0
			_do_spin_attack()


# ═══════════════════════════════════════════════════════════════════════
# 旋转攻击（Path1 T3+）
# ═══════════════════════════════════════════════════════════════════════
func _do_spin_attack() -> void:
	var spin_r: float = spin_base_radius
	if _lv(1) >= 5:
		spin_r *= 1.5
	var max_t: int = 4 if _lv(1) >= 4 else 999
	var dmg: float = tower._get_effective_damage() * 0.6
	var atk_type: int = 2 if _lv(2) >= 3 else 0
	var hit: int = 0

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		if hit >= max_t:
			break
		if atk_type == 0:
			var ed = enemy.get("enemy_data")
			if ed and ed.get("is_flying"):
				continue
		if enemy.global_position.distance_to(tower.global_position) <= spin_r:
			deal_damage(enemy, dmg, [], tower.buff_giant_pierce)
			hit += 1

	tower.flash_attack_range(Color(0.4, 0.8, 0.3))


# ═══════════════════════════════════════════════════════════════════════
# 辅助方法
# ═══════════════════════════════════════════════════════════════════════

func _is_slowed(enemy: Area2D) -> bool:
	if not is_instance_valid(enemy):
		return false
	if enemy.get("terrain_slow") != null and enemy.terrain_slow > 0.0:
		return true
	var effs = enemy.get("_active_effects")
	if effs:
		for eff in effs:
			if eff.get("type") == BulletEffect.Type.SLOW:
				return true
	return false


func _spread_mark(source: Area2D, count: int) -> void:
	var spread: int = 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == source or not is_instance_valid(enemy) or enemy.finished:
			continue
		if spread >= count:
			break
		if enemy.global_position.distance_to(source.global_position) <= 120.0:
			if enemy.has_method("apply_effect"):
				enemy.apply_effect(_mark_fx)
			spread += 1


func _mark_aoe(center: Vector2, radius: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		if enemy.global_position.distance_to(center) <= radius:
			if enemy.has_method("apply_effect"):
				enemy.apply_effect(_mark_fx)


func _death_explode(pos: Vector2) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		if enemy.global_position.distance_to(pos) <= 100.0:
			deal_damage(enemy, 50.0, [], tower.buff_giant_pierce)
