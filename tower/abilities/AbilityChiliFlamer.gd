extends TowerAbility

## 辣椒喷火器 — 近程分段喷火，只打地面
##
## Path 0 太阳炙热：伤害+燃烧DOT+护甲穿透+大型克制
## Path 1 烈焰洪流：锥形AOE覆盖（60°→150°）
## Path 2 永恒火焰：攻速+减速，T5持续喷火模式
## Path 3 地狱魔辣：标记增伤+扩散+减速

# ── 各路线各层累计加成（下标 = 层级 0-5）────────────────────────────────
const P0_DMG: Array[float] = [0.0, 0.20, 0.40, 0.60, 0.80, 1.00]
const P0_SPD: Array[float] = [0.0, 0.20, 0.40, 0.40, 0.40, 0.40]

const P1_RNG: Array[float] = [0.0, 0.15, 0.15, 0.15, 0.20, 0.20]
const P1_SPD: Array[float] = [0.0, 0.15, 0.15, 0.15, 0.15, 0.15]
const P1_CONE: Array[float] = [0.0, 0.0, 60.0, 90.0, 120.0, 150.0]
const P1_DMG: Array[float]  = [0.0, 0.0, 0.0, 0.0, 0.20, 0.20]

const P2_SPD: Array[float] = [0.0, 0.18, 0.36, 0.54, 0.72, 0.72]

const P3_MARK: Array[float] = [0.0, 0.12, 0.18, 0.25, 0.30, 0.30]

# ── 燃烧配置（P0） ──────────────────────────────────────────────────────
const P0_BURN_DPS: Array[float]  = [0.0, 2.0, 4.0, 8.0, 8.0, 8.0]
const P0_BURN_DUR: Array[float]  = [0.0, 3.0, 4.0, 4.0, 8.0, 8.0]
const P0_ARMOR_PEN: Array[int]   = [0, 0, 0, 1, 1, 2]

# ── 减速配置（P2） ──────────────────────────────────────────────────────
const P2_SLOW_POT: Array[float] = [0.0, 0.0, 0.0, 0.15, 0.25, 0.35]

# ── 效果对象 ────────────────────────────────────────────────────────────
var _burn_fx: BulletEffect = null
var _slow_fx: BulletEffect = null
var _mark_fx: BulletEffect = null
var _mark_slow_fx: BulletEffect = null

# ── 火焰粒子 ────────────────────────────────────────────────────────────
var _fire_particles: CPUParticles2D = null
var _burst_timer: float = 0.0

# ── P2 T5 持续模式 ──────────────────────────────────────────────────────
var _cont_timer: float = 0.0
@export var continuous_tick: float = 0.15

# ── P3 T5 标记增伤光环 ─────────────────────────────────────────────────
var _aura_timer: float = 0.0
var _aura_buffed_towers: Array = []
const AURA_REFRESH_INTERVAL: float = 0.5


func on_placed() -> void:
	# 初始化效果对象
	_burn_fx = BulletEffect.new()
	_burn_fx.effect_type = BulletEffect.Type.BURN
	_burn_fx.damage_per_tick = 2.0
	_burn_fx.tick_interval = 1.0
	_burn_fx.duration = 3.0

	_slow_fx = BulletEffect.new()
	_slow_fx.effect_type = BulletEffect.Type.SLOW
	_slow_fx.potency = 0.15
	_slow_fx.duration = 0.5

	_mark_fx = BulletEffect.new()
	_mark_fx.effect_type = BulletEffect.Type.MARK
	_mark_fx.potency = 0.12
	_mark_fx.duration = 4.0

	_mark_slow_fx = BulletEffect.new()
	_mark_slow_fx.effect_type = BulletEffect.Type.SLOW
	_mark_slow_fx.potency = 0.20
	_mark_slow_fx.duration = 2.0

	# 创建火焰粒子（核心游戏视觉，不受设置中粒子开关影响）
	_fire_particles = CPUParticles2D.new()
	_fire_particles.emitting = false
	_fire_particles.amount = 40
	_fire_particles.lifetime = 0.4
	_fire_particles.one_shot = false
	_fire_particles.explosiveness = 0.9
	_fire_particles.direction = Vector2(1, 0)
	_fire_particles.spread = 15.0
	_fire_particles.initial_velocity_min = 150.0
	_fire_particles.initial_velocity_max = 250.0
	_fire_particles.gravity = Vector2.ZERO
	_fire_particles.scale_amount_min = 2.0
	_fire_particles.scale_amount_max = 5.0
	_fire_particles.z_index = 10
	# 颜色渐变：黄→橙→红→透明
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.2, 1.0))
	grad.add_point(0.3, Color(1.0, 0.5, 0.1, 0.9))
	grad.add_point(0.7, Color(0.9, 0.2, 0.05, 0.6))
	grad.set_color(1, Color(0.5, 0.1, 0.0, 0.0))
	_fire_particles.color_ramp = grad
	tower.add_child(_fire_particles)


func _lv(path: int) -> int:
	return tower._in_game_path_levels[path] if tower._in_game_path_levels.size() > path else 0


# ═══════════════════════════════════════════════════════════════════════
# 被动处理
# ═══════════════════════════════════════════════════════════════════════
func ability_process(delta: float) -> void:
	_sync_ability_bonuses()
	_update_particles()

	# 粒子突发关闭计时
	if _burst_timer > 0.0:
		_burst_timer -= delta
		if _burst_timer <= 0.0 and _lv(2) < 5:
			_fire_particles.emitting = false

	# P2 T5 持续模式
	if _lv(2) >= 5:
		_cont_timer += delta
		if _cont_timer >= continuous_tick:
			_cont_timer = 0.0
			_do_continuous_tick()

	# P3 T5 标记增伤光环
	if _lv(3) >= 5:
		_aura_timer += delta
		if _aura_timer >= AURA_REFRESH_INTERVAL:
			_aura_timer = 0.0
			_refresh_mark_aura()
	elif _aura_buffed_towers.size() > 0:
		_clear_mark_aura()


func _sync_ability_bonuses() -> void:
	tower.ability_damage_bonus = P0_DMG[_lv(0)] + P1_DMG[_lv(1)]
	tower.ability_speed_bonus = P0_SPD[_lv(0)] + P1_SPD[_lv(1)] + P2_SPD[_lv(2)]
	tower.ability_range_bonus = P1_RNG[_lv(1)]
	tower.armor_penetration = P0_ARMOR_PEN[_lv(0)]
	tower.apply_stat_upgrades()


func _update_particles() -> void:
	if not is_instance_valid(_fire_particles):
		return
	# 方向指向当前目标
	if is_instance_valid(tower._current_target):
		var dir: Vector2 = tower._current_target.global_position - tower.global_position
		_fire_particles.rotation = dir.angle()
	# 锥形模式调整扩散
	if _lv(1) >= 2:
		_fire_particles.spread = P1_CONE[_lv(1)] / 2.0
	else:
		_fire_particles.spread = 15.0
	# P2 T5 持续模式配置
	if _lv(2) >= 5:
		_fire_particles.explosiveness = 0.0
		var has_enemies: bool = tower.get_enemies_in_range().size() > 0
		_fire_particles.emitting = has_enemies


# ═══════════════════════════════════════════════════════════════════════
# 主攻击 — 分段喷火
# ═══════════════════════════════════════════════════════════════════════
func do_attack(target: Area2D, damage: float, _td: TowerCollectionData) -> bool:
	# P2 T5 持续模式：由 ability_process 处理
	if _lv(2) >= 5:
		return true

	if not is_instance_valid(target):
		return true

	var dmg: float = damage
	var effects: Array = _build_effects()
	var gp: bool = tower.buff_giant_pierce

	# 触发粒子突发
	if is_instance_valid(_fire_particles):
		_fire_particles.emitting = true
		_burst_timer = 0.25

	# 锥形 or 单目标
	if _lv(1) >= 2:
		var dir: Vector2 = (target.global_position - tower.global_position).normalized()
		var half_angle: float = deg_to_rad(P1_CONE[_lv(1)] / 2.0)
		var enemies: Array = _get_enemies_in_cone(tower.global_position, dir, tower._effective_range, half_angle)
		for enemy in enemies:
			if is_instance_valid(enemy):
				var fd: float = _apply_dmg_mods(dmg, enemy)
				deal_damage(enemy, fd, effects, gp)
				_on_hit_marked_effects(enemy)
	else:
		var fd: float = _apply_dmg_mods(dmg, target)
		deal_damage(target, fd, effects, gp)
		_on_hit_marked_effects(target)

	return true


# ═══════════════════════════════════════════════════════════════════════
# P2 T5 持续喷火 tick
# ═══════════════════════════════════════════════════════════════════════
func _do_continuous_tick() -> void:
	var base_dmg: float = tower._get_effective_damage()
	var tick_dmg: float = base_dmg * continuous_tick
	var effects: Array = _build_effects()
	var gp: bool = tower.buff_giant_pierce

	var enemies: Array
	if _lv(1) >= 2 and is_instance_valid(tower._current_target):
		var dir: Vector2 = (tower._current_target.global_position - tower.global_position).normalized()
		var half_angle: float = deg_to_rad(P1_CONE[_lv(1)] / 2.0)
		enemies = _get_enemies_in_cone(tower.global_position, dir, tower._effective_range, half_angle)
	else:
		var range_enemies: Array = tower.get_enemies_in_range()
		enemies = [range_enemies[0]] if range_enemies.size() > 0 else []

	for enemy in enemies:
		if is_instance_valid(enemy):
			var fd: float = _apply_dmg_mods(tick_dmg, enemy)
			deal_damage(enemy, fd, effects, gp)
			_on_hit_marked_effects(enemy)


# ═══════════════════════════════════════════════════════════════════════
# 效果构建
# ═══════════════════════════════════════════════════════════════════════
func _build_effects() -> Array:
	# 注意：标记(MARK)不在此处添加，伤害结算后单独施加，确保辣椒自身不受标记加成
	var effects: Array = []
	if _lv(0) >= 1:
		_burn_fx.damage_per_tick = P0_BURN_DPS[_lv(0)]
		_burn_fx.duration = P0_BURN_DUR[_lv(0)]
		effects.append(_burn_fx)
	if _lv(2) >= 3:
		_slow_fx.potency = P2_SLOW_POT[_lv(2)]
		_slow_fx.duration = 0.5 if _lv(2) >= 5 else 1.5
		effects.append(_slow_fx)
	return effects


## 攻击已标记敌人时的附加效果（辣椒自身不施加标记，只对已标记目标生效）
func _on_hit_marked_effects(enemy: Area2D) -> void:
	if _lv(3) < 1 or not is_instance_valid(enemy):
		return
	if not _is_marked(enemy):
		return
	# P3 T3+: 攻击标记目标时，标记扩散至相邻敌人
	if _lv(3) >= 3:
		_spread_existing_mark(enemy)
	# P3 T4+: 攻击标记目标附加减速20%
	if _lv(3) >= 4 and enemy.has_method("apply_effect"):
		enemy.apply_effect(_mark_slow_fx)


# ═══════════════════════════════════════════════════════════════════════
# 锥形检测
# ═══════════════════════════════════════════════════════════════════════
func _get_enemies_in_cone(origin: Vector2, dir: Vector2, max_range: float, half_angle: float) -> Array:
	var result: Array = []
	var r2: float = max_range * max_range
	for enemy in GameManager.get_all_enemies():
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		var ed = enemy.get("enemy_data")
		if ed and ed.get("is_flying"):
			continue
		var to_enemy: Vector2 = enemy.global_position - origin
		if to_enemy.length_squared() > r2:
			continue
		var to_dir: Vector2 = to_enemy.normalized()
		if absf(dir.angle_to(to_dir)) <= half_angle:
			result.append(enemy)
	return result


# ═══════════════════════════════════════════════════════════════════════
# 伤害修正
# ═══════════════════════════════════════════════════════════════════════
func _apply_dmg_mods(base_dmg: float, enemy: Area2D) -> float:
	var d: float = base_dmg
	# P0 T4: 对大型 +50%
	if _lv(0) >= 4:
		var ed = enemy.get("enemy_data")
		if ed and ed.get("is_giant"):
			d *= 1.5
	# P3: 攻击已被标记的敌人伤害加成（辣椒自身不施加标记）
	if _lv(3) >= 1 and _is_marked(enemy):
		d *= (1.0 + P3_MARK[_lv(3)])   # +12%→+30%
		# P3 T2+: 标记目标同时在燃烧时再+10%
		if _lv(3) >= 2 and _is_burning(enemy):
			d *= 1.1
	return d


func _is_burning(enemy: Area2D) -> bool:
	if not is_instance_valid(enemy):
		return false
	var effs = enemy.get("_active_effects")
	if effs:
		for eff in effs:
			if eff.get("type") == BulletEffect.Type.BURN:
				return true
	return false


func _is_marked(enemy: Area2D) -> bool:
	if not is_instance_valid(enemy):
		return false
	var effs = enemy.get("_active_effects")
	if effs:
		for eff in effs:
			if eff.get("type") == BulletEffect.Type.MARK:
				return true
	return false


# ═══════════════════════════════════════════════════════════════════════
# P3 T3+: 攻击标记目标时，将已有标记扩散到相邻敌人
# ═══════════════════════════════════════════════════════════════════════
func _spread_existing_mark(source: Area2D) -> void:
	if not is_instance_valid(source):
		return
	# 从源敌人身上读取现有标记效果的参数
	var mark_potency: float = 0.0
	var mark_duration: float = 4.0
	var effs = source.get("_active_effects")
	if effs:
		for eff in effs:
			if eff.get("type") == BulletEffect.Type.MARK:
				mark_potency = eff.get("potency", 0.10)
				mark_duration = eff.get("remaining", 4.0)
				break
	if mark_potency <= 0.0:
		return
	# 复制标记到120px内相邻敌人
	_mark_fx.potency = mark_potency
	_mark_fx.duration = mark_duration
	for enemy in GameManager.get_all_enemies():
		if enemy == source or not is_instance_valid(enemy) or enemy.finished:
			continue
		if enemy.global_position.distance_to(source.global_position) <= 120.0:
			if enemy.has_method("apply_effect"):
				enemy.apply_effect(_mark_fx)
			break   # 只扩散到1个相邻目标


# ═══════════════════════════════════════════════════════════════════════
# P3 T5 标记增伤光环（范围内炮台攻击标记敌人+30%伤）
# ═══════════════════════════════════════════════════════════════════════
func _refresh_mark_aura() -> void:
	# 先移除旧buff
	_clear_mark_aura()
	# 获取范围内的友方炮台
	var nearby: Array = tower.get_nearby_towers(tower._effective_range)
	for t in nearby:
		if not is_instance_valid(t) or t == tower:
			continue
		t.buff_mark_bonus = 0.30
		# 添加到 buff_sources（Array[Dictionary] 格式）
		t.buff_sources.append({
			"source": tower,
			"emoji": "🌶️",
			"name": "辣椒标记",
			"type": "mark_bonus",
			"value": 0.30
		})
		_aura_buffed_towers.append(t)


func _clear_mark_aura() -> void:
	for t in _aura_buffed_towers:
		if is_instance_valid(t):
			t.buff_mark_bonus = maxf(t.buff_mark_bonus - 0.30, 0.0)
			# 从 buff_sources 中移除辣椒相关的
			var to_remove: Array = []
			for i in t.buff_sources.size():
				var bs: Dictionary = t.buff_sources[i]
				if bs.get("type") == "mark_bonus" and bs.get("source") == tower:
					to_remove.append(i)
			for i in range(to_remove.size() - 1, -1, -1):
				t.buff_sources.remove_at(to_remove[i])
	_aura_buffed_towers.clear()
