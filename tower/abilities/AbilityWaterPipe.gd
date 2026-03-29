extends TowerAbility

## 水压管道 — 纯控制塔（0伤害）
##
## Path 0 冰封淋流：减速+冻结概率+冻结扩散
## Path 1 超级洪流：击退+被击退增伤
## Path 2 无限水流：攻速+射程+多目标
## Path 3 腐蚀水雾：降低敌人护甲

# ── Path 0 减速/冻结参数 ────────────────────────────────────────────────
const P0_SLOW:     Array[float] = [0.20, 0.30, 0.40, 0.50, 0.50, 0.60]
const P0_SLOW_DUR: Array[float] = [2.0,  2.0,  3.0,  3.0,  3.0,  3.0]
const P0_FREEZE_CHANCE: Array[float] = [0.0, 0.0, 0.0, 0.10, 0.10, 0.25]
const P0_FREEZE_DUR: float = 2.0
const P0_SPREAD_RADIUS: Array[float] = [0.0, 0.0, 0.0, 0.0, 100.0, 200.0]

# ── Path 1 击退参数 ─────────────────────────────────────────────────────
const P1_KNOCKBACK: Array[float] = [0.0, 30.0, 30.0, 30.0, 30.0, 60.0]
const P1_TARGETS:   Array[int]   = [0, 1, 3, 999, 999, 999]   # T3+ AOE all in range
const P1_SLOW_ON_KB: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.40, 0.50]  # T4+

# ── Path 2 攻速/射程/目标数 ─────────────────────────────────────────────
const P2_SPD:     Array[float] = [0.0, 0.15, 0.30, 0.50, 0.70, 0.70]
const P2_RNG:     Array[float] = [0.0, 0.15, 0.30, 0.50, 0.70, 0.70]
const P2_TARGETS: Array[int]   = [1, 2, 3, 5, 6, 8]

# ── Path 3 减甲参数 ─────────────────────────────────────────────────────
const P3_ARMOR_RED:  Array[float] = [0.0, 0.10, 0.18, 0.25, 0.30, 0.35]
const P3_ARMOR_DUR:  Array[float] = [0.0, 4.0,  4.0,  6.0,  6.0,  6.0]
const P3_AOE_RADIUS: Array[float] = [0.0, 0.0,  50.0, 50.0, 50.0, 100.0]

# ── 效果对象 ────────────────────────────────────────────────────────────
var _slow_fx: BulletEffect = null
var _freeze_fx: BulletEffect = null
var _mark_fx: BulletEffect = null   # Path1 T4: 被击退增伤


func _lv(path: int) -> int:
	return tower._in_game_path_levels[path] if tower._in_game_path_levels.size() > path else 0


func on_placed() -> void:
	_slow_fx = BulletEffect.new()
	_slow_fx.effect_type = BulletEffect.Type.SLOW
	_slow_fx.potency = 0.20
	_slow_fx.duration = 2.0

	_freeze_fx = BulletEffect.new()
	_freeze_fx.effect_type = BulletEffect.Type.STUN
	_freeze_fx.duration = P0_FREEZE_DUR

	_mark_fx = BulletEffect.new()
	_mark_fx.effect_type = BulletEffect.Type.MARK
	_mark_fx.potency = 0.20
	_mark_fx.duration = 3.0


# ═══════════════════════════════════════════════════════════════════════
# 主攻击
# ═══════════════════════════════════════════════════════════════════════
func do_attack(_target: Area2D, _damage: float, _td: TowerCollectionData) -> bool:
	tower.flash_attack_range(Color(0.3, 0.6, 1.0))
	var enemies: Array = tower.get_enemies_in_range().duplicate()
	var gp: bool = tower.buff_giant_pierce

	# 决定最大目标数
	var max_tgt: int = P2_TARGETS[_lv(2)]
	# Path1 也影响目标数
	if _lv(1) >= 1:
		max_tgt = maxi(max_tgt, P1_TARGETS[_lv(1)])

	var count: int = mini(max_tgt, enemies.size())

	# 更新减速参数
	_slow_fx.potency = P0_SLOW[_lv(0)]
	_slow_fx.duration = P0_SLOW_DUR[_lv(0)]
	# Path2 T4+: 减速时间+1s
	if _lv(2) >= 4:
		_slow_fx.duration += 1.0

	for i in count:
		var enemy: Area2D = enemies[i]
		if not is_instance_valid(enemy):
			continue

		# ── 基础减速 ──
		var effects: Array = [_slow_fx]
		deal_damage(enemy, 0.0, effects, gp)

		# ── Path 0: 冻结概率 ──
		var freeze_chance: float = P0_FREEZE_CHANCE[_lv(0)]
		if freeze_chance > 0.0 and randf() < freeze_chance:
			enemy._try_apply_effect(_freeze_fx, gp)
			# 冻结扩散
			var spread_r: float = P0_SPREAD_RADIUS[_lv(0)]
			if spread_r > 0.0:
				_spread_slow(enemy.global_position, spread_r, gp)

		# ── Path 1: 击退 ──
		var kb: float = P1_KNOCKBACK[_lv(1)]
		if kb > 0.0:
			enemy.apply_knockback(kb)
			# T4+: 被击退目标受伤+20%
			if _lv(1) >= 4:
				_mark_fx.potency = 0.20
				_mark_fx.duration = 3.0
				enemy._try_apply_effect(_mark_fx, gp)
			# T4+: 被击退目标减速
			var kb_slow: float = P1_SLOW_ON_KB[_lv(1)]
			if kb_slow > 0.0:
				var kb_slow_fx := BulletEffect.new()
				kb_slow_fx.effect_type = BulletEffect.Type.SLOW
				kb_slow_fx.potency = kb_slow
				kb_slow_fx.duration = 2.0
				enemy._try_apply_effect(kb_slow_fx, gp)

		# ── Path 3: 腐蚀减甲 ──
		if _lv(3) >= 1:
			_apply_armor_debuff(enemy)
			# T2+: 小范围AOE减甲
			var aoe_r: float = P3_AOE_RADIUS[_lv(3)]
			if aoe_r > 0.0:
				for other in enemies:
					if other == enemy or not is_instance_valid(other):
						continue
					if other.global_position.distance_to(enemy.global_position) <= aoe_r:
						_apply_armor_debuff(other)

	# Path2 T5: 必定减速（对所有范围内敌人）
	if _lv(2) >= 5:
		for enemy in enemies:
			if is_instance_valid(enemy):
				enemy._try_apply_effect(_slow_fx, gp)

	return true


# ═══════════════════════════════════════════════════════════════════════
# 被动处理
# ═══════════════════════════════════════════════════════════════════════
func ability_process(_delta: float) -> void:
	tower.ability_speed_bonus = P2_SPD[_lv(2)]
	tower.ability_range_bonus = P2_RNG[_lv(2)]
	tower.apply_stat_upgrades()

	# 更新特殊加成描述
	var specials: Array[String] = []
	if _lv(0) >= 3:
		specials.append("冻结概率：%d%%" % int(P0_FREEZE_CHANCE[_lv(0)] * 100))
	if _lv(1) >= 1:
		specials.append("击退：%.0fpx" % P1_KNOCKBACK[_lv(1)])
	if _lv(1) >= 4:
		specials.append("被击退目标受伤+20%%")
	if _lv(3) >= 1:
		var red: float = P3_ARMOR_RED[_lv(3)]
		specials.append("腐蚀减甲：%d%%" % int(red * 100))
	if _lv(3) >= 4:
		specials.append("对大型额外减甲：10%%")
	if _lv(3) >= 5:
		specials.append("对BOSS生效")
	tower.ability_special_bonuses = specials


# ═══════════════════════════════════════════════════════════════════════
# 辅助方法
# ═══════════════════════════════════════════════════════════════════════

## 冻结扩散（Path0 T4+）
func _spread_slow(center: Vector2, radius: float, pierce_g: bool) -> void:
	var spread_slow := BulletEffect.new()
	spread_slow.effect_type = BulletEffect.Type.SLOW
	spread_slow.potency = 0.30
	spread_slow.duration = 2.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		if enemy.global_position.distance_to(center) <= radius:
			enemy._try_apply_effect(spread_slow, pierce_g)


## 腐蚀减甲（Path3）— 临时降低敌人护甲（所有炮台攻击该敌人时受益）
func _apply_armor_debuff(enemy: Area2D) -> void:
	if not is_instance_valid(enemy):
		return
	var reduction: float = P3_ARMOR_RED[_lv(3)]
	# 对大型额外减甲10%（T4+）
	if _lv(3) >= 4:
		var ed = enemy.get("enemy_data")
		if ed and ed.get("is_giant"):
			reduction += 0.10
	# 使用独立的 debuff_armor_reduction（与地形减甲叠加）
	enemy.debuff_armor_reduction = maxf(enemy.debuff_armor_reduction, reduction)
	enemy._effects_dirty = true   # 触发 debuff 图标刷新
	# 设置定时恢复
	var dur: float = P3_ARMOR_DUR[_lv(3)]
	var enemy_ref: Area2D = enemy
	var reset_val: float = reduction
	get_tree().create_timer(dur).timeout.connect(func():
		if is_instance_valid(enemy_ref):
			if is_equal_approx(enemy_ref.debuff_armor_reduction, reset_val):
				enemy_ref.debuff_armor_reduction = 0.0
				enemy_ref._effects_dirty = true   # 腐蚀消失时刷新图标
	)
