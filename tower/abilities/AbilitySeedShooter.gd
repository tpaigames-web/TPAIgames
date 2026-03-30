extends TowerAbility

## 播种机 — 远程种子炮弹，只打地面
##
## Path 0 超级草丛：命中后地面生长草丛（减速/伤害/爆炸/叠层）
## Path 1 终极炮射：伤害+溅射+标记
## Path 2 超速播种：攻速+穿透+双发
## Path 3 全图覆盖：射程+优先最远+减速

# ── Path 0: 草丛参数 ────────────────────────────────────────────────
const P0_GRASS_SLOW: Array[float]     = [0.0, 0.15, 0.15, 0.30, 0.30, 0.30]
const P0_GRASS_DUR: Array[float]      = [0.0, 3.0, 5.0, 8.0, 8.0, 8.0]
const P0_GRASS_DPS: Array[float]      = [0.0, 0.0, 3.0, 3.0, 3.0, 3.0]
const P0_GRASS_EXPLODE: Array[float]  = [0.0, 0.0, 0.0, 0.0, 50.0, 50.0]
const P0_GRASS_MAX_STACK: Array[int]  = [0, 1, 1, 1, 1, 3]
const P0_STUN_ON_FULL: Array[float]   = [0.0, 0.0, 0.0, 0.0, 0.0, 2.0]

# ── Path 1: 伤害+溅射+标记 ─────────────────────────────────────────
const P1_DMG: Array[float]         = [0.0, 0.18, 0.36, 0.54, 0.72, 0.90]
const P1_SPD: Array[float]         = [0.0, 0.18, 0.36, 0.54, 0.72, 0.90]
const P1_SPLASH: Array[float]      = [0.0, 0.0, 60.0, 100.0, 100.0, 150.0]
const P1_SPLASH_RATIO: Array[float] = [0.0, 0.0, 0.60, 0.60, 0.60, 0.60]
const P1_MARK_POT: Array[float]    = [0.0, 0.0, 0.0, 0.0, 0.20, 0.25]
const P1_MARK_DUR: Array[float]    = [0.0, 0.0, 0.0, 0.0, 4.0, 4.0]

# ── Path 2: 攻速+穿透 ─────────────────────────────────────────────
const P2_SPD: Array[float]         = [0.0, 0.15, 0.30, 0.60, 0.80, 0.80]
const P2_RNG: Array[float]         = [0.0, 0.15, 0.30, 0.60, 0.80, 0.80]
const P2_PIERCE_EVERY: Array[int]  = [0, 0, 0, 4, 3, 3]
const P2_DOUBLE_CHANCE: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.15]

# ── Path 3: 射程+减速 ─────────────────────────────────────────────
const P3_RNG: Array[float]  = [0.0, 0.20, 0.40, 0.60, 0.80, 0.80]
const P3_SLOW: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.20]

# ── 效果对象 ────────────────────────────────────────────────────────
var _mark_fx: BulletEffect = null
var _slow_fx: BulletEffect = null

# ── 穿透/双发计数 ──────────────────────────────────────────────────
var _shot_count: int = 0
var _last_p3_lv: int = -1


func on_placed() -> void:
	_mark_fx = BulletEffect.new()
	_mark_fx.effect_type = BulletEffect.Type.MARK

	_slow_fx = BulletEffect.new()
	_slow_fx.effect_type = BulletEffect.Type.SLOW
	_slow_fx.potency = 0.20
	_slow_fx.duration = 1.5


func _lv(path: int) -> int:
	return tower._in_game_path_levels[path] if tower._in_game_path_levels.size() > path else 0


# ═══════════════════════════════════════════════════════════════════════
# 被动处理
# ═══════════════════════════════════════════════════════════════════════
func ability_process(_delta: float) -> void:
	tower.ability_damage_bonus = P1_DMG[_lv(1)]
	tower.ability_speed_bonus = P1_SPD[_lv(1)] + P2_SPD[_lv(2)]
	tower.ability_range_bonus = P2_RNG[_lv(2)] + P3_RNG[_lv(3)]
	# P3 T3+: 解锁空中攻击 + 优先空中敌人
	if _lv(3) >= 3:
		tower.ability_attack_type = 2  # 地面+空中
	else:
		tower.ability_attack_type = -1  # 使用默认（地面）
	# P3 T5: 全图射程
	if _lv(3) >= 5:
		tower.ability_range_bonus = 99.0
	tower.apply_stat_upgrades()
	# P3 T3: 优先空中目标（只设一次）
	var cur_p3: int = _lv(3)
	if cur_p3 >= 3 and cur_p3 != _last_p3_lv:
		tower.target_mode = 3  # LAST = 优先最后（空中敌人通常在后面）
	_last_p3_lv = cur_p3


# ═══════════════════════════════════════════════════════════════════════
# 主攻击
# ═══════════════════════════════════════════════════════════════════════
func do_attack(target: Area2D, damage: float, td: TowerCollectionData) -> bool:
	if not is_instance_valid(target):
		return true

	var dmg: float = damage
	var effects: Array = td.bullet_effects.duplicate()

	# P1 T4+: 标记
	if _lv(1) >= 4:
		_mark_fx.potency = P1_MARK_POT[_lv(1)]
		_mark_fx.duration = P1_MARK_DUR[_lv(1)]
		effects.append(_mark_fx)

	# P3 T5: 减速
	if _lv(3) >= 5:
		effects.append(_slow_fx)

	# 溅射参数
	var splash_r: float = P1_SPLASH[_lv(1)]
	var splash_ratio: float = P1_SPLASH_RATIO[_lv(1)]

	# 子弹速度
	var bspd: float = td.bullet_speed if td.bullet_speed > 0.0 else 400.0

	# P2 穿透（每N发）
	_shot_count += 1
	var pierce: int = 0
	var pierce_every: int = P2_PIERCE_EVERY[_lv(2)]
	if pierce_every > 0 and _shot_count % pierce_every == 0:
		pierce = 1

	# 发射子弹
	var bullet: Node = tower.spawn_bullet_at(target, dmg, bspd, effects,
			td.bullet_emoji, splash_r, splash_ratio, td.bullet_scene)
	if bullet and pierce > 0:
		bullet.pierce_count = pierce

	# P0 T1+: 草丛（延迟到子弹命中后生成）
	if _lv(0) >= 1:
		var pos: Vector2 = target.global_position
		var dist: float = tower.global_position.distance_to(pos)
		var delay: float = dist / maxf(bspd, 100.0)
		get_tree().create_timer(delay).timeout.connect(
			func(): _spawn_grass(pos)
		)

	# P2 T5: 15%概率双发
	if _lv(2) >= 5 and randf() < P2_DOUBLE_CHANCE[_lv(2)]:
		var bullet2: Node = tower.spawn_bullet_at(target, dmg, bspd, effects,
				td.bullet_emoji, splash_r, splash_ratio, td.bullet_scene)
		if bullet2 and pierce > 0:
			bullet2.pierce_count = pierce

	return true


# ═══════════════════════════════════════════════════════════════════════
# P0 草丛生成
# ═══════════════════════════════════════════════════════════════════════
func _spawn_grass(pos: Vector2) -> void:
	var zone := _GrassZone.new()
	zone.global_position = pos
	zone.grass_slow = P0_GRASS_SLOW[_lv(0)]
	zone.grass_duration = P0_GRASS_DUR[_lv(0)]
	zone.grass_dps = P0_GRASS_DPS[_lv(0)]
	zone.explode_dmg = P0_GRASS_EXPLODE[_lv(0)]
	zone.max_stacks = P0_GRASS_MAX_STACK[_lv(0)]
	zone.stun_on_full = P0_STUN_ON_FULL[_lv(0)]
	zone.source_tower = tower
	get_tree().current_scene.add_child(zone)


# ═══════════════════════════════════════════════════════════════════════
# 草丛内部类
# ═══════════════════════════════════════════════════════════════════════
class _GrassZone extends Node2D:
	var grass_slow: float = 0.15
	var grass_duration: float = 3.0
	var grass_dps: float = 0.0
	var explode_dmg: float = 0.0
	var max_stacks: int = 1
	var stun_on_full: float = 0.0
	var source_tower: Area2D = null

	var _elapsed: float = 0.0
	var _tick_timer: float = 0.0
	var _stack_count: int = 1
	const ZONE_RADIUS: float = 40.0

	func _ready() -> void:
		z_index = 2
		# emoji 视觉（后续替换图片）
		var lbl := Label.new()
		lbl.text = "🌿"
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(-10, -10)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
		# 检查同位置草丛叠加
		_check_stacking()

	func _check_stacking() -> void:
		var stack: int = 0
		for node in get_tree().get_nodes_in_group("grass_zone"):
			if node == self:
				continue
			if node.global_position.distance_to(global_position) < 30.0:
				stack += 1
		_stack_count = mini(stack + 1, max_stacks)
		add_to_group("grass_zone")

	func _process(delta: float) -> void:
		_elapsed += delta
		if _elapsed >= grass_duration:
			_on_expire()
			return

		_tick_timer += delta
		if _tick_timer >= 0.5:
			_tick_timer = 0.0
			_apply_zone_effects()

	func _apply_zone_effects() -> void:
		var r2: float = ZONE_RADIUS * ZONE_RADIUS
		for enemy in GameManager.get_all_enemies():
			if not is_instance_valid(enemy) or enemy.finished:
				continue
			if enemy.global_position.distance_squared_to(global_position) > r2:
				continue
			# 减速
			if grass_slow > 0.0:
				var slow := BulletEffect.new()
				slow.effect_type = BulletEffect.Type.SLOW
				slow.potency = grass_slow * _stack_count
				slow.duration = 0.8
				enemy._try_apply_effect(slow, false)
			# 伤害
			if grass_dps > 0.0:
				if enemy.has_method("take_damage"):
					enemy.take_damage(int(grass_dps * 0.5 * _stack_count))
					if is_instance_valid(source_tower):
						source_tower.notify_damage(grass_dps * 0.5)
			# T5: 叠满眩晕
			if stun_on_full > 0.0 and _stack_count >= max_stacks:
				var stun := BulletEffect.new()
				stun.effect_type = BulletEffect.Type.STUN
				stun.duration = stun_on_full
				enemy._try_apply_effect(stun, false)

	func _on_expire() -> void:
		# T4: 消失时爆炸
		if explode_dmg > 0.0:
			var r2: float = 80.0 * 80.0
			for enemy in GameManager.get_all_enemies():
				if not is_instance_valid(enemy) or enemy.finished:
					continue
				if enemy.global_position.distance_squared_to(global_position) <= r2:
					if enemy.has_method("take_damage"):
						enemy.take_damage(int(explode_dmg))
						if is_instance_valid(source_tower):
							source_tower.notify_damage(explode_dmg)
			# 爆炸视觉
			var lbl := Label.new()
			lbl.text = "💥"
			lbl.add_theme_font_size_override("font_size", 24)
			lbl.global_position = global_position - Vector2(12, 12)
			lbl.z_index = 50
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			get_tree().current_scene.add_child(lbl)
			var tw := lbl.create_tween()
			tw.tween_property(lbl, "scale", Vector2(1.5, 1.5), 0.2).from(Vector2(0.5, 0.5))
			tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.3)
			tw.tween_callback(lbl.queue_free)
		remove_from_group("grass_zone")
		queue_free()

	func _draw() -> void:
		var alpha: float = 0.2 * (1.0 - _elapsed / maxf(grass_duration, 0.1))
		draw_circle(Vector2.ZERO, ZONE_RADIUS, Color(0.2, 0.8, 0.3, alpha))
