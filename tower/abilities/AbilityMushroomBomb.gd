extends TowerAbility

## 蘑菇炸弹 — 投掷蘑菇，命中后圆形AOE爆炸，只打地面
##
## Path 0 末日蘑菇：伤害+爆炸半径+碎片+连锁爆炸
## Path 1 极速轰炸：攻速+暴击+减速
## Path 2 核爆蘑菇：范围极大+攻速换范围+燃烧地形
## Path 3 剧毒孢子：毒气DOT+减速+叠层+眩晕

# ── 各路线各层累计加成 ────────────────────────────────────────────────
const P0_DMG: Array[float] = [0.0, 0.18, 0.36, 0.36, 0.36, 0.56]
const P0_SPD: Array[float] = [0.0, 0.18, 0.36, 0.36, 0.36, 0.56]
const P0_SPLASH_BONUS: Array[float] = [0.0, 0.10, 0.20, 0.20, 0.20, 0.20]
const P0_FRAG_COUNT: Array[int] = [0, 0, 0, 8, 8, 12]

const P1_SPD: Array[float] = [0.0, 0.15, 0.30, 0.60, 0.80, 0.80]
const P1_CRIT_EVERY: Array[int] = [0, 0, 0, 5, 4, 4]

const P2_SPD: Array[float] = [0.0, 0.0, 0.0, -0.10, -0.20, -0.20]
const P2_RNG: Array[float] = [0.0, 0.20, 0.40, 0.60, 0.80, 0.80]
const P2_BURN_DUR: Array[float] = [0.0, 0.0, 0.0, 0.0, 3.0, 15.0]

const P3_POISON_DPS: Array[float] = [0.0, 3.0, 6.0, 6.0, 6.0, 6.0]
const P3_POISON_DUR: Array[float] = [0.0, 4.0, 5.0, 8.0, 8.0, 8.0]
const P3_SLOW: Array[float]       = [0.0, 0.0, 0.0, 0.0, 0.30, 0.30]
const P3_STUN_DUR: Array[float]   = [0.0, 0.0, 0.0, 0.0, 0.0, 1.5]

# ── 基础溅射参数 ────────────────────────────────────────────────────
@export var base_splash_radius: float = 100.0
@export var splash_ratio: float = 0.7

# ── 效果对象 ────────────────────────────────────────────────────────
var _poison_fx: BulletEffect = null
var _slow_fx: BulletEffect = null
var _stun_fx: BulletEffect = null
var _hit_slow_fx: BulletEffect = null   # P1 T5 每发减速

# ── 暴击计数 ────────────────────────────────────────────────────────
var _shot_count: int = 0


func on_placed() -> void:
	_poison_fx = BulletEffect.new()
	_poison_fx.effect_type = BulletEffect.Type.POISON
	_poison_fx.tick_interval = 1.0

	_slow_fx = BulletEffect.new()
	_slow_fx.effect_type = BulletEffect.Type.SLOW
	_slow_fx.duration = 2.0

	_stun_fx = BulletEffect.new()
	_stun_fx.effect_type = BulletEffect.Type.STUN

	_hit_slow_fx = BulletEffect.new()
	_hit_slow_fx.effect_type = BulletEffect.Type.SLOW
	_hit_slow_fx.potency = 0.25
	_hit_slow_fx.duration = 0.2


func _lv(path: int) -> int:
	return tower._in_game_path_levels[path] if tower._in_game_path_levels.size() > path else 0


# ═══════════════════════════════════════════════════════════════════════
# 被动处理
# ═══════════════════════════════════════════════════════════════════════
func ability_process(_delta: float) -> void:
	tower.ability_damage_bonus = P0_DMG[_lv(0)]
	tower.ability_speed_bonus = P0_SPD[_lv(0)] + P1_SPD[_lv(1)] + P2_SPD[_lv(2)]
	tower.ability_range_bonus = P2_RNG[_lv(2)]
	tower.apply_stat_upgrades()


# ═══════════════════════════════════════════════════════════════════════
# 主攻击
# ═══════════════════════════════════════════════════════════════════════
func do_attack(target: Area2D, damage: float, td: TowerCollectionData) -> bool:
	if not is_instance_valid(target):
		return true

	var dmg: float = damage
	var effects: Array = _build_effects()

	# ── P1 暴击 ──
	_shot_count += 1
	var crit_every: int = P1_CRIT_EVERY[_lv(1)]
	if crit_every > 0 and _shot_count % crit_every == 0:
		dmg *= 1.5

	# ── 计算溅射半径 ──
	var splash_r: float = base_splash_radius * (1.0 + P0_SPLASH_BONUS[_lv(0)] + P2_RNG[_lv(2)])

	# ── 发射子弹 ──
	var bspd: float = td.bullet_speed if td.bullet_speed > 0.0 else 300.0
	var bullet: Node = tower.spawn_bullet_at(target, dmg, bspd, effects,
			td.bullet_emoji, splash_r, splash_ratio, td.bullet_scene)

	# ── P0 T3+: 碎片模式 ──
	if bullet and _lv(0) >= 3:
		bullet.splash_cone_deg = 360.0
		bullet.splash_damage_ratio = 0.30
		bullet.splash_frag_count = P0_FRAG_COUNT[_lv(0)]

	# ── P0 T4: 击杀连锁爆炸 ──
	if _lv(0) >= 4:
		var tgt_ref: Area2D = target
		var pos: Vector2 = target.global_position
		var dist: float = tower.global_position.distance_to(pos)
		var delay: float = dist / maxf(bspd, 100.0)
		var chain_dmg: float = dmg * 0.4
		get_tree().create_timer(delay + 0.05).timeout.connect(
			func():
				if is_instance_valid(tgt_ref) and tgt_ref.hp <= 0:
					_chain_explode(tgt_ref.global_position, chain_dmg)
		)

	# ── P2 T4+: 燃烧地形 ──
	if _lv(2) >= 4:
		var pos: Vector2 = target.global_position
		var dist: float = tower.global_position.distance_to(pos)
		var delay: float = dist / maxf(bspd, 100.0)
		var burn_dur: float = P2_BURN_DUR[_lv(2)]
		var burn_r: float = splash_r * 0.6
		get_tree().create_timer(delay).timeout.connect(
			func(): _create_burn_zone(pos, burn_r, burn_dur)
		)

	# ── 后坐力 ──
	_apply_recoil(target)
	return true


# ═══════════════════════════════════════════════════════════════════════
# 效果构建
# ═══════════════════════════════════════════════════════════════════════
func _build_effects() -> Array:
	var effects: Array = []
	# P3 毒气
	if _lv(3) >= 1:
		_poison_fx.damage_per_tick = P3_POISON_DPS[_lv(3)]
		_poison_fx.duration = P3_POISON_DUR[_lv(3)]
		effects.append(_poison_fx)
	# P3 T4+ 减速
	if _lv(3) >= 4:
		_slow_fx.potency = P3_SLOW[_lv(3)]
		effects.append(_slow_fx)
	# P3 T5 眩晕
	if _lv(3) >= 5:
		_stun_fx.duration = P3_STUN_DUR[_lv(3)]
		effects.append(_stun_fx)
	# P1 T5 每发减速
	if _lv(1) >= 5:
		effects.append(_hit_slow_fx)
	return effects


# ═══════════════════════════════════════════════════════════════════════
# P0 T4 击杀连锁爆炸
# ═══════════════════════════════════════════════════════════════════════
func _chain_explode(pos: Vector2, chain_dmg: float) -> void:
	for enemy in GameManager.get_all_enemies():
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		if enemy.global_position.distance_to(pos) <= 60.0:
			deal_damage(enemy, chain_dmg, [], tower.buff_giant_pierce)
	# 视觉
	var lbl := Label.new()
	lbl.text = "💥"
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.global_position = pos - Vector2(12, 12)
	lbl.z_index = 50
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().current_scene.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.5, 1.5), 0.2).from(Vector2(0.5, 0.5))
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.3).set_delay(0.1)
	tw.tween_callback(lbl.queue_free)


# ═══════════════════════════════════════════════════════════════════════
# P2 T4+ 燃烧地形
# ═══════════════════════════════════════════════════════════════════════
func _create_burn_zone(pos: Vector2, radius: float, duration: float) -> void:
	var zone := _BurnZone.new()
	zone.global_position = pos
	zone.burn_radius = radius
	zone.burn_duration = duration
	zone.burn_dps = 5.0
	zone.source_tower = tower
	get_tree().current_scene.add_child(zone)


# ═══════════════════════════════════════════════════════════════════════
# 后坐力
# ═══════════════════════════════════════════════════════════════════════
func _apply_recoil(target: Area2D) -> void:
	if not is_instance_valid(target):
		return
	var dir: Vector2 = (target.global_position - tower.global_position).normalized()
	var spr: Sprite2D = tower.get_node_or_null("BaseSprite")
	if not spr:
		return
	var orig_pos: Vector2 = spr.position
	var tw := spr.create_tween()
	tw.tween_property(spr, "position", orig_pos - dir * 3.0, 0.05)
	tw.tween_property(spr, "position", orig_pos, 0.12).set_ease(Tween.EASE_OUT)


# ═══════════════════════════════════════════════════════════════════════
# 燃烧地形内部类
# ═══════════════════════════════════════════════════════════════════════
class _BurnZone extends Node2D:
	var burn_radius: float = 60.0
	var burn_duration: float = 3.0
	var burn_dps: float = 5.0
	var source_tower: Area2D = null
	var _elapsed: float = 0.0
	var _tick_timer: float = 0.0

	func _ready() -> void:
		z_index = 2

	func _process(delta: float) -> void:
		_elapsed += delta
		if _elapsed >= burn_duration:
			queue_free()
			return
		_tick_timer += delta
		if _tick_timer >= 1.0:
			_tick_timer = 0.0
			var r2: float = burn_radius * burn_radius
			for enemy in GameManager.get_all_enemies():
				if not is_instance_valid(enemy) or enemy.finished:
					continue
				if enemy.global_position.distance_squared_to(global_position) <= r2:
					if enemy.has_method("take_damage"):
						enemy.take_damage(int(burn_dps))
						if is_instance_valid(source_tower):
							source_tower.notify_damage(burn_dps)

	func _draw() -> void:
		# 半透明橙红色圆形表示燃烧区域
		var alpha: float = 0.3 * (1.0 - _elapsed / maxf(burn_duration, 0.1))
		draw_circle(Vector2.ZERO, burn_radius, Color(1.0, 0.3, 0.05, alpha))
