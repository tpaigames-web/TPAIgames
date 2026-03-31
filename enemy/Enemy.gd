extends Area2D

## 敌人召唤子单位时发出（WaveManager 监听此信号生成新敌人）
signal want_spawn(enemy_type: String, count: int, path_progress: float)
signal treasure_killed()    ## 宝箱敌人被击杀（掉落奖励）
signal treasure_escaped()   ## 宝箱敌人逃走（无奖励）

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

## ── 地鼠挖洞系统 ──────────────────────────────────────────────────────
var is_burrowed: bool = false        ## 炮台不可选中标志
var _mole_state: int = 0             ## 0=run, 1=jumping_in, 2=burrowed, 3=emerging
const MOLE_TRAP_DETECT_RANGE: float = 180.0  ## 检测陷阱的前方距离
## 地洞节点列表存储在 GameManager.burrow_holes（全局共享）
## 地洞纹理（preload 确保 Android 可用）
const DIRT_HOLE_ENTER_TEX = preload("res://assets/sprites/enemy/Groundhog/GroundHog_Dirt_02.png")  ## 入口洞
const DIRT_HOLE_EXIT_TEX  = preload("res://assets/sprites/enemy/Groundhog/GroundHog_Dirt_16.png")  ## 出口洞
const DIRT_TRAIL_TEX      = preload("res://assets/sprites/enemy/Groundhog/GroundHog_Dirt_08.png")  ## 移动痕迹
## 地下移动痕迹间隔
var _trail_timer: float = 0.0
const TRAIL_INTERVAL: float = 0.3  ## 每0.3秒留一个痕迹

## ── 毒蛙跳跃系统 ──────────────────────────────────────────────────────
var _toad_state: int = 0         ## 0=jumping(移动中), 1=idle(停下回血)
var _toad_timer: float = 0.0
const TOAD_JUMP_DURATION: float = 1.0   ## 跳跃动画时长（115速×1.0s≈120px）
const TOAD_IDLE_DURATION: float = 1.0   ## 停下时间（1秒，期间回血）
var _toad_is_idle: bool = false          ## 停下标志（用于增强回血）

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
		# 遍历所有动画所有帧取最大尺寸，确保缩放固定不抖动
		var max_dim: float = 0.0
		var sf: SpriteFrames = enemy_data.sprite_frames
		for anim in sf.get_animation_names():
			for fi in sf.get_frame_count(anim):
				var ftex: Texture2D = sf.get_frame_texture(anim, fi)
				if ftex:
					var sz: Vector2 = ftex.get_size()
					max_dim = maxf(max_dim, maxf(sz.x, sz.y))
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
	# 地鼠挖洞状态机
	if enemy_data and enemy_data.can_bypass_traps:
		_mole_process(delta)
	# 毒蛙跳跃状态机
	if enemy_data and enemy_data.regen_per_second > 0 and enemy_data.is_dot_immune:
		_toad_process(delta)

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
		# 毒蛙停下时不移动
		if not _toad_is_idle:
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


# ── 毒蛙跳跃状态机 ────────────────────────────────────────────────────
func _toad_process(delta: float) -> void:
	_toad_timer += delta
	var anim_spr: AnimatedSprite2D = $AnimSprite

	match _toad_state:
		0:  # JUMPING — 播放跳跃动画，移动中
			if _toad_timer >= TOAD_JUMP_DURATION:
				# 跳完 → 停下
				_toad_state = 1
				_toad_timer = 0.0
				_toad_is_idle = true
				if anim_spr.visible and anim_spr.sprite_frames and anim_spr.sprite_frames.has_animation("idle"):
					anim_spr.play("idle")
		1:  # IDLE — 停下回血
			if _toad_timer >= TOAD_IDLE_DURATION:
				# 回血完 → 继续跳
				_toad_state = 0
				_toad_timer = 0.0
				_toad_is_idle = false
				if anim_spr.visible and anim_spr.sprite_frames and anim_spr.sprite_frames.has_animation("jump"):
					anim_spr.play("jump")
				elif anim_spr.visible and anim_spr.sprite_frames and anim_spr.sprite_frames.has_animation("default"):
					anim_spr.play("default")


# ── 地鼠挖洞状态机 ────────────────────────────────────────────────────
func _mole_process(_delta: float) -> void:
	match _mole_state:
		0:  # RUN — 检测前方是否有陷阱
			if _detect_trap_ahead():
				_mole_start_jump()
		1:  # JUMPING_IN — 等 jump 动画播完（由 animation_finished 信号处理）
			pass
		2:  # BURROWED — 地下移动，定期留痕迹，检测是否离开陷阱区域
			_trail_timer += _delta
			if _trail_timer >= TRAIL_INTERVAL:
				_trail_timer -= TRAIL_INTERVAL
				_create_trail_mark(global_position)
			if not _detect_trap_ahead():
				_mole_start_emerge()
		3:  # EMERGING — 等 emerge 动画播完
			pass


func _detect_trap_ahead() -> bool:
	var my_pos: Vector2 = global_position
	for tower in get_tree().get_nodes_in_group("tower"):
		if not is_instance_valid(tower):
			continue
		var td = tower.get("tower_data")
		if td == null:
			continue
		if not td.get("place_on_path_only"):
			continue
		if tower.get("is_preview"):
			continue
		var dist: float = my_pos.distance_to(tower.global_position)
		if dist < MOLE_TRAP_DETECT_RANGE:
			return true
	return false


var _jump_hole_created: bool = false

func _mole_start_jump() -> void:
	_mole_state = 1
	_jump_hole_created = _find_nearby_hole(global_position, 80.0) != null
	var anim_spr: AnimatedSprite2D = $AnimSprite
	if not anim_spr.visible:
		_mole_enter_burrow()
		return
	if anim_spr.sprite_frames.has_animation("jump"):
		anim_spr.play("jump")
		if not anim_spr.animation_finished.is_connected(_on_jump_finished):
			anim_spr.animation_finished.connect(_on_jump_finished, CONNECT_ONE_SHOT)
		# 持续监听帧变化，在 frame>=2 时创建地洞
		if not _jump_hole_created:
			if not anim_spr.frame_changed.is_connected(_on_jump_frame_changed):
				anim_spr.frame_changed.connect(_on_jump_frame_changed)
	else:
		if not _jump_hole_created:
			_create_burrow_hole(global_position)
		_mole_enter_burrow()


func _on_jump_frame_changed() -> void:
	var anim_spr: AnimatedSprite2D = $AnimSprite
	if anim_spr.animation != "jump":
		# 动画已切换，断开
		if anim_spr.frame_changed.is_connected(_on_jump_frame_changed):
			anim_spr.frame_changed.disconnect(_on_jump_frame_changed)
		return
	if anim_spr.frame >= 2 and not _jump_hole_created:
		_jump_hole_created = true
		_create_burrow_hole(global_position)
		# 地洞已创建，断开监听
		if anim_spr.frame_changed.is_connected(_on_jump_frame_changed):
			anim_spr.frame_changed.disconnect(_on_jump_frame_changed)


func _on_jump_finished() -> void:
	# 确保断开帧监听
	var anim_spr: AnimatedSprite2D = $AnimSprite
	if anim_spr.frame_changed.is_connected(_on_jump_frame_changed):
		anim_spr.frame_changed.disconnect(_on_jump_frame_changed)
	# 如果地洞还没创建（动画太快跳过了frame 2），这里补创建
	if not _jump_hole_created:
		_jump_hole_created = true
		_create_burrow_hole(global_position)
	_mole_enter_burrow()


func _mole_enter_burrow() -> void:
	_mole_state = 2
	is_burrowed = true
	# 隐藏血条等
	if is_instance_valid(_hp_bar): _hp_bar.visible = false
	if is_instance_valid(_shield_bar): _shield_bar.visible = false
	if is_instance_valid(_debuff_lbl): _debuff_lbl.visible = false
	if is_instance_valid(_armor_lbl): _armor_lbl.visible = false
	# 切换到 dirt_move 动画
	var anim_spr: AnimatedSprite2D = $AnimSprite
	if anim_spr.sprite_frames.has_animation("dirt_move"):
		anim_spr.play("dirt_move")


func _mole_start_emerge() -> void:
	_mole_state = 3
	# 在钻出位置创建出口地洞
	_create_exit_hole(global_position)
	var anim_spr: AnimatedSprite2D = $AnimSprite
	if anim_spr.sprite_frames.has_animation("emerge"):
		anim_spr.play("emerge")
		if not anim_spr.animation_finished.is_connected(_on_emerge_finished):
			anim_spr.animation_finished.connect(_on_emerge_finished, CONNECT_ONE_SHOT)
	else:
		_mole_exit_burrow()


func _on_emerge_finished() -> void:
	_mole_exit_burrow()


func _mole_exit_burrow() -> void:
	_mole_state = 0
	is_burrowed = false
	# 恢复血条等
	if is_instance_valid(_hp_bar): _hp_bar.visible = true
	if is_instance_valid(_debuff_lbl): _debuff_lbl.visible = true
	if enemy_data and enemy_data.armor > 0 and is_instance_valid(_armor_lbl):
		_armor_lbl.visible = true
	# 恢复 run 动画
	var anim_spr: AnimatedSprite2D = $AnimSprite
	if anim_spr.sprite_frames.has_animation("run"):
		anim_spr.play("run")
	elif anim_spr.sprite_frames.has_animation("default"):
		anim_spr.play("default")


## 创建入口地洞
func _create_burrow_hole(pos: Vector2) -> void:
	_spawn_ground_sprite(pos, DIRT_HOLE_ENTER_TEX, 120.0)

## 创建出口地洞
func _create_exit_hole(pos: Vector2) -> void:
	_spawn_ground_sprite(pos, DIRT_HOLE_EXIT_TEX, 120.0)

## 创建地下移动痕迹
func _create_trail_mark(pos: Vector2) -> void:
	_spawn_ground_sprite(pos, DIRT_TRAIL_TEX, 100.0)

## 通用：在地面创建一个纹理节点
func _spawn_ground_sprite(pos: Vector2, tex: Texture2D, target_size: float) -> void:
	if tex == null:
		return
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.global_position = pos
	spr.z_index = -1
	var tex_size: Vector2 = tex.get_size()
	if tex_size.x > 0:
		spr.scale = Vector2.ONE * (target_size / max(tex_size.x, tex_size.y))
	var scene := get_tree().current_scene
	var tower_layer = scene.get_node_or_null("TutorialMap/TowerLayer") if scene else null
	if tower_layer:
		tower_layer.add_child(spr)
	elif scene:
		scene.add_child(spr)
	GameManager.burrow_holes.append(spr)


## 查找附近已存在的地洞
func _find_nearby_hole(pos: Vector2, radius: float) -> Node2D:
	for hole in GameManager.burrow_holes:
		if is_instance_valid(hole) and hole.global_position.distance_to(pos) < radius:
			return hole
	return null


## 清除所有地洞 — 由 BattleScene 直接调用 GameManager


# ── 冲锋逻辑 ──────────────────────────────────────────────────────────
func _update_speed(delta: float) -> void:
	if not enemy_data or enemy_data.charge_duration <= 0.0:
		return
	_charge_timer += delta
	if _charge_timer <= enemy_data.charge_duration:
		speed = enemy_data.move_speed * enemy_data.charge_speed_multiplier
	else:
		speed = enemy_data.move_speed   # 冲锋结束，恢复正常速度


# ── 召唤逻辑（动态冷却）──────────────────────────────────────────────
func _update_spawn(delta: float) -> void:
	if not enemy_data or enemy_data.spawn_interval <= 0.0:
		return

	# 计算动态冷却间隔
	var effective_interval: float = _get_spawn_cooldown()

	_spawn_timer += delta
	if _spawn_timer >= effective_interval:
		# 检查场上召唤物上限
		if enemy_data.spawn_max_active > 0:
			var active_count: int = _count_active_summons()
			if active_count >= enemy_data.spawn_max_active:
				return  # 达到上限，不召唤但保留计时器

		_spawn_timer = 0.0
		var parent = get_parent()
		var prog: float = parent.progress if parent is PathFollow2D else 0.0
		want_spawn.emit(enemy_data.spawn_enemy_type, enemy_data.spawn_count, prog)
		_show_spawn_vfx()


## 根据场上召唤物数量计算动态冷却间隔
func _get_spawn_cooldown() -> float:
	var base: float = enemy_data.spawn_interval
	var max_active: int = enemy_data.spawn_max_active if enemy_data.spawn_max_active > 0 else 10
	var active: int = _count_active_summons()

	# 归一化：0.0（无召唤物）→ 1.0（满）
	var ratio: float = clampf(float(active) / float(max_active), 0.0, 1.0)

	# 使用 Curve 资源或默认线性（1.0x → 2.5x）
	var multiplier: float
	if enemy_data.spawn_cooldown_curve:
		multiplier = enemy_data.spawn_cooldown_curve.sample(ratio)
	else:
		multiplier = lerpf(1.0, 2.5, ratio)

	return base * maxf(multiplier, 0.5)


## 统计场上同类型的已召唤单位数量
func _count_active_summons() -> int:
	var count: int = 0
	var target_type: String = enemy_data.spawn_enemy_type
	for enemy in GameManager.get_all_enemies():
		if is_instance_valid(enemy) and enemy.get("is_summoned") and enemy.is_summoned:
			if enemy.enemy_data and enemy.enemy_data.enemy_id == target_type:
				count += 1
	return count


# ── 状态效果处理 ──────────────────────────────────────────────────────

## 获取受控制效果影响后的实际移动速度（委托 EffectService）
func _get_effective_speed() -> float:
	return EffectService.get_effective_speed(self, speed)


## 每帧处理所有激活效果（委托 EffectService）
func _process_effects(delta: float) -> void:
	EffectService.process_tick(self, delta)


## 再生：每帧回复 HP（毒蛙等）
var _regen_accumulator: float = 0.0
func _process_regen(delta: float) -> void:
	if not enemy_data or enemy_data.regen_per_second <= 0.0:
		return
	if hp <= 0 or hp >= enemy_data.max_hp:
		return
	# 毒蛙：只有停下时才回血
	if _toad_is_idle or not enemy_data.is_dot_immune:
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


## 子弹命中入口（向后兼容包装器 — 新代码应使用 CombatService.deal_damage）
func take_damage_from_bullet(dmg: float, bullet_effects: Array, pierce_giant: bool = false, armor_penetration: int = 0, ignore_dodge: bool = false) -> void:
	CombatService.deal_damage(
		{"source_tower": null, "armor_penetration": armor_penetration,
		 "pierce_giant": pierce_giant, "ignore_dodge": ignore_dodge},
		self, dmg, bullet_effects
	)


## 公开接口：施加单个效果（委托 EffectService）
func apply_effect(effect: BulletEffect, pierce_giant: bool = false) -> void:
	EffectService.apply_single_effect(self, effect, pierce_giant)


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
	# 宝箱敌人到达终点不扣血，只是逃走（奖励消失）
	if enemy_data and enemy_data.is_treasure_runner:
		treasure_escaped.emit()
		queue_free()
		return
	var dmg: int = enemy_data.damage_to_player if enemy_data else 1
	GameManager.damage_player(dmg)
	queue_free()


# ── 受到伤害 ──────────────────────────────────────────────────────────
func take_damage(amount: float) -> void:
	# 地鼠挖洞中完全无敌
	if is_burrowed:
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
	# 宝箱敌人击杀 → 发射掉落信号（不给金币/XP，奖励由外部处理）
	if enemy_data and enemy_data.is_treasure_runner:
		treasure_killed.emit()
		_play_death_anim()
		return
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
	lbl.text = tr("UI_SPAWN_TEXT") % count  # "召唤 +2" / "Spawn +2"
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.z_index = 10
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().current_scene.add_child(lbl)
	lbl.global_position = global_position + Vector2(-40, -80)
	var tw := lbl.create_tween()
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
