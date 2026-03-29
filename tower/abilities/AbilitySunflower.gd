extends TowerAbility

## 向日葵 — 支援型炮台，打地面+空中
##
## Path 0 神圣庇护：标记增伤+攻速光环
## Path 1 烈日灼烧：AOE燃烧
## Path 2 永恒太阳：多目标照射+BOSS克制
## Path 3 星光普照：减速控制+射程

# ── 各路线各层累计加成 ────────────────────────────────────────────────
const P0_MARK: Array[float]    = [0.0, 0.15, 0.20, 0.20, 0.25, 0.35]
const P0_MARK_DUR: Array[float] = [0.0, 4.0, 4.0, 8.0, 8.0, 12.0]
const P0_AURA_SPD: Array[float] = [0.0, 0.0, 0.08, 0.12, 0.18, 0.25]
const P0_AURA_RNG: Array[float] = [0.0, 0.0, 200.0, 200.0, 9999.0, 9999.0]

const P1_DMG: Array[float]     = [0.0, 0.15, 0.15, 0.15, 0.15, 0.15]
const P1_SPD: Array[float]     = [0.0, 0.15, 0.15, 0.15, 0.15, 0.15]
const P1_AOE_R: Array[float]   = [0.0, 80.0, 100.0, 130.0, 130.0, 9999.0]
const P1_BURN_DPS: Array[float] = [0.0, 0.0, 2.0, 4.0, 4.0, 4.0]
const P1_BURN_DUR: Array[float] = [0.0, 0.0, 3.0, 5.0, 5.0, 5.0]

const P2_DMG: Array[float]     = [0.0, 0.0, 0.0, 0.20, 0.20, 0.20]
const P2_SPD: Array[float]     = [0.0, 0.15, 0.30, 0.45, 0.60, 0.60]
const P2_TARGETS: Array[int]   = [1, 2, 3, 4, 5, 6]

const P3_RNG: Array[float]     = [0.0, 0.20, 0.40, 0.60, 0.80, 0.80]
const P3_SLOW: Array[float]    = [0.0, 0.10, 0.15, 0.20, 0.25, 0.35]
const P3_SLOW_DUR: Array[float] = [0.0, 1.5, 1.5, 1.5, 2.5, 3.0]

# ── 金币生成 ────────────────────────────────────────────────────────
@export var gold_interval: float = 8.0
@export var gold_amount: int = 25
@export var max_total_gold: int = 2000

# ── 效果对象 ────────────────────────────────────────────────────────
var _mark_fx: BulletEffect = null
var _burn_fx: BulletEffect = null
var _slow_fx: BulletEffect = null

# ── 计时器 ──────────────────────────────────────────────────────────
var _gold_timer: float = 0.0
var _total_gold_generated: int = 0
var _aura_timer: float = 0.0
var _buffed_towers: Array = []


func on_placed() -> void:
	_mark_fx = BulletEffect.new()
	_mark_fx.effect_type = BulletEffect.Type.MARK
	_mark_fx.potency = 0.15
	_mark_fx.duration = 4.0

	_burn_fx = BulletEffect.new()
	_burn_fx.effect_type = BulletEffect.Type.BURN
	_burn_fx.tick_interval = 1.0

	_slow_fx = BulletEffect.new()
	_slow_fx.effect_type = BulletEffect.Type.SLOW


func _lv(path: int) -> int:
	return tower._in_game_path_levels[path] if tower._in_game_path_levels.size() > path else 0


# ═══════════════════════════════════════════════════════════════════════
# 被动处理
# ═══════════════════════════════════════════════════════════════════════
func ability_process(delta: float) -> void:
	_sync_ability_bonuses()

	# 金币生成
	if _total_gold_generated < max_total_gold:
		_gold_timer += delta
		if _gold_timer >= gold_interval:
			_gold_timer = 0.0
			var give: int = mini(gold_amount, max_total_gold - _total_gold_generated)
			GameManager.add_gold(give)
			_total_gold_generated += give
			_show_gold_vfx(give)

	# P0 T2+ 攻速光环
	if _lv(0) >= 2:
		_aura_timer += delta
		if _aura_timer >= 0.5:
			_aura_timer = 0.0
			_refresh_aura()
	elif _buffed_towers.size() > 0:
		_clear_aura()


func _sync_ability_bonuses() -> void:
	tower.ability_damage_bonus = P1_DMG[_lv(1)] + P2_DMG[_lv(2)]
	tower.ability_speed_bonus = P1_SPD[_lv(1)] + P2_SPD[_lv(2)]
	tower.ability_range_bonus = P3_RNG[_lv(3)]
	# P3 T5: 全图射程
	if _lv(3) >= 5:
		tower.ability_range_bonus = 99.0
	tower.apply_stat_upgrades()


# ═══════════════════════════════════════════════════════════════════════
# 主攻击 — 瞬发（支援型）
# ═══════════════════════════════════════════════════════════════════════
func do_attack(target: Area2D, damage: float, td: TowerCollectionData) -> bool:
	if not is_instance_valid(target):
		return true
	tower.flash_attack_range(Color(1.0, 0.9, 0.3))

	var dmg: float = damage
	var effects: Array = _build_effects()
	var gp: bool = tower.buff_giant_pierce

	# P2 多目标
	var max_targets: int = P2_TARGETS[_lv(2)]
	var targets: Array = []
	if max_targets <= 1:
		targets = [target]
	else:
		var all_enemies: Array = tower.get_enemies_in_range()
		for enemy in all_enemies:
			if is_instance_valid(enemy) and targets.size() < max_targets:
				targets.append(enemy)

	# 对每个目标
	for enemy in targets:
		if not is_instance_valid(enemy):
			continue
		var fd: float = _apply_dmg_mods(dmg, enemy)

		# P1 AOE模式
		if _lv(1) >= 1:
			var aoe_r: float = P1_AOE_R[_lv(1)]
			if aoe_r >= 9999.0:
				# T5 全场AOE
				for e in GameManager.get_all_enemies():
					if is_instance_valid(e) and not e.finished:
						deal_damage(e, fd, effects, gp)
				break   # 全场只处理一次
			else:
				# AOE范围攻击
				for e in GameManager.get_all_enemies():
					if not is_instance_valid(e) or e.finished:
						continue
					if e.global_position.distance_to(enemy.global_position) <= aoe_r:
						deal_damage(e, fd, effects, gp)
		else:
			deal_damage(enemy, fd, effects, gp)

	return true


# ═══════════════════════════════════════════════════════════════════════
# 效果构建
# ═══════════════════════════════════════════════════════════════════════
func _build_effects() -> Array:
	var effects: Array = []
	# P0 标记
	if _lv(0) >= 1:
		_mark_fx.potency = P0_MARK[_lv(0)]
		_mark_fx.duration = P0_MARK_DUR[_lv(0)]
		effects.append(_mark_fx)
	# P1 T2+ 燃烧
	if _lv(1) >= 2:
		_burn_fx.damage_per_tick = P1_BURN_DPS[_lv(1)]
		_burn_fx.duration = P1_BURN_DUR[_lv(1)]
		effects.append(_burn_fx)
	# P3 减速
	if _lv(3) >= 1:
		_slow_fx.potency = P3_SLOW[_lv(3)]
		_slow_fx.duration = P3_SLOW_DUR[_lv(3)]
		effects.append(_slow_fx)
	return effects


func _apply_dmg_mods(base_dmg: float, enemy: Area2D) -> float:
	var d: float = base_dmg
	# P2 T5: 对BOSS双倍
	if _lv(2) >= 5:
		var ed = enemy.get("enemy_data")
		if ed and ed.get("is_elite"):
			d *= 2.0
	# P1 T4: 燃烧区停留+20%伤
	if _lv(1) >= 4:
		var effs = enemy.get("_active_effects")
		if effs:
			for eff in effs:
				if eff.get("type") == BulletEffect.Type.BURN:
					d *= 1.2
					break
	return d


# ═══════════════════════════════════════════════════════════════════════
# P0 攻速光环
# ═══════════════════════════════════════════════════════════════════════
func _refresh_aura() -> void:
	_clear_aura()
	var aura_spd: float = P0_AURA_SPD[_lv(0)]
	var aura_rng: float = P0_AURA_RNG[_lv(0)]
	if aura_spd <= 0.0:
		return
	var my_id: int = tower.get_instance_id()
	var td := tower.tower_data as TowerCollectionData
	var emoji: String = td.tower_emoji if td else "🌻"
	var tname: String = td.display_name if td else "向日葵"
	for t in tower.get_nearby_towers(aura_rng):
		if not is_instance_valid(t) or t == tower:
			continue
		t.buff_speed_mult += aura_spd
		t.buff_sources.append({
			"source_id": my_id,
			"emoji": emoji,
			"name": tname,
			"type": "speed",
			"value": aura_spd,
		})
		_buffed_towers.append(t)


func _clear_aura() -> void:
	var my_id: int = tower.get_instance_id()
	var aura_spd: float = P0_AURA_SPD[_lv(0)]
	for t in _buffed_towers:
		if is_instance_valid(t):
			t.buff_speed_mult = maxf(t.buff_speed_mult - aura_spd, 1.0)
			t.buff_sources = t.buff_sources.filter(func(bs): return bs.get("source_id") != my_id)
	_buffed_towers.clear()


# ═══════════════════════════════════════════════════════════════════════
# 金币特效
# ═══════════════════════════════════════════════════════════════════════
func _show_gold_vfx(amount: int) -> void:
	var lbl := Label.new()
	lbl.text = "+🪙%d" % amount
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.modulate = Color(1.0, 0.9, 0.2)
	lbl.position = Vector2(-30, -80)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tower.add_child(lbl)
	var tw := tower.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 70, 1.2)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.tween_callback(lbl.queue_free)
