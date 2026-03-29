extends TowerAbility

## 弓弩 — 超远程精准狙击
##
## Path 0 终极狙击：伤害+18%/层 + 暴击 + 护甲穿透 + 爆炸
## Path 1 弹如雨点：攻速/射程 + 穿透 + 减速
## Path 2 全图狙击：射程 + 穿透 + 全图覆盖 + 减速暴击
## Path 3 永久猎杀：标记增伤 + 扩散 + 暴击加成

# ── 数值查表（下标 = 层级 0-5）─────────────────────────────────────────
const P0_DMG: Array[float] = [0.0, 0.18, 0.36, 0.54, 0.72, 0.90]
const P0_CRIT_CHANCE: Array[float] = [0.0, 0.0, 0.25, 0.25, 1.0, 1.0]
const P0_CRIT_MULT: Array[float] = [0.0, 0.0, 2.5, 2.5, 2.5, 3.0]
const P0_ARMOR_PEN: Array[int] = [0, 0, 0, 1, 1, 1]

const P1_SPD: Array[float] = [0.0, 0.12, 0.24, 0.36, 0.48, 0.48]
const P1_RNG: Array[float] = [0.0, 0.12, 0.24, 0.36, 0.48, 0.48]
const P1_PIERCE: Array[int] = [0, 0, 1, 2, 3, 999]

const P2_RNG: Array[float] = [0.0, 0.25, 0.50, 0.75, 1.00, 1.00]
const P2_PIERCE: Array[int] = [0, 0, 1, 3, 999, 999]

const P3_MARK_POTENCY: Array[float] = [0.0, 0.18, 0.18, 0.18, 0.18, 0.30]
const P3_MARK_DURATION: Array[float] = [0.0, 5.0, 10.0, 10.0, 10.0, 10.0]
const P3_MAX_MARKS: Array[int] = [0, 1, 2, 2, 2, 4]

# ── 效果对象 ────────────────────────────────────────────────────────────
var _mark_fx: BulletEffect = null
var _slow_fx: BulletEffect = null

# ── 标记追踪 ────────────────────────────────────────────────────────────
var _marked_enemies: Array = []


func on_placed() -> void:
	tower.target_mode = 2   # 默认最强优先

	_mark_fx = BulletEffect.new()
	_mark_fx.effect_type = BulletEffect.Type.MARK
	_mark_fx.potency = 0.18
	_mark_fx.duration = 5.0

	_slow_fx = BulletEffect.new()
	_slow_fx.effect_type = BulletEffect.Type.SLOW
	_slow_fx.duration = 2.0


func _lv(path: int) -> int:
	return tower._in_game_path_levels[path] if tower._in_game_path_levels.size() > path else 0


# ═══════════════════════════════════════════════════════════════════════
# 主攻击
# ═══════════════════════════════════════════════════════════════════════
func do_attack(target: Area2D, damage: float, td: TowerCollectionData) -> bool:
	if not td or not is_instance_valid(target):
		return true

	var dmg: float = damage
	var effects: Array = td.bullet_effects.duplicate()

	# ── Path 0: 护甲穿透 ──
	tower.armor_penetration = P0_ARMOR_PEN[_lv(0)]

	# ── 暴击计算 ──
	var crit_chance: float = P0_CRIT_CHANCE[_lv(0)]
	var crit_mult: float = P0_CRIT_MULT[_lv(0)]

	# Path 3 T3+: 对标记目标暴击+60%
	if _lv(3) >= 3 and _is_marked(target):
		crit_chance += 0.60

	# Path 2 T5: 对已减速目标暴击
	if _lv(2) >= 5 and _is_slowed(target):
		crit_chance = 1.0
		if crit_mult <= 0.0:
			crit_mult = 2.0

	if crit_chance > 0.0 and randf() < crit_chance:
		dmg *= crit_mult

	# ── Path 0 T5: 对大型额外伤害 ──
	if _lv(0) >= 5:
		var ed = target.get("enemy_data")
		if ed and ed.get("is_giant"):
			dmg *= 1.5

	# ── Path 1 T4+: 减速 ──
	if _lv(1) >= 4:
		_slow_fx.potency = 0.20 if _lv(1) >= 5 else 0.10
		effects.append(_slow_fx)

	# ── Path 2 T5: 减速30% ──
	if _lv(2) >= 5:
		_slow_fx.potency = 0.30
		effects.append(_slow_fx)

	# ── Path 3: 标记 ──
	if _lv(3) >= 1:
		_mark_fx.potency = P3_MARK_POTENCY[_lv(3)]
		_mark_fx.duration = P3_MARK_DURATION[_lv(3)]
		effects.append(_mark_fx)
		_track_mark(target)

	# ── 穿透数量 ──
	var pierce: int = maxi(P1_PIERCE[_lv(1)], P2_PIERCE[_lv(2)])

	# ── 溅射（Path0 T5: 命中爆炸120px）──
	var splash_r: float = 120.0 if _lv(0) >= 5 else 0.0

	# ── 发射箭矢 ──
	var bullet: Node = tower.spawn_bullet_at(target, dmg, td.bullet_speed, effects,
			td.bullet_emoji, splash_r, 0.5, td.bullet_scene)

	if bullet:
		# 穿透
		if pierce > 0:
			bullet.pierce_count = pierce
		# Path 0 T1+: 无视闪避
		if _lv(0) >= 1:
			bullet.ignore_dodge = true

	# 后坐力
	_apply_recoil(target)

	return true


# ═══════════════════════════════════════════════════════════════════════
# 被动处理
# ═══════════════════════════════════════════════════════════════════════
func ability_process(_delta: float) -> void:
	# 同步加成
	tower.ability_damage_bonus = P0_DMG[_lv(0)]
	tower.ability_speed_bonus = P1_SPD[_lv(1)]

	# 射程（Path2 T4+ 全图）
	if _lv(2) >= 4:
		tower.ability_range_bonus = 99.0
	else:
		tower.ability_range_bonus = P1_RNG[_lv(1)] + P2_RNG[_lv(2)]
	tower.apply_stat_upgrades()

	# Path 3 T4+: 标记死亡转移
	if _lv(3) >= 4:
		_check_mark_transfer()

	# 特殊加成描述
	var specials: Array[String] = []
	if _lv(0) >= 1:
		specials.append("必定命中（无视闪避）")
	if P0_CRIT_CHANCE[_lv(0)] > 0:
		specials.append("暴击：%d%% × %.1fx" % [int(P0_CRIT_CHANCE[_lv(0)] * 100), P0_CRIT_MULT[_lv(0)]])
	if _lv(0) >= 3:
		specials.append("护甲穿透：降%d级" % P0_ARMOR_PEN[_lv(0)])
	if _lv(0) >= 5:
		specials.append("命中爆炸：120px")
	var pc: int = maxi(P1_PIERCE[_lv(1)], P2_PIERCE[_lv(2)])
	if pc > 0:
		specials.append("穿透：%s" % ("所有" if pc >= 999 else str(pc) + "敌"))
	if _lv(1) >= 4 or _lv(2) >= 5:
		specials.append("附带减速")
	if _lv(3) >= 1:
		specials.append("标记：+%d%%伤 %ds" % [int(P3_MARK_POTENCY[_lv(3)] * 100), int(P3_MARK_DURATION[_lv(3)])])
	tower.ability_special_bonuses = specials


# ═══════════════════════════════════════════════════════════════════════
# 标记系统（Path3）
# ═══════════════════════════════════════════════════════════════════════

func _track_mark(enemy: Area2D) -> void:
	if enemy in _marked_enemies:
		return
	var max_marks: int = P3_MAX_MARKS[_lv(3)]
	# 超过上限，移除最老的
	while _marked_enemies.size() >= max_marks:
		_marked_enemies.pop_front()
	_marked_enemies.append(enemy)


func _check_mark_transfer() -> void:
	var to_remove: Array = []
	for enemy in _marked_enemies:
		if not is_instance_valid(enemy) or enemy.hp <= 0:
			to_remove.append(enemy)
			# 转移标记到最近敌人
			if is_instance_valid(enemy):
				_transfer_mark(enemy.global_position)
			# Path3 T5: 击杀爆炸
			if _lv(3) >= 5 and is_instance_valid(enemy):
				_mark_death_explode(enemy.global_position)
	for e in to_remove:
		_marked_enemies.erase(e)


func _transfer_mark(pos: Vector2) -> void:
	var best: Area2D = null
	var best_dist: float = INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.finished or enemy in _marked_enemies:
			continue
		var d: float = enemy.global_position.distance_to(pos)
		if d < best_dist:
			best = enemy
			best_dist = d
	if best and best.has_method("apply_effect"):
		best.apply_effect(_mark_fx)
		_track_mark(best)


func _mark_death_explode(pos: Vector2) -> void:
	var explode_dmg: float = tower._get_effective_damage() * 0.5
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		if enemy.global_position.distance_to(pos) <= 100.0:
			deal_damage(enemy, explode_dmg, [], tower.buff_giant_pierce)


func _is_marked(enemy: Area2D) -> bool:
	return enemy in _marked_enemies


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


## 后坐力
func _apply_recoil(target: Area2D) -> void:
	if not is_instance_valid(target):
		return
	var dir: Vector2 = (target.global_position - tower.global_position).normalized()
	var recoil_offset: Vector2 = -dir * 2.0
	var spr: Sprite2D = tower.get_node_or_null("BaseSprite")
	if not spr:
		return
	var orig_pos: Vector2 = spr.position
	var tw := spr.create_tween()
	tw.tween_property(spr, "position", orig_pos + recoil_offset, 0.04)
	tw.tween_property(spr, "position", orig_pos, 0.1).set_ease(Tween.EASE_OUT)
