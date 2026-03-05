extends Area2D

## 敌人召唤子单位时发出（WaveManager 监听此信号生成新敌人）
signal want_spawn(enemy_type: String, count: int, path_progress: float)

@export var enemy_data: Resource

var finished:         bool  = false
var hp:               int   = 50
var speed:            float = 0.0

## 冲锋计时（野猪 / 装甲野猪）
var _charge_timer:    float = 0.0
## 召唤计时（蚁后 / 乌鸦王 / 森林之王）
var _spawn_timer:     float = 0.0

## 护盾状态（森林之王）
var _shield_active:   bool  = false
var _shield_absorbed: int   = 0

## 激活的状态效果列表
## 每项格式：{type: int, remaining: float, potency: float,
##             damage_per_tick: float, tick_interval: float, tick_timer: float}
var _active_effects:    Array[Dictionary] = []

## 狂暴状态是否已触发（避免重复）
var _berserk_triggered: bool = false

@onready var _hp_bar: ProgressBar = $HPBar


func _ready() -> void:
	add_to_group("enemy")
	_update_hp_bar()  # apply_enemy_data() 在 add_child 前调用，_ready 触发后补初始化


func _update_hp_bar() -> void:
	if not is_instance_valid(_hp_bar) or not enemy_data:
		return
	_hp_bar.max_value = enemy_data.max_hp
	_hp_bar.value     = max(hp, 0)
	var pct: float = float(max(hp, 0)) / float(enemy_data.max_hp)
	if pct > 0.5:
		_hp_bar.modulate = Color(0.2, 1.0, 0.2)
	elif pct > 0.25:
		_hp_bar.modulate = Color(1.0, 0.85, 0.0)
	else:
		_hp_bar.modulate = Color(1.0, 0.2, 0.2)


func apply_enemy_data() -> void:
	if not enemy_data:
		return
	hp    = enemy_data.max_hp
	speed = enemy_data.move_speed

	if enemy_data.sprite_texture:
		$Sprite2D.texture = enemy_data.sprite_texture
		$Sprite2D.visible = true
		$EmojiLabel.visible = false
		# 自动缩放贴图至约 80px（与路径宽度匹配）
		var target: float = 80.0
		var tex_size: Vector2 = enemy_data.sprite_texture.get_size()
		var max_dim: float = max(tex_size.x, tex_size.y)
		if max_dim > 0:
			var s: float = target / max_dim
			$Sprite2D.scale = Vector2(s, s)
	else:
		$Sprite2D.visible  = false
		$EmojiLabel.text   = enemy_data.display_emoji
		$EmojiLabel.visible = true
	_update_hp_bar()


func _process(delta: float) -> void:
	if finished:
		return

	_update_speed(delta)
	_update_spawn(delta)
	_process_effects(delta)

	# 血条始终水平固定在敌人头顶，不随 PathFollow2D 旋转
	# Control 节点无 global_rotation/global_position，用局部 position/rotation 抵消父节点旋转
	if is_instance_valid(_hp_bar):
		_hp_bar.position = Vector2(-30.0, -54.0).rotated(-global_rotation)
		_hp_bar.rotation = -global_rotation

	var parent = get_parent()
	if parent is PathFollow2D:
		if parent.progress_ratio >= 1.0:
			_reach_goal()
			return
		parent.progress += _get_effective_speed() * delta
		if parent.progress_ratio >= 1.0:
			_reach_goal()


# ── 冲锋逻辑 ──────────────────────────────────────────────────────────
func _update_speed(delta: float) -> void:
	if not enemy_data or enemy_data.charge_duration <= 0.0:
		return
	_charge_timer += delta
	if _charge_timer <= enemy_data.charge_duration:
		speed = enemy_data.move_speed * enemy_data.charge_speed_multiplier
	else:
		speed = enemy_data.move_speed   # 冲锋结束，恢复正常速度


# ── 召唤逻辑 ──────────────────────────────────────────────────────────
func _update_spawn(delta: float) -> void:
	if not enemy_data or enemy_data.spawn_interval <= 0.0:
		return
	_spawn_timer += delta
	if _spawn_timer >= enemy_data.spawn_interval:
		_spawn_timer = 0.0
		var parent = get_parent()
		var prog: float = parent.progress if parent is PathFollow2D else 0.0
		want_spawn.emit(enemy_data.spawn_enemy_type, enemy_data.spawn_count, prog)


# ── 状态效果处理 ──────────────────────────────────────────────────────

## 获取受控制效果（减速 / 定身）影响后的实际移动速度
func _get_effective_speed() -> float:
	for eff in _active_effects:
		if eff.type == BulletEffect.Type.STUN:
			return 0.0
	var s: float = speed
	for eff in _active_effects:
		if eff.type == BulletEffect.Type.SLOW:
			s *= (1.0 - eff.potency)
	return max(s, 0.0)


## 每帧处理所有激活效果（倒计时、DoT tick）
func _process_effects(delta: float) -> void:
	var i: int = _active_effects.size() - 1
	while i >= 0:
		var eff: Dictionary = _active_effects[i]
		eff.remaining -= delta
		# DoT tick（BURN / POISON / BLEED）
		var tick_iv: float = eff.get("tick_interval", 0.0)
		if tick_iv > 0.0:
			eff.tick_timer += delta
			if eff.tick_timer >= tick_iv:
				eff.tick_timer -= tick_iv
				_apply_dot_tick(eff.get("damage_per_tick", 0.0))
		if eff.remaining <= 0.0:
			_active_effects.remove_at(i)
		i -= 1
	_check_berserk()


## DoT tick 伤害结算（绕过护盾，直接扣 HP）
func _apply_dot_tick(dmg: float) -> void:
	if dmg <= 0.0:
		return
	hp -= int(dmg)
	_update_hp_bar()
	if hp <= 0:
		die()


## 子弹命中入口（由 Bullet._on_hit 调用）
func take_damage_from_bullet(dmg: float, bullet_effects: Array) -> void:
	# 全局闪避检查
	if enemy_data and randf() < enemy_data.attack_immunity_chance:
		return

	# 标记效果：受到额外伤害加成
	var dmg_mult: float = 1.0
	for eff in _active_effects:
		if eff.type == BulletEffect.Type.MARK:
			dmg_mult += eff.potency

	take_damage(dmg * dmg_mult)

	# 施加子弹携带的效果
	for effect in bullet_effects:
		_try_apply_effect(effect)


## 尝试施加单个效果（检查免疫 → 加入激活列表）
func _try_apply_effect(effect: BulletEffect) -> void:
	var t: int         = effect.effect_type
	var is_control: bool = (t == BulletEffect.Type.SLOW or t == BulletEffect.Type.STUN)
	var is_dot: bool     = (t == BulletEffect.Type.BURN or t == BulletEffect.Type.POISON or t == BulletEffect.Type.BLEED)

	# 控制免疫检查
	if is_control and enemy_data:
		if enemy_data.is_control_immune:
			return
		if enemy_data.is_giant and not effect.affects_giant:
			return

	# DoT 免疫检查
	if is_dot and enemy_data and enemy_data.is_dot_immune:
		return

	# 叠加规则：BLEED 可叠加层数，其余刷新持续时间
	if t != BulletEffect.Type.BLEED:
		for existing in _active_effects:
			if existing.type == t:
				existing.remaining = effect.duration
				existing.potency   = effect.potency
				return

	_active_effects.append({
		type            = t,
		remaining       = effect.duration,
		potency         = effect.potency,
		damage_per_tick = effect.damage_per_tick,
		tick_interval   = effect.tick_interval,
		tick_timer      = 0.0,
	})


## 狂暴检查：HP < 30% 时一次性触发速度提升50%
func _check_berserk() -> void:
	if _berserk_triggered or not enemy_data or not enemy_data.is_berserk:
		return
	if float(hp) / float(enemy_data.max_hp) < 0.3:
		_berserk_triggered = true
		speed *= 1.5


# ── 到达终点 ──────────────────────────────────────────────────────────
func _reach_goal() -> void:
	if finished:
		return
	finished = true
	var dmg: int = enemy_data.damage_to_player if enemy_data else 1
	GameManager.damage_player(dmg)
	queue_free()


# ── 受到伤害 ──────────────────────────────────────────────────────────
func take_damage(amount: float) -> void:
	# 狐狸首领：按概率免疫本次攻击（旧兼容路径，新代码请用 take_damage_from_bullet）
	if enemy_data and randf() < enemy_data.attack_immunity_chance:
		return

	var final_dmg: int = int(amount)

	# 护盾吸收（森林之王）
	if _shield_active and _shield_absorbed > 0:
		var absorbed: int = min(final_dmg, _shield_absorbed)
		_shield_absorbed -= absorbed
		final_dmg        -= absorbed
		if _shield_absorbed <= 0:
			_shield_active = false

	hp -= final_dmg
	_update_hp_bar()
	_check_shield_trigger()

	if hp <= 0:
		die()


## 检查是否触发护盾（HP 降至阈值时激活）
func _check_shield_trigger() -> void:
	if not enemy_data or enemy_data.shield_threshold <= 0.0:
		return
	if _shield_active:
		return
	if float(hp) / float(enemy_data.max_hp) <= enemy_data.shield_threshold:
		_shield_active   = true
		_shield_absorbed = int(enemy_data.max_hp * enemy_data.shield_threshold)


# ── 死亡 ──────────────────────────────────────────────────────────────
func die() -> void:
	if enemy_data:
		GameManager.add_gold(enemy_data.gold_reward)
		UserManager.add_xp(enemy_data.xp_reward)
	else:
		UserManager.add_xp(5)
	queue_free()
