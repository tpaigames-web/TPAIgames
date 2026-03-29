extends Area2D

## 敌人召唤子单位时发出（WaveManager 监听此信号生成新敌人）
signal want_spawn(enemy_type: String, count: int, path_progress: float)

@export var enemy_data: Resource

var finished:         bool  = false
var hp:               int   = 50
var speed:            float = 0.0
var is_summoned:      bool  = false   ## 召唤单位不掉金币

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
## 死亡标记：防止 die() 被多个伤害源在同帧重复调用导致金币/经验翻倍
var _dead: bool = false

## ── 英雄地形效果（由守卫者领域能力脚本施加）──────────────────────────────
## 地形减速（与子弹 SLOW 效果分开计算）
var terrain_slow: float = 0.0
## 嘲讽目标（守卫者节点引用，有效时敌人暂停路径移动、朝目标移动）
var taunt_target: Node2D = null
## 地形护甲减免比例（0.10 = 降低 10%）
var terrain_armor_reduction: float = 0.0
## debuff 护甲减免（水压管道腐蚀等，与地形减免叠加）
var debuff_armor_reduction: float = 0.0
var _debuff_lbl: Label = null
## debuff 显示脏标记（仅变化时重建文本，避免每帧字符串拼接）
var _effects_dirty: bool = false
## 视觉平滑：上一帧的视觉位置（用于 lerp 补帧）
var _visual_pos: Vector2 = Vector2.ZERO
## 受击视觉 Tween（防止冲突）
var _hit_tween: Tween = null
var _knockback_tween: Tween = null

## 护甲等级对应的伤害减免比例（Lv0~Lv4）
const ARMOR_REDUCTION: Array[float] = [0.0, 0.15, 0.35, 0.55, 0.75]

@onready var _hp_bar:     ProgressBar = $HPBar
@onready var _shield_bar: ProgressBar = $ShieldBar
@onready var _armor_lbl:  Label       = $ArmorLabel


func _ready() -> void:
	add_to_group("enemy")
	_update_hp_bar()
	_update_armor_display()
	# 创建 debuff 图标标签
	_debuff_lbl = Label.new()
	_debuff_lbl.position = Vector2(-50, -95)
	_debuff_lbl.add_theme_font_size_override("font_size", 18)
	_debuff_lbl.z_index = 10
	add_child(_debuff_lbl)  # apply_enemy_data() 在 add_child 前调用，_ready 触发后补初始化


## 血条颜色缓存（0=绿 1=黄 2=红），避免每次受伤都设置 modulate 触发 UI 重绘
var _hp_color_state: int = 0
const _HP_COLORS: Array[Color] = [
	Color(0.2, 1.0, 0.2),   # 绿 > 50%
	Color(1.0, 0.85, 0.0),  # 黄 25%-50%
	Color(1.0, 0.2, 0.2),   # 红 < 25%
]

func _update_hp_bar() -> void:
	if not is_instance_valid(_hp_bar) or not enemy_data:
		return
	if enemy_data.max_hp <= 0:
		return
	_hp_bar.max_value = enemy_data.max_hp
	_hp_bar.value     = max(hp, 0)
	var pct: float = float(max(hp, 0)) / float(enemy_data.max_hp)
	var new_state: int = 0 if pct > 0.5 else (1 if pct > 0.25 else 2)
	if new_state != _hp_color_state:
		_hp_color_state = new_state
		_hp_bar.modulate = _HP_COLORS[new_state]


func _update_shield_bar() -> void:
	if not is_instance_valid(_shield_bar) or not enemy_data:
		return
	if _shield_active:
		_shield_bar.visible   = true
		_shield_bar.max_value = int(enemy_data.max_hp * enemy_data.shield_threshold)
		_shield_bar.value     = max(_shield_absorbed, 0)
	else:
		_shield_bar.visible = false


func apply_enemy_data() -> void:
	if not enemy_data:
		return
	hp    = enemy_data.max_hp
	speed = enemy_data.move_speed

	var target: float = enemy_data.sprite_display_size if enemy_data.sprite_display_size > 0.0 else 100.0

	if enemy_data.sprite_frames:
		# ── 动画帧模式（优先） ──
		$AnimSprite.sprite_frames = enemy_data.sprite_frames
		$AnimSprite.visible = true
		$Sprite2D.visible   = false
		$EmojiLabel.visible = false
		# 自动缩放至约 80px
		var anim_name: String = "default"
		if enemy_data.sprite_frames.has_animation(anim_name):
			var frame_tex: Texture2D = enemy_data.sprite_frames.get_frame_texture(anim_name, 0)
			if frame_tex:
				var tex_size: Vector2 = frame_tex.get_size()
				var max_dim: float = max(tex_size.x, tex_size.y)
				if max_dim > 0:
					var s: float = target / max_dim
					$AnimSprite.scale = Vector2(s, s)
		$AnimSprite.play("default")
		# 应用贴图朝向偏移
		$AnimSprite.rotation = deg_to_rad(enemy_data.sprite_rotation_offset)
	elif enemy_data.sprite_texture:
		# ── 静态贴图模式 ──
		$Sprite2D.texture = enemy_data.sprite_texture
		$Sprite2D.visible = true
		$AnimSprite.visible = false
		$EmojiLabel.visible = false
		var tex_size: Vector2 = enemy_data.sprite_texture.get_size()
		var max_dim: float = max(tex_size.x, tex_size.y)
		if max_dim > 0:
			var s: float = target / max_dim
			$Sprite2D.scale = Vector2(s, s)
		# 应用贴图朝向偏移
		$Sprite2D.rotation = deg_to_rad(enemy_data.sprite_rotation_offset)
	else:
		# ── Emoji 后备模式 ──
		$Sprite2D.visible   = false
		$AnimSprite.visible  = false
		$EmojiLabel.text     = enemy_data.display_emoji
		$EmojiLabel.visible  = true
	_update_hp_bar()
	_update_armor_display()


func _update_armor_display() -> void:
	if not is_instance_valid(_armor_lbl):
		return
	if enemy_data and enemy_data.armor > 0:
		_armor_lbl.text    = "🛡️" + str(enemy_data.armor)
		_armor_lbl.visible = true
	else:
		_armor_lbl.visible = false


func _process(delta: float) -> void:
	if finished:
		return

	_update_speed(delta)
	_update_spawn(delta)
	_process_effects(delta)
	_process_regen(delta)
	_update_debuff_display()

	# 血条/护盾条始终水平固定在敌人头顶，不随 PathFollow2D 旋转
	# 只在旋转角度变化时才重新计算（避免每帧三角函数）
	var neg_rot: float = -global_rotation
	if is_instance_valid(_hp_bar):
		if not is_equal_approx(_hp_bar.rotation, neg_rot):
			_hp_bar.rotation = neg_rot
			_hp_bar.position = Vector2(-30.0, -54.0).rotated(neg_rot)
	if is_instance_valid(_shield_bar) and _shield_bar.visible:
		if not is_equal_approx(_shield_bar.rotation, neg_rot):
			_shield_bar.rotation = neg_rot
			_shield_bar.position = Vector2(-30.0, -65.0).rotated(neg_rot)
	if is_instance_valid(_armor_lbl) and _armor_lbl.visible:
		if not is_equal_approx(_armor_lbl.rotation, neg_rot):
			_armor_lbl.rotation = neg_rot
			_armor_lbl.position = Vector2(-30.0, -76.0).rotated(neg_rot)

	var parent = get_parent()
	if parent is PathFollow2D:
		if parent.progress_ratio >= 1.0:
			_reach_goal()
			return
		parent.progress += _get_effective_speed() * delta
		if parent.progress_ratio >= 1.0:
			_reach_goal()
			return

		# 视觉平滑：精灵 lerp 跟随逻辑位置（消除高速下的跳帧感）
		var spr: Node = $Sprite2D if $Sprite2D.visible else ($AnimSprite if has_node("AnimSprite") and $AnimSprite.visible else null)
		if spr:
			var target_pos: Vector2 = global_position
			if _visual_pos == Vector2.ZERO:
				_visual_pos = target_pos
			else:
				_visual_pos = _visual_pos.lerp(target_pos, minf(15.0 * delta, 1.0))
			spr.global_position = _visual_pos


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
		_show_spawn_vfx()


# ── 状态效果处理 ──────────────────────────────────────────────────────

## 获取受控制效果（减速 / 定身）影响后的实际移动速度
func _get_effective_speed() -> float:
	for eff in _active_effects:
		if eff.type == BulletEffect.Type.STUN:
			return 0.0
	var s: float = speed
	# 子弹减速效果
	for eff in _active_effects:
		if eff.type == BulletEffect.Type.SLOW:
			s *= (1.0 - eff.potency)
	# 地形减速（守卫者领域）
	if terrain_slow > 0.0:
		s *= (1.0 - terrain_slow)
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
			_effects_dirty = true
		i -= 1
	_check_berserk()


## 再生：每帧回复 HP（毒蛙等）
var _regen_accumulator: float = 0.0
func _process_regen(delta: float) -> void:
	if not enemy_data or enemy_data.regen_per_second <= 0.0:
		return
	if hp <= 0 or hp >= enemy_data.max_hp:
		return
	_regen_accumulator += enemy_data.regen_per_second * delta
	if _regen_accumulator >= 1.0:
		var heal: int = int(_regen_accumulator)
		_regen_accumulator -= float(heal)
		hp = mini(hp + heal, enemy_data.max_hp)
		_update_hp_bar()


## DoT tick 伤害结算（绕过护盾，直接扣 HP）
func _apply_dot_tick(dmg: float) -> void:
	if dmg <= 0.0:
		return
	hp -= int(dmg)
	_update_hp_bar()
	if hp <= 0:
		die()


## 子弹命中入口（由 Bullet._on_hit 调用）
func take_damage_from_bullet(dmg: float, bullet_effects: Array, pierce_giant: bool = false, armor_penetration: int = 0, ignore_dodge: bool = false) -> void:
	# 全局闪避检查（ignore_dodge 无视闪避）
	if not ignore_dodge and enemy_data and randf() < enemy_data.attack_immunity_chance:
		return

	# 标记效果：受到额外伤害加成
	var dmg_mult: float = 1.0
	for eff in _active_effects:
		if eff.type == BulletEffect.Type.MARK:
			dmg_mult += eff.potency

	var final_dmg: float = dmg * dmg_mult

	# 护甲减伤（护穿降低有效护甲等级）
	if enemy_data and enemy_data.armor > 0:
		var effective_armor: int = maxi(enemy_data.armor - armor_penetration, 0)
		if effective_armor > 0:
			var idx: int = mini(effective_armor, ARMOR_REDUCTION.size() - 1)
			var reduction: float = ARMOR_REDUCTION[idx]
			# 护甲减免（地形 + debuff 叠加）
			var total_armor_red: float = terrain_armor_reduction + debuff_armor_reduction
			if total_armor_red > 0.0:
				reduction = maxf(reduction - total_armor_red, 0.0)
			final_dmg *= (1.0 - reduction)

	take_damage(final_dmg)

	# 施加子弹携带的效果
	for effect in bullet_effects:
		_try_apply_effect(effect, pierce_giant)


## 公开接口：施加单个效果（供地形能力等外部调用）
func apply_effect(effect: BulletEffect, pierce_giant: bool = false) -> void:
	_try_apply_effect(effect, pierce_giant)


## 尝试施加单个效果（检查免疫 → 加入激活列表）
func _try_apply_effect(effect: BulletEffect, pierce_giant: bool = false) -> void:
	var t: int         = effect.effect_type
	var is_control: bool = (t == BulletEffect.Type.SLOW or t == BulletEffect.Type.STUN)
	var is_dot: bool     = (t == BulletEffect.Type.BURN or t == BulletEffect.Type.POISON or t == BulletEffect.Type.BLEED)

	# 控制免疫检查
	if is_control and enemy_data:
		if enemy_data.is_control_immune:
			return
		if enemy_data.shield_grants_control_immune and _shield_active:
			return
		if enemy_data.is_giant and not effect.affects_giant and not pierce_giant:
			return

	# DoT 免疫检查
	if is_dot and enemy_data and enemy_data.is_dot_immune:
		return

	# 叠加规则：BLEED 可叠加层数（上限 8 层），SLOW/MARK 取最大 potency，其余刷新持续时间
	if t != BulletEffect.Type.BLEED:
		for existing in _active_effects:
			if existing.type == t:
				existing.remaining = maxf(existing.remaining, effect.duration)
				# SLOW 和 MARK 取最大 potency（多塔配合取最强效果）
				if t == BulletEffect.Type.SLOW or t == BulletEffect.Type.MARK:
					existing.potency = maxf(existing.potency, effect.potency)
				else:
					existing.potency = effect.potency
				return
	else:
		# BLEED 叠加上限：超过 8 层时替换剩余时间最短的一层
		var bleed_count: int = 0
		var oldest_idx: int = -1
		var oldest_rem: float = INF
		for i in _active_effects.size():
			if _active_effects[i].type == BulletEffect.Type.BLEED:
				bleed_count += 1
				if _active_effects[i].remaining < oldest_rem:
					oldest_rem = _active_effects[i].remaining
					oldest_idx = i
		if bleed_count >= 8 and oldest_idx >= 0:
			_active_effects.remove_at(oldest_idx)

	_active_effects.append({
		type            = t,
		remaining       = effect.duration,
		potency         = effect.potency,
		damage_per_tick = effect.damage_per_tick,
		tick_interval   = effect.tick_interval,
		tick_timer      = 0.0,
	})
	_effects_dirty = true


## 狂暴检查：HP 低于阈值时一次性触发速度提升
func _check_berserk() -> void:
	if _berserk_triggered or not enemy_data or not enemy_data.is_berserk:
		return
	if enemy_data.max_hp > 0 and float(hp) / float(enemy_data.max_hp) < enemy_data.berserk_threshold:
		_berserk_triggered = true
		speed *= (1.0 + enemy_data.berserk_speed_bonus)


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
	_update_shield_bar()
	_check_shield_trigger()

	if hp <= 0:
		die()
	else:
		_flash_hit(final_dmg)


## 检查是否触发护盾（HP 降至阈值时激活）
func _check_shield_trigger() -> void:
	if not enemy_data or enemy_data.shield_threshold <= 0.0:
		return
	if _shield_active:
		return
	if enemy_data.max_hp > 0 and float(hp) / float(enemy_data.max_hp) <= enemy_data.shield_threshold:
		_shield_active   = true
		_shield_absorbed = int(enemy_data.max_hp * enemy_data.shield_threshold)
		_update_shield_bar()  # 立即显示护盾条


# ── 死亡 ──────────────────────────────────────────────────────────────
@export var death_duration: float = 0.35

func die() -> void:
	if _dead:
		return
	_dead = true
	if enemy_data and not is_summoned:
		GameManager.add_gold(enemy_data.gold_reward)
		UserManager.add_xp(enemy_data.xp_reward)
	elif not is_summoned:
		UserManager.add_xp(5)
	_play_death_anim()

func _play_death_anim() -> void:
	# 禁用碰撞和移动，防止死亡期间再被攻击
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	speed = 0.0
	# 隐藏血条
	if is_instance_valid(_hp_bar):
		_hp_bar.visible = false
	if is_instance_valid(_shield_bar):
		_shield_bar.visible = false
	if is_instance_valid(_debuff_lbl):
		_debuff_lbl.visible = false
	if is_instance_valid(_armor_lbl):
		_armor_lbl.visible = false
	# 闪白 → 缩小 + 淡出
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(3, 3, 3, 1), 0.06)  # 闪白
	tw.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.06)  # 恢复
	tw.tween_property(self, "scale", Vector2(0.3, 0.3), death_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(self, "modulate:a", 0.0, death_duration)
	tw.tween_callback(queue_free)

## 召唤敌人时的浮动特效
func _show_spawn_vfx() -> void:
	var lbl := Label.new()
	var count: int = enemy_data.spawn_count if enemy_data else 1
	lbl.text = "🌀 +%d" % count
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.modulate = Color(0.4, 0.9, 1.0)
	lbl.z_index = 10
	get_tree().current_scene.add_child(lbl)
	lbl.global_position = global_position + Vector2(-30, -80)   # 场景空间定位
	var tw := lbl.create_tween()   # 绑定到 lbl，lbl 被释放时 tween 自动停止
	tw.tween_property(lbl, "position:y", lbl.position.y - 60, 1.0)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
	tw.tween_callback(lbl.queue_free)

## 仅在效果列表变化时更新头顶 debuff 图标显示
func _update_debuff_display() -> void:
	if not is_instance_valid(_debuff_lbl):
		return
	# 检查是否有变化（效果脏标记 或 减甲状态变化）
	var has_armor_debuff: bool = debuff_armor_reduction > 0.0
	if not _effects_dirty and not has_armor_debuff and _debuff_lbl.text == "":
		return
	if not _effects_dirty and _debuff_lbl.text != "":
		# 检查减甲是否刚消失
		if not has_armor_debuff and "[腐蚀]" in _debuff_lbl.text:
			_effects_dirty = true
		elif has_armor_debuff and "[腐蚀]" not in _debuff_lbl.text:
			_effects_dirty = true
	if not _effects_dirty:
		return
	_effects_dirty = false
	var seen: Dictionary = {}
	var text := ""
	for eff in _active_effects:
		var t: int = eff.type
		if seen.has(t):
			continue
		seen[t] = true
		match t:
			BulletEffect.Type.SLOW:    text += "[减速]"
			BulletEffect.Type.BURN:    text += "[燃烧]"
			BulletEffect.Type.POISON:  text += "[中毒]"
			BulletEffect.Type.BLEED:   text += "[流血]"
			BulletEffect.Type.STUN:    text += "[定身]"
			BulletEffect.Type.MARK:    text += "[标记]"
	# 腐蚀减甲（不在 _active_effects 中，单独检查）
	if debuff_armor_reduction > 0.0:
		text += "[腐蚀]"
	_debuff_lbl.text = text


## 受击红闪 + 大伤害缩放脉冲
func _flash_hit(dmg: int) -> void:
	if _dead or finished:
		return
	# 终止上一个受击 Tween（避免叠加冲突）
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_tween = create_tween()
	# 红闪
	_hit_tween.tween_property(self, "modulate", Color(1.5, 0.3, 0.3, 1.0), 0.0)
	_hit_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)
	# 大伤害缩放脉冲（> 最大血量 10%）
	if enemy_data and dmg > enemy_data.max_hp * 0.1:
		_hit_tween.parallel().tween_property(self, "scale", Vector2(1.15, 1.15), 0.05)
		_hit_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)


## 击退：将敌人沿路径后推（Tween 动画版）
func apply_knockback(distance: float) -> void:
	# 护盾免控期间免疫击退
	if _shield_active and enemy_data and enemy_data.shield_grants_control_immune:
		return
	# 控制免疫敌人免疫击退
	if enemy_data and enemy_data.is_control_immune:
		return
	if enemy_data and enemy_data.is_giant:
		distance *= 0.3
	var parent = get_parent()
	if parent is PathFollow2D:
		var target_progress: float = maxf(0.0, parent.progress - distance)
		# 终止旧击退 Tween
		if _knockback_tween and _knockback_tween.is_valid():
			_knockback_tween.kill()
		_knockback_tween = create_tween()
		_knockback_tween.tween_property(parent, "progress", target_progress, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
