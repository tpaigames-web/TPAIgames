extends TowerAbility

## 老阿福 — 丰收圣地（被动地形英雄）
##
## Lv1: 圣地内炮台伤害+12%，每次击杀+1金币
## Lv2A: 圣地深耕（伤害+32%）  |  Lv2B: 金穗满田（击杀+2金，精英+5金）
## Lv3A: 广袤农场（半径260px）  |  Lv3B: 丰收节奏（每10击杀爆发×2持续3s）
## Lv4A: 农神庇护（受伤-20%）   |  Lv4B: 黄金地脉（升级费-25%）
## Lv5A: 永恒圣地（350px+叠加） |  Lv5B: 农场之神（精英击杀10%免费强化刷新）

const TERRAIN_DATA_PATH := "res://data/heroes/afu_terrain.tres"

## 光环刷新间隔
@export var buff_interval: float = 1.0

## 基础伤害加成
@export var base_damage_buff: float = 0.12
## 基础击杀金币
@export var base_kill_gold: int = 1

# ── 运行时状态 ─────────────────────────────────────────────────────────
var _buff_timer: float = 0.0
var _buffed_towers: Array = []
var _terrain_data: HeroTerrainData = null

## 当前生效的伤害加成（受升级影响）
var _current_damage_buff: float = 0.12
## 击杀金币加成
var _kill_gold: int = 1
## 精英击杀额外金币
var _elite_kill_gold: int = 0
## 是否开启丰收爆发（Lv3B）
var _harvest_burst_enabled: bool = false
var _burst_kill_counter: int = 0
@export var burst_kill_threshold: int = 10
@export var burst_duration: float = 3.0
@export var burst_damage_mult: float = 2.0
var _burst_active: bool = false
var _burst_timer: float = 0.0
## 受伤减免（Lv4A 农神庇护）
var _damage_reduction: float = 0.0
## 升级费用折扣（Lv4B 黄金地脉）
var _upgrade_discount: float = 0.0
## 精英击杀概率触发免费强化刷新（Lv5B）
var _elite_refresh_chance: float = 0.0
## Lv5A 永恒圣地：叠加全部伤害路线
var _eternal_sacred: bool = false


func on_placed() -> void:
	_terrain_data = load(TERRAIN_DATA_PATH) as HeroTerrainData
	if _terrain_data:
		tower.terrain_radius = _terrain_data.base_radius
		tower.terrain_color  = _terrain_data.terrain_color
		tower.queue_redraw()
	# 连接击杀信号（通过 tower 的 notify_kill 无法直接获知是哪个塔击杀的）
	# 改为在 buff 刷新时检查域内塔的 stat_kills 变化


## 英雄不攻击，返回 true 阻止默认攻击流程
func do_attack(_target: Area2D, _damage: float, _td: TowerCollectionData) -> bool:
	return true


func ability_process(delta: float) -> void:
	# ── 光环 buff 刷新 ──
	_buff_timer += delta
	if _buff_timer >= buff_interval:
		_buff_timer = 0.0
		_refresh_terrain_buff()

	# ── 丰收爆发倒计时（Lv3B）──
	if _burst_active:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_active = false
			_refresh_terrain_buff()   # 恢复正常倍率


## 应用升级选择
func apply_upgrade(tier: int, choice: String) -> void:
	match tier:
		1:  # 波次5
			if choice == "A":
				# 圣地深耕：伤害+12%→+32%
				_current_damage_buff = 0.32
			else:
				# 金穗满田：击杀+2金，精英+5金
				_kill_gold = 2
				_elite_kill_gold = 5
		2:  # 波次10
			if choice == "A":
				# 广袤农场：半径260px
				tower.terrain_radius = 260.0
				tower.queue_redraw()
			else:
				# 丰收节奏：每10次击杀触发爆发
				_harvest_burst_enabled = true
		3:  # 波次15
			if choice == "A":
				# 农神庇护：域内炮台受伤-20%
				_damage_reduction = 0.20
			else:
				# 黄金地脉：域内炮台升级费-25%
				_upgrade_discount = 0.25
		4:  # 波次20
			if choice == "A":
				# 永恒圣地：半径350px，伤害叠加全部路线
				tower.terrain_radius = 350.0
				_eternal_sacred = true
				# 叠加之前所有伤害加成效果
				if _current_damage_buff < 0.32:
					_current_damage_buff = 0.32
				tower.queue_redraw()
			else:
				# 农场之神：精英击杀10%概率免费强化刷新
				_elite_refresh_chance = 0.10
	_refresh_terrain_buff()


## 刷新域内炮台的 buff
func _refresh_terrain_buff() -> void:
	if not is_instance_valid(tower):
		return
	var radius: float = tower.terrain_radius
	if radius <= 0.0:
		return

	# 清除旧 buff
	var my_id: int = tower.get_instance_id()
	for t in _buffed_towers:
		if is_instance_valid(t):
			t.terrain_damage_bonus    = 0.0
			t.buff_damage_reduction   = 0.0
			t.buff_upgrade_discount   = 0.0
			t.buff_sources = t.buff_sources.filter(func(bs): return bs.get("source_id") != my_id)
	_buffed_towers.clear()

	# 计算当前伤害 buff（爆发期间翻倍）
	var dmg_buff: float = _current_damage_buff
	if _burst_active:
		dmg_buff *= burst_damage_mult

	# 施加新 buff
	var hero_td := tower.tower_data as TowerCollectionData
	var emoji: String = hero_td.tower_emoji if hero_td else "🧑‍🌾"
	var hero_name: String = TowerResourceRegistry.tr_tower_name(hero_td) if hero_td else tr("TOWER_HERO_FARMER")
	for t in tower.get_nearby_towers(radius):
		if not is_instance_valid(t):
			continue
		var td := t.tower_data as TowerCollectionData
		if td and td.is_hero:
			continue   # 不 buff 其他英雄
		t.terrain_damage_bonus  = dmg_buff
		t.buff_damage_reduction = _damage_reduction
		t.buff_upgrade_discount = _upgrade_discount
		# 注册 buff 来源
		if dmg_buff > 0.0:
			t.buff_sources.append({
				"source_id": my_id,
				"emoji": emoji,
				"name": hero_name,
				"type": "terrain_damage",
				"value": dmg_buff,
			})
		_buffed_towers.append(t)


## 域内炮台击杀时调用（由 BattleScene 转发）
func on_tower_kill_in_terrain(killer_tower: Area2D, enemy: Area2D) -> void:
	if not is_instance_valid(tower):
		return
	# 检查击杀者是否在圣地内
	if killer_tower.global_position.distance_to(tower.global_position) > tower.terrain_radius:
		return

	# 金币加成
	var gold: int = _kill_gold
	var enemy_data = enemy.get("enemy_data") if is_instance_valid(enemy) else null
	var is_elite: bool = enemy_data != null and enemy_data.get("is_giant") == true
	if is_elite and _elite_kill_gold > 0:
		gold = _elite_kill_gold
	if gold > 0:
		GameManager.add_gold(gold)
		_show_gold_vfx(gold)

	# 丰收爆发计数（Lv3B）
	if _harvest_burst_enabled:
		_burst_kill_counter += 1
		if _burst_kill_counter >= burst_kill_threshold:
			_burst_kill_counter = 0
			_burst_active = true
			_burst_timer = burst_duration
			_refresh_terrain_buff()
			_show_burst_vfx()

	# 精英击杀免费刷新（Lv5B）
	if is_elite and _elite_refresh_chance > 0.0:
		if randf() < _elite_refresh_chance:
			# 通知 BattleScene 触发免费刷新
			if tower.has_signal("hero_free_refresh"):
				tower.emit_signal("hero_free_refresh")


## 从存档恢复升级状态
func restore_upgrades(choices: Array[String]) -> void:
	for i in choices.size():
		apply_upgrade(i + 1, choices[i])


## 产金浮动特效
func _show_gold_vfx(amount: int) -> void:
	if not is_instance_valid(tower):
		return
	var lbl := Label.new()
	lbl.text = "+🪙%d" % amount
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.modulate = Color(1.0, 0.9, 0.2)
	lbl.position = Vector2(-30, -80)
	tower.add_child(lbl)
	var tw := tower.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 70, 1.2)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.tween_callback(lbl.queue_free)


## 丰收爆发视觉特效
func _show_burst_vfx() -> void:
	if not is_instance_valid(tower):
		return
	var lbl := Label.new()
	lbl.text = "⚡ 丰收爆发！"
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.modulate = Color(1.0, 0.8, 0.0)
	lbl.position = Vector2(-100, -120)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tower.add_child(lbl)
	var tw := tower.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 80, 1.5)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.5)
	tw.tween_callback(lbl.queue_free)
