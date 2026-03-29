extends TowerAbility

## 农场大炮 — 重型炮击，只打地面
##
## Path 0 末日炮击：伤害+18%/层 + 护甲穿透 + 燃烧 + 大型克制 + 击杀爆炸
## Path 1 榴弹洗地：溅射AOE + 燃烧区域
## Path 2 极速炮兵：攻速 + 暴击 + 减速
## Path 3 洲际导弹：超远射程 + 攻击最远目标 + 弹丸加速/追踪

# ── 各路线各层累计加成（下标 = 层级 0-5）────────────────────────────────
const P0_DMG: Array[float] = [0.0, 0.18, 0.36, 0.54, 0.72, 0.90]

const P1_SPLASH: Array[float]  = [0.0, 50.0, 80.0, 80.0, 110.0, 150.0]   # 弹片飞行距离
const P1_RATIO: Array[float]   = [0.0, 0.30, 0.50, 0.50, 0.50,  0.50]
const P1_CONE: Array[float]    = [0.0, 60.0, 70.0, 70.0, 70.0,  70.0]   # 弹片锥形角度（度）

const P2_SPD: Array[float] = [0.0, 0.18, 0.36, 0.54, 0.72, 0.72]
const P3_RNG: Array[float] = [0.0, 0.20, 0.40, 0.60, 0.80, 0.80]

# ── Path 0 护甲穿透等级 ─────────────────────────────────────────────────
const P0_ARMOR_PEN: Array[int] = [0, 0, 1, 1, 2, 2]

# ── Path 1 燃烧持续时间 ─────────────────────────────────────────────────
const P1_BURN_DUR: Array[float] = [0.0, 0.0, 0.0, 3.0, 8.0, 10.0]

# ── 效果对象 ────────────────────────────────────────────────────────────
var _burn_p0: BulletEffect = null   # Path0 T3+ 燃烧
var _burn_p1: BulletEffect = null   # Path1 T3+ 溅射区燃烧
var _slow_fx: BulletEffect = null   # Path2 T5 减速

# ── 暴击计数 ────────────────────────────────────────────────────────────
var _shot_count: int = 0
var _last_p3_lv: int = -1   # 记录上次 Path3 等级，避免每帧覆盖目标模式


func on_placed() -> void:
	_burn_p0 = BulletEffect.new()
	_burn_p0.effect_type = BulletEffect.Type.BURN
	_burn_p0.damage_per_tick = 5.0
	_burn_p0.tick_interval = 1.0
	_burn_p0.duration = 4.0

	_burn_p1 = BulletEffect.new()
	_burn_p1.effect_type = BulletEffect.Type.BURN
	_burn_p1.damage_per_tick = 5.0
	_burn_p1.tick_interval = 1.0
	_burn_p1.duration = 3.0

	_slow_fx = BulletEffect.new()
	_slow_fx.effect_type = BulletEffect.Type.SLOW
	_slow_fx.potency = 0.25
	_slow_fx.duration = 2.0


func _lv(path: int) -> int:
	return tower._in_game_path_levels[path] if tower._in_game_path_levels.size() > path else 0


# ═══════════════════════════════════════════════════════════════════════
# 主攻击
# ═══════════════════════════════════════════════════════════════════════
func do_attack(target: Area2D, damage: float, td: TowerCollectionData) -> bool:
	if not td or not is_instance_valid(target):
		return true

	# Tower 已自动计算 damage（含 ability_damage_bonus），直接使用
	var dmg: float = damage
	var effects: Array = td.bullet_effects.duplicate()

	# ── Path 0: 护甲穿透 ──
	tower.armor_penetration = P0_ARMOR_PEN[_lv(0)]

	# ── Path 0 T3+: 燃烧 ──
	if _lv(0) >= 3:
		effects.append(_burn_p0)

	# ── Path 1 T3+: 溅射区燃烧 ──
	if _lv(1) >= 3:
		_burn_p1.duration = P1_BURN_DUR[_lv(1)]
		effects.append(_burn_p1)

	# ── Path 2 T5: 减速 ──
	if _lv(2) >= 5:
		effects.append(_slow_fx)

	# ── Path 2 T4+: 暴击 ──
	_shot_count += 1
	if _lv(2) >= 4 and _shot_count % 3 == 0:
		dmg *= 2.0

	# ── Path 0 T4: 对大型 +40% ──
	if _lv(0) >= 4:
		var ed = target.get("enemy_data")
		if ed and ed.get("is_giant"):
			dmg *= 1.4

	# ── 溅射参数（Path1）──
	var splash_r: float = P1_SPLASH[_lv(1)]
	var splash_ratio: float = P1_RATIO[_lv(1)]

	# ── 弹丸速度（Path3 T4+: 飞行时间减半 = 速度×2）──
	var bspd: float = td.bullet_speed
	if bspd <= 0.0:
		bspd = 400.0
	if _lv(3) >= 4:
		bspd *= 2.0
	if _lv(3) >= 5:
		bspd *= 2.0   # T5 极快

	# ── 发射子弹 ──
	var bullet: Node = tower.spawn_bullet_at(target, dmg, bspd, effects,
			td.bullet_emoji, splash_r, splash_ratio, td.bullet_scene)

	# ── Path1: 弹片模式参数 ──
	if bullet and _lv(1) >= 1:
		bullet.splash_cone_deg = P1_CONE[_lv(1)]
		bullet.splash_burn_duration = P1_BURN_DUR[_lv(1)]
		bullet.splash_end_explode = _lv(1) >= 5

	# ── Path 0 T5: 击杀溅射爆炸（子弹命中后才触发，延迟处理）──
	if _lv(0) >= 5:
		var pos: Vector2 = target.global_position
		var dist: float = tower.global_position.distance_to(pos)
		var delay: float = dist / maxf(bspd, 100.0)
		var expl_dmg: float = dmg * 0.5
		var tgt_ref: Area2D = target
		get_tree().create_timer(delay + 0.05).timeout.connect(
			func():
				if is_instance_valid(tgt_ref) and tgt_ref.hp <= 0:
					_death_explode(tgt_ref.global_position, expl_dmg)
		)

	# ── 后坐力视觉效果 ──
	_apply_recoil(target)

	return true


# ═══════════════════════════════════════════════════════════════════════
# 被动处理（同步加成 + 目标模式）
# ═══════════════════════════════════════════════════════════════════════
func ability_process(_delta: float) -> void:
	# 通过 Tower.ability_*_bonus 注入加成，Tower 自动计算生效
	tower.ability_damage_bonus = P0_DMG[_lv(0)]
	tower.ability_speed_bonus = P2_SPD[_lv(2)]

	# Path3 射程（T5 全图覆盖特殊处理）
	if _lv(3) >= 5:
		tower.ability_range_bonus = 99.0   # 极大值 → 全图
	else:
		tower.ability_range_bonus = P3_RNG[_lv(3)]
	tower.apply_stat_upgrades()   # 刷新射程

	# Path3 T2+: 升级时自动切换为攻击最远目标（只设置一次，不覆盖玩家手动选择）
	var cur_p3: int = _lv(3)
	if cur_p3 >= 2 and cur_p3 != _last_p3_lv:
		tower.target_mode = 3

	# 更新特殊加成描述
	var specials: Array[String] = []
	if _lv(0) >= 3:
		specials.append("燃烧：5dps/4s")
	if _lv(0) >= 4:
		specials.append("对大型：+40%%伤害")
	if _lv(0) >= 5:
		specials.append("击杀溅射：100px 50%%原始伤")
	if _lv(2) >= 4:
		specials.append("暴击：每3发×2伤害")
	if _lv(2) >= 5:
		specials.append("附带减速：25%%")
	if _lv(3) >= 2:
		specials.append("优先攻击最远目标")
	tower.ability_special_bonuses = specials
	_last_p3_lv = cur_p3


# ═══════════════════════════════════════════════════════════════════════
# 辅助方法
# ═══════════════════════════════════════════════════════════════════════

## 击杀溅射爆炸（Path0 T5）
## 开火后坐力 — 位移抖动（向子弹反方向后退再弹回）
func _apply_recoil(target: Area2D) -> void:
	if not is_instance_valid(target):
		return
	# 计算后退方向（子弹飞行方向的反向）
	var dir: Vector2 = (target.global_position - tower.global_position).normalized()
	var recoil_offset: Vector2 = -dir * 3.0   # 后退3px
	var spr: Sprite2D = tower.get_node_or_null("BaseSprite")
	if not spr:
		return
	var orig_pos: Vector2 = spr.position
	var tw := spr.create_tween()
	tw.tween_property(spr, "position", orig_pos + recoil_offset, 0.05)
	tw.tween_property(spr, "position", orig_pos, 0.12).set_ease(Tween.EASE_OUT)


func _death_explode(pos: Vector2, explode_dmg: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		if enemy.global_position.distance_to(pos) <= 100.0:
			deal_damage(enemy, explode_dmg, [], tower.buff_giant_pierce)
	_spawn_explosion_emoji(pos)


## 爆炸emoji视觉效果
func _spawn_explosion_emoji(pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = "💥"
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.global_position = pos - Vector2(16, 16)
	lbl.z_index = 50
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parent := tower.get_parent()
	if parent:
		parent.add_child(lbl)
	else:
		get_tree().current_scene.add_child(lbl)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2(2.0, 2.0), 0.3).from(Vector2(0.5, 0.5))
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)
