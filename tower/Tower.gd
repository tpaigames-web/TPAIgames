extends Area2D
## Tower — 炮台主体
## 代码区域：
##   #region CONSTANTS       — 常量 & 能力映射
##   #region VARIABLES       — 所有变量声明
##   #region LIFECYCLE       — _ready, apply_tower_data, _process
##   #region STATS           — 伤害/攻速/射程 计算 & Buff 系统
##   #region COMBAT          — _fire_at, spawn_bullet_at, 能力系统
##   #region TARGETING       — 目标选取, 范围内敌人查询
##   #region GLOBAL_UPGRADES — 波次强化应用
##   #region VISUALS         — 贴图切换, 范围显示, Buff 图标, _draw
##   #region PLACEMENT       — 放置检查, 碰撞检测, 输入处理

signal tower_tapped(tower: Area2D)

#region CONSTANTS
const BULLET_SCENE: PackedScene = preload("res://bullet/Bullet.tscn")

## tower_id → 能力脚本映射
const ABILITY_MAP: Dictionary = {
	"scarecrow":     preload("res://tower/abilities/AbilityScarecrow.gd"),
	"water_pipe":    preload("res://tower/abilities/AbilityWaterPipe.gd"),
	"farmer":        preload("res://tower/abilities/AbilityFarmer.gd"),
	"bear_trap":     preload("res://tower/abilities/AbilityBearTrap.gd"),
	"beehive":       preload("res://tower/abilities/AbilityBeehive.gd"),
	"farm_cannon":   preload("res://tower/abilities/AbilityFarmCannon.gd"),
	"barbed_wire":   preload("res://tower/abilities/AbilityBarbedWire.gd"),
	"windmill":      preload("res://tower/abilities/AbilityWindmill.gd"),
	"seed_shooter":  preload("res://tower/abilities/AbilitySeedShooter.gd"),
	"mushroom_bomb": preload("res://tower/abilities/AbilityMushroomBomb.gd"),
	"chili_flamer":  preload("res://tower/abilities/AbilityChiliFlamer.gd"),
	"watchtower":    preload("res://tower/abilities/AbilityWatchtower.gd"),
	"sunflower":     preload("res://tower/abilities/AbilitySunflower.gd"),
	"hero_farmer":    preload("res://tower/abilities/AbilityHeroAfu.gd"),
	"farm_guardian":  preload("res://tower/abilities/AbilityHeroGuardian.gd"),
}
#endregion

#region VARIABLES
@export var tower_data: Resource

var can_place: bool = true
var is_preview: bool = true
var bullet_pool: ObjectPool = null  ## 子弹对象池（由 BattleScene 注入）
var attack_timer: float = 0.0
var attack_range: Area2D
var _current_target: Area2D = null
var _target_query_counter: int = 0   ## 目标查询节流计数器
var _ability: TowerAbility = null
var _placed: bool = false

## 外部增伤乘数（来自向日葵等光环）
var buff_damage_mult: float = 1.0
## 外部攻速乘数
var buff_speed_mult: float = 1.0
## 巨型穿透增益：使本塔的控制效果可作用于巨型单位（由向日葵路线3施加）
var buff_giant_pierce: bool = false
## 护甲穿透等级（降低目标有效护甲，0 = 无穿透）
var armor_penetration: int = 0

## 能力脚本注入的加成（用于非均匀路线加成，.tres bonus 为 0 时由能力脚本设置）
var ability_damage_bonus: float = 0.0
var ability_speed_bonus: float = 0.0
var ability_range_bonus: float = 0.0
## 能力脚本覆盖攻击类型（-1=使用.tres默认值，0=地面，1=空中，2=全部）
var ability_attack_type: int = -1

## 标记增伤光环（来自辣椒P3T5等）：攻击被标记敌人时额外伤害加成
var buff_mark_bonus: float = 0.0

## ── 全局升级（波次强化）独立加成 ────────────────────────────────────────────
## 与光环 buff_*_mult 分开存储，避免两者互相覆盖
## 由 BattleScene._apply_upgrades_to_all_towers() 在升级选中/新塔放置时写入
var global_damage_bonus:  float = 0.0   ## 叠加伤害比例加成（0.20=+20%）
var global_speed_bonus:   float = 0.0   ## 叠加攻速比例加成
var global_range_bonus:   float = 0.0   ## 叠加射程比例加成
var global_cost_discount: float = 0.0   ## 放置费用折扣（0.15=打八五折）

## ── 新增全局加成（波次强化扩展）──────────────────────────────────────────
var global_armor_pen_bonus: float = 0.0   ## 全局穿甲加成（0.10=忽视10%护甲）
var global_dot_bonus: float = 0.0          ## 全局DoT伤害加成（出血/毒素/燃烧 +X%）
var global_crit_bonus: float = 0.0         ## 全局暴击率加成（0.08=+8%暴击率）
var global_mark_bonus: float = 0.0         ## 全局标记增伤加成（叠加到标记效果上）
var global_slow_bonus: float = 0.0         ## 全局减速效果加成（+X%减速强度）

## Buff 来源追踪（用于 UI 显示图标和数值分解）
## 每项：{ "source": Area2D, "emoji": "🌻", "name": "向日葵", "type": "speed"|"damage", "value": 0.15 }
var buff_sources: Array[Dictionary] = []

## Buff 图标 UI
var _buff_icon_container: HBoxContainer = null
var _buff_icon_timer: float = 0.0
var _last_buff_count: int = 0

## 攻击范围闪光（瞬发塔视觉反馈）
var _flash_alpha: float = 0.0
var _flash_color: Color = Color.WHITE
const FLASH_FADE_SPEED: float = 2.0

## 射击纹理切换
var _idle_texture: Texture2D = null    ## attack_texture 或 base_texture（待机图）
var _shoot_texture: Texture2D = null   ## shoot_texture（射击图）
var _ready_texture: Texture2D = null   ## ready_texture（准备状态图，非旋转塔专用）
var _shoot_timer: float = 0.0         ## 射击纹理显示剩余时间
var _is_rotating_tower: bool = false   ## 是否为旋转塔（有 attack_texture）
@export var shoot_flash_duration: float = 0.15  ## 射击图显示时长（秒）

## 游戏内各升级路径当前层数（0=未升级；Arsenal 层数决定免费配额）
var _in_game_path_levels: Array[int] = [0, 0, 0, 0]
## 攻击目标模式：0=第一个 1=靠近 2=强力 3=最后一个
var target_mode: int = 0
## 触屏双击检测：上一次 tap 时间戳
var _last_tap_time: float = 0.0
## 是否持续显示攻击范围圆（点击炮台后由 BattleScene 控制）
var show_range: bool = false
var _effective_range: float = -1.0
var stat_damage_dealt: float = 0.0
var stat_kills: int = 0
var stat_wave_placed: int = 0
var stat_total_spent: int = 0

## 英雄等级（1–5；非英雄塔保持 1，不影响计算）
var hero_level: int = 1

## ── 英雄地形系统 ──────────────────────────────────────────────────────────
## 地形半径（像素），>0 时绘制半透明彩色圆
var terrain_radius: float = 0.0
## 地形颜色（含 alpha，由能力脚本根据 HeroTerrainData 设置）
var terrain_color: Color = Color.TRANSPARENT
## 英雄升级等级（1-5，与 hero_level 同步）
var hero_upgrade_level: int = 1
## 记录每次 2 选 1 的选择 ["A","B","A","B"]
var hero_chosen_upgrades: Array[String] = []

## ── 英雄地形 buff 字段（由地形能力脚本施加到域内炮台）──────────────────────
## 地形伤害加成（叠加到 buff_damage_mult 之上）
var terrain_damage_bonus: float = 0.0
## 地形受伤减免（农神庇护：0.20 = 减免 20%）
var buff_damage_reduction: float = 0.0
## 地形升级费用折扣（黄金地脉：0.25 = 打七五折）
var buff_upgrade_discount: float = 0.0

@onready var placement_poly: CollisionPolygon2D = $PlacementPolygon
@onready var attack_shape = $AttackRange/CollisionShape2D
@onready var _shadow_spr:  Sprite2D = $ShadowSprite
@onready var _base_spr:   Sprite2D = $BaseSprite
@onready var _attack_spr: Sprite2D = $AttackSprite
@onready var _anim_spr:   AnimatedSprite2D = $AnimSprite
@onready var _emoji_lbl:  Label    = $EmojiLabel
#endregion

#region LIFECYCLE
func _ready():

	monitoring = true
	monitorable = true

	attack_range = $AttackRange

	if tower_data:
		apply_tower_data()

	# 连接自身 input_event，放置后响应点击
	input_event.connect(_on_tower_input)

	# 预览模式下隔离物理干扰——禁止参与 collision_mask=8 通道，避免拖动时影响已放置炮台的攻击检测
	if is_preview:
		monitorable = false
		attack_range.monitoring = false
		attack_shape.disabled = true   # 完全从物理宽相移除，防止预览在路面时干扰其他 AttackRange


func apply_tower_data():

	if not tower_data:
		return

	# ===== 攻击范围 =====
	# duplicate() 使每个实例持有独立的 CircleShape2D 副本，
	# 防止预览炮台修改共享资源时波及所有已放置炮台的碰撞形状
	if attack_shape and attack_shape.shape and attack_shape.shape is CircleShape2D:
		attack_shape.shape = attack_shape.shape.duplicate()
		attack_shape.shape.radius = tower_data.attack_range
	# 同步 AttackRange 的独立半径字段（get_enemies_in_range 使用此值，不读共享 shape）
	if attack_range:
		attack_range.attack_radius = tower_data.attack_range

	# ===== 放置碰撞（CollisionPolygon2D）=====
	# 多边形优先来自各炮台独立 .tscn 场景（编辑器中可视化手绘）
	# .tres 的 collision_polygon 可作覆盖；都无数据时用 collision_radius 生成圆
	var td_col := tower_data as TowerCollectionData
	if td_col and placement_poly:
		if td_col.collision_polygon.size() >= 3:
			placement_poly.polygon = td_col.collision_polygon
		elif placement_poly.polygon.size() < 3:
			# .tscn 也无多边形时，用 collision_radius 生成近似圆形（12边）
			var r: float = td_col.collision_radius
			var pts := PackedVector2Array()
			for i in 12:
				var angle: float = TAU * i / 12.0
				pts.append(Vector2(cos(angle) * r, sin(angle) * r))
			placement_poly.polygon = pts

	# ===== 图片分层显示 =====
	var td := tower_data as TowerCollectionData
	if td and td.anim_frames:
		# ── 动画帧模式（风车等）──
		_anim_spr.sprite_frames = td.anim_frames
		_anim_spr.visible = true
		_base_spr.visible = false
		_attack_spr.visible = false
		_emoji_lbl.visible = false
		# 自动缩放至约 100px
		var anim_name: String = "default"
		if td.anim_frames.has_animation(anim_name):
			var frame_tex: Texture2D = td.anim_frames.get_frame_texture(anim_name, 0)
			if frame_tex:
				var target: float = 100.0
				var tex_size: Vector2 = frame_tex.get_size()
				var max_dim: float = max(tex_size.x, tex_size.y)
				if max_dim > 0:
					var s: float = target / max_dim
					_anim_spr.scale = Vector2(s, s)
		_anim_spr.play("default")
		# 影子层
		var first_frame: Texture2D = td.anim_frames.get_frame_texture("default", 0) if td.anim_frames.has_animation("default") else null
		if first_frame:
			_shadow_spr.texture  = first_frame
			_shadow_spr.modulate = Color(0, 0, 0, 0.35)
			_shadow_spr.position = Vector2(6, 8)
			_shadow_spr.visible  = true
			_auto_scale(_shadow_spr)
		else:
			_shadow_spr.visible = false
		_is_rotating_tower = false
		_idle_texture = null

	elif td and (td.base_texture or td.attack_texture):
		# ── 静态贴图模式 ──
		_anim_spr.visible = false
		# 底座层
		_base_spr.texture = td.base_texture
		_base_spr.visible = td.base_texture != null
		_auto_scale(_base_spr)

		# 影子层（与底座相同纹理，偏移 + 半透明黑色）
		_shadow_spr.texture  = td.base_texture
		_shadow_spr.modulate = Color(0, 0, 0, 0.35)
		_shadow_spr.position = Vector2(6, 8)
		_shadow_spr.visible  = td.base_texture != null
		_auto_scale(_shadow_spr)

		_is_rotating_tower = td.attack_texture != null
		_shoot_texture = td.shoot_texture
		_ready_texture = td.ready_texture

		if _is_rotating_tower:
			# 旋转塔（弓弩等）：攻击层待机/射击在 _attack_spr 切换
			_idle_texture = td.attack_texture
			_attack_spr.texture = td.attack_texture
			_attack_spr.visible = true
			_auto_scale(_attack_spr)
		else:
			# 非旋转塔（稻草人等）：状态切换在 _base_spr 上
			_idle_texture = td.base_texture
			_attack_spr.visible = false

		_emoji_lbl.visible = false

	elif td and td.icon_texture:
		# 兼容旧 icon_texture
		_base_spr.texture  = td.icon_texture
		_base_spr.visible  = true
		_auto_scale(_base_spr)
		_shadow_spr.visible = false
		_attack_spr.visible = false
		_emoji_lbl.visible  = false

	else:
		_shadow_spr.visible = false
		_base_spr.visible   = false
		_attack_spr.visible = false
		_emoji_lbl.text     = td.tower_emoji if td else "?"
		_emoji_lbl.visible  = true

	# ===== 英雄地形预览：预加载地形半径和颜色 =====
	if td and td.is_hero and terrain_radius <= 0.0:
		var terrain_file: String = "afu" if td.tower_id == "hero_farmer" else "guardian"
		var terrain_path: String = "res://data/heroes/%s_terrain.tres" % terrain_file
		var ht := load(terrain_path) as HeroTerrainData
		if ht:
			terrain_radius = ht.base_radius
			terrain_color  = ht.terrain_color


func _auto_scale(spr: Sprite2D) -> void:
	if not spr.texture:
		return
	var sz: Vector2 = spr.texture.get_size()
	var md: float = maxf(sz.x, sz.y)
	if md > 0.0:
		spr.scale = Vector2(100.0 / md, 100.0 / md)


## 放置预览碰撞检查节流计时器
var _place_check_timer: float = 0.0
## 上一帧的 can_place 状态（用于只在变化时重绘）
var _prev_can_place: bool = false

func _process(delta):

	if is_preview:
		# 节流：每 0.1 秒检查一次碰撞，状态变化时才重绘
		_place_check_timer -= delta
		if _place_check_timer <= 0.0:
			_place_check_timer = 0.1
			var old_can := can_place
			_update_can_place()
			if can_place != old_can:
				queue_redraw()
		return

	if not tower_data:
		return

	# 首次放置后挂载能力
	if not _placed:
		_placed = true
		monitorable = true
		attack_range.monitoring = true
		attack_shape.disabled = false
		_attach_ability()

	# 能力被动处理（光环/产金等）
	if _ability:
		_ability.ability_process(delta)

	# 常驻范围圈模式需要持续重绘
	if SettingsManager and SettingsManager.range_display == 2:
		queue_redraw()

	# Buff 图标更新（每 0.5 秒刷新一次）
	_buff_icon_timer += delta
	if _buff_icon_timer >= 0.5:
		_buff_icon_timer = 0.0
		_refresh_buff_icons()

	# 英雄是被动地形单位，不执行攻击逻辑
	var _td_hero := tower_data as TowerCollectionData
	if _td_hero and _td_hero.is_hero:
		# 仅绘制地形圆，不攻击
		return

	# 闪光衰减 — 节流重绘，降到 0 后停止
	if _flash_alpha > 0.0:
		_flash_alpha = maxf(_flash_alpha - FLASH_FADE_SPEED * delta, 0.0)
		if _target_query_counter == 0:   # 复用节流计数器，每 3 帧重绘一次
			queue_redraw()

	# ── 目标查询节流：每 3 帧查一次，减少 O(n) 遍历 ──
	# 陷阱类（路径放置）每帧检测，确保敌人进入时立即触发
	var _td_path := tower_data as TowerCollectionData
	var _is_trap: bool = _td_path != null and _td_path.place_on_path_only
	_target_query_counter += 1
	if _is_trap or _target_query_counter >= 3 or _current_target == null or not is_instance_valid(_current_target):
		_target_query_counter = 0
		if is_instance_valid(attack_range):
			var _atk_type: int = 2
			if ability_attack_type >= 0:
				_atk_type = ability_attack_type
			else:
				var _td := tower_data as TowerCollectionData
				if _td:
					_atk_type = _td.attack_type
			var new_target: Area2D = attack_range.get_target(target_mode, _atk_type)
			if new_target and is_instance_valid(new_target):
				_current_target = new_target
			else:
				_current_target = null

	# 射击纹理倒计时 — 到期后切回待机图（或准备图）
	if _shoot_timer > 0.0:
		_shoot_timer -= delta
		if _shoot_timer <= 0.0:
			if _is_rotating_tower:
				if _idle_texture:
					_attack_spr.texture = _idle_texture
			else:
				if is_instance_valid(_current_target) and _ready_texture:
					_base_spr.texture = _ready_texture
				elif _idle_texture:
					_base_spr.texture = _idle_texture

	# 非旋转塔：根据是否有敌人切换准备/待机纹理（射击中不切换）
	if not _is_rotating_tower and _ready_texture and _shoot_timer <= 0.0:
		if is_instance_valid(_current_target):
			if _base_spr.texture != _ready_texture:
				_base_spr.texture = _ready_texture
		else:
			if _base_spr.texture != _idle_texture and _idle_texture:
				_base_spr.texture = _idle_texture

	# 旋转塔：攻击图层实时朝向当前目标（图片默认朝上=12点方向，补偿 +PI/2）
	if _is_rotating_tower and _attack_spr.visible and is_instance_valid(_current_target):
		_attack_spr.rotation = (_current_target.global_position - global_position).angle() + PI / 2.0

	# attack_speed == 0 表示不使用定时攻击（如陷阱型塔由能力脚本自行处理）
	var _td_atk := tower_data as TowerCollectionData
	if _td_atk and _td_atk.attack_speed > 0.0:
		attack_timer += delta
		if attack_timer >= _get_effective_attack_interval():
			attack_timer = 0.0
			if is_instance_valid(_current_target):
				_fire_at(_current_target)


#endregion

#region STATS
## ═══ 数值分解（供 ⓘ 详情面板使用）═══════════════════════════════════════

func get_damage_breakdown() -> Dictionary:
	var td := tower_data as TowerCollectionData
	if not td:
		return {}
	var path_bonus: float = 0.0
	for i in td.upgrade_paths.size():
		var p := td.upgrade_paths[i] as TowerUpgradePath
		if p: path_bonus += p.damage_bonus_per_tier * _in_game_path_levels[i]
	path_bonus += ability_damage_bonus
	var hero_b: float = (hero_level - 1) * 0.12
	var additive: float = 1.0 + path_bonus + global_damage_bonus + hero_b + terrain_damage_bonus
	var final_dmg: float = td.base_damage * additive * buff_damage_mult
	# 光环分解
	var aura_buffs: Array = []
	for bs in buff_sources:
		if bs.get("type") == "damage":
			aura_buffs.append(bs)
	return {
		"base": td.base_damage,
		"path_bonus": path_bonus,
		"global_bonus": global_damage_bonus,
		"hero_bonus": hero_b,
		"terrain_bonus": terrain_damage_bonus,
		"buff_mult": buff_damage_mult,
		"aura_buffs": aura_buffs,
		"final": final_dmg,
	}


func get_speed_breakdown() -> Dictionary:
	var td := tower_data as TowerCollectionData
	if not td:
		return {}
	var path_bonus: float = 0.0
	for i in td.upgrade_paths.size():
		var p := td.upgrade_paths[i] as TowerUpgradePath
		if p: path_bonus += p.speed_bonus_per_tier * _in_game_path_levels[i]
	path_bonus += ability_speed_bonus
	var hero_s: float = (hero_level - 1) * 0.08
	var denom: float = maxf((1.0 + path_bonus + global_speed_bonus + hero_s) * buff_speed_mult, 0.001)
	var interval: float = maxf(td.attack_speed / denom, 0.05)
	var aura_buffs: Array = []
	for bs in buff_sources:
		if bs.get("type") == "speed":
			aura_buffs.append(bs)
	return {
		"base_interval": td.attack_speed,
		"path_bonus": path_bonus,
		"global_bonus": global_speed_bonus,
		"hero_bonus": hero_s,
		"buff_mult": buff_speed_mult,
		"aura_buffs": aura_buffs,
		"final_interval": interval,
		"attacks_per_sec": 1.0 / interval if interval > 0 else 0.0,
	}


func get_range_breakdown() -> Dictionary:
	var td := tower_data as TowerCollectionData
	if not td:
		return {}
	var path_bonus: float = 0.0
	for i in td.upgrade_paths.size():
		var p := td.upgrade_paths[i] as TowerUpgradePath
		if p: path_bonus += p.range_bonus_per_tier * _in_game_path_levels[i]
	path_bonus += ability_range_bonus
	var hero_r: float = (hero_level - 1) * 0.06
	var final_range: float = td.attack_range * (1.0 + path_bonus + global_range_bonus + hero_r)
	return {
		"base": td.attack_range,
		"path_bonus": path_bonus,
		"global_bonus": global_range_bonus,
		"hero_bonus": hero_r,
		"final": final_range,
	}


## 能力脚本注入的自定义特殊描述（在 ability_process 中更新）
var ability_special_bonuses: Array[String] = []

## 获取特殊加成列表（大型伤害、大型穿透等）
func get_special_bonuses() -> Array[String]:
	var specials: Array[String] = []
	if buff_giant_pierce:
		specials.append("大型穿透：控制效果可作用于大型单位")
	if armor_penetration > 0:
		specials.append("护甲穿透：降低%d级有效护甲" % armor_penetration)
	for s in ability_special_bonuses:
		specials.append(s)
	return specials


## 根据升级层数计算实际伤害
func _get_effective_damage() -> float:
	var td := tower_data as TowerCollectionData
	if not td: return 0.0
	var bonus: float = 0.0
	for i in td.upgrade_paths.size():
		var p := td.upgrade_paths[i] as TowerUpgradePath
		if p: bonus += p.damage_bonus_per_tier * _in_game_path_levels[i]
	bonus += ability_damage_bonus
	var hero_bonus: float = (hero_level - 1) * 0.12   # +12% per level
	return td.base_damage * (1.0 + bonus + global_damage_bonus + hero_bonus + terrain_damage_bonus) * buff_damage_mult

## 根据升级层数计算实际攻击间隔（秒）
func _get_effective_attack_interval() -> float:
	var td := tower_data as TowerCollectionData
	if not td: return 1.0
	var bonus: float = 0.0
	for i in td.upgrade_paths.size():
		var p := td.upgrade_paths[i] as TowerUpgradePath
		if p: bonus += p.speed_bonus_per_tier * _in_game_path_levels[i]
	bonus += ability_speed_bonus
	var hero_spd: float = (hero_level - 1) * 0.08   # +8% speed per level
	var denom: float = maxf((1.0 + bonus + global_speed_bonus + hero_spd) * buff_speed_mult, 0.001)
	return max(td.attack_speed / denom, 0.05)

## 根据升级层数计算实际攻击范围，并同步更新碰撞圆
func apply_stat_upgrades() -> void:
	var td := tower_data as TowerCollectionData
	if not td: return
	var bonus: float = 0.0
	for i in td.upgrade_paths.size():
		var p := td.upgrade_paths[i] as TowerUpgradePath
		if p: bonus += p.range_bonus_per_tier * _in_game_path_levels[i]
	bonus += ability_range_bonus
	var hero_range: float = (hero_level - 1) * 0.06
	var new_range: float = td.attack_range * (1.0 + bonus + global_range_bonus + hero_range)
	if attack_shape and attack_shape.shape and attack_shape.shape is CircleShape2D:
		attack_shape.shape.radius = new_range
	# 同步 AttackRange 独立半径字段，确保升级后的范围立即生效
	if attack_range:
		attack_range.attack_radius = new_range
	_effective_range = new_range
	queue_redraw()
#endregion

#region COMBAT
func _fire_at(tgt: Area2D) -> void:
	_current_target = tgt   # 记录当前目标供旋转用
	var td := tower_data as TowerCollectionData
	var dmg: float = _get_effective_damage()

	# 标记增伤光环（辣椒P3T5等）：攻击被标记敌人时额外伤害
	if buff_mark_bonus > 0.0 and is_instance_valid(tgt):
		var effs = tgt.get("_active_effects")
		if effs:
			for eff in effs:
				if eff.get("type") == 5:   # BulletEffect.Type.MARK = 5
					dmg *= (1.0 + buff_mark_bonus)
					break

	# 切换到射击纹理
	if _shoot_texture:
		if _is_rotating_tower:
			_attack_spr.texture = _shoot_texture
		else:
			_base_spr.texture = _shoot_texture
		_shoot_timer = shoot_flash_duration

	# 能力优先处理攻击
	if _ability and _ability.do_attack(tgt, dmg, td):
		return

	if td == null:
		if tgt.has_method("take_damage"):
			tgt.take_damage(dmg)
		return

	# bullet_speed == 0 → 瞬间命中，不生成子弹实体
	if td.bullet_speed <= 0.0:
		CombatService.deal_damage(
			{"source_tower": self, "armor_penetration": armor_penetration,
			 "pierce_giant": false, "ignore_dodge": false},
			tgt, dmg, td.bullet_effects
		)
		return

	# Hitscan 模式：立即判定伤害 + Tween 视觉飞行
	if td.use_hitscan:
		_fire_hitscan(tgt, dmg, td)
		return

	# 生成并发射子弹（优先从对象池获取）
	var bullet: Node
	if bullet_pool and not td.bullet_scene:
		bullet = bullet_pool.acquire()
		if bullet == null:
			bullet = BULLET_SCENE.instantiate()  # 池耗尽时 fallback
	else:
		var scene: PackedScene = td.bullet_scene if td.bullet_scene else BULLET_SCENE
		bullet = scene.instantiate()
	bullet.global_position = global_position
	bullet.target          = tgt
	bullet.damage          = dmg
	bullet.move_speed      = td.bullet_speed
	bullet.effects         = td.bullet_effects
	bullet.attack_type     = td.attack_type
	bullet.bullet_emoji    = td.bullet_emoji
	bullet.armor_penetration = armor_penetration
	bullet.source_tower    = self
	if bullet_pool and not td.bullet_scene:
		bullet._pool = bullet_pool
	get_tree().current_scene.add_child(bullet)


## Hitscan 攻击：立即结算伤害，视觉用 Tween 飞行 emoji
func _fire_hitscan(tgt: Area2D, dmg: float, td: TowerCollectionData) -> void:
	# 1. 立即结算伤害
	var tgt_pos: Vector2 = tgt.global_position if is_instance_valid(tgt) else global_position
	CombatService.deal_damage(
		{"source_tower": self, "armor_penetration": armor_penetration,
		 "pierce_giant": buff_giant_pierce, "ignore_dodge": false},
		tgt, dmg, td.bullet_effects
	)

	# 2. 视觉飞行动画（轻量 Node2D + Tween，不影响物理）
	if not SettingsManager.hit_vfx_enabled:
		return
	var vfx := Node2D.new()
	vfx.global_position = global_position
	vfx.z_index = 15
	var lbl := Label.new()
	lbl.text = td.bullet_emoji if td.bullet_emoji != "" else "⚫"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.position = Vector2(-10, -10)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vfx.add_child(lbl)
	get_tree().current_scene.add_child(vfx)

	# Tween 飞行：从炮台飞到目标位置
	var flight_time: float = global_position.distance_to(tgt_pos) / maxf(td.bullet_speed, 200.0)
	flight_time = clampf(flight_time, 0.05, 0.3)  # 限制飞行时间
	var tw := vfx.create_tween()
	tw.tween_property(vfx, "global_position", tgt_pos, flight_time)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.1)
	tw.tween_callback(vfx.queue_free)


## ═══ 能力系统 ═══

func _attach_ability() -> void:
	var td := tower_data as TowerCollectionData
	if td == null:
		return
	if ABILITY_MAP.has(td.tower_id):
		var scr: GDScript = ABILITY_MAP[td.tower_id]
		_ability = TowerAbility.new()
		_ability.set_script(scr)
		_ability.tower = self
		add_child(_ability)
		_ability.on_placed()


## ═══ 能力辅助方法 ═══

## 返回攻击范围内的所有敌人（委托给 AttackRange 直接物理查询）
## override_attack_type: 传入 >= 0 可覆盖炮台自身的 attack_type（用于英雄升级解锁对空）
func get_enemies_in_range(override_attack_type: int = -1) -> Array:
	if not is_instance_valid(attack_range):
		return []
	var _atk_type: int = 2
	if override_attack_type >= 0:
		_atk_type = override_attack_type
	else:
		var _td := tower_data as TowerCollectionData
		if _td:
			_atk_type = _td.attack_type
	return attack_range.get_enemies_in_range(_atk_type)

## 返回实际伤害（供能力脚本调用）
func get_effective_damage() -> float:
	return _get_effective_damage()

## 生成并发射子弹（带可选溅射参数和自定义子弹场景）
func spawn_bullet_at(tgt: Area2D, dmg: float, spd: float, effects: Array, emoji: String, splash: float = 0.0, splash_ratio: float = 0.5, scene: PackedScene = null) -> Node:
	if not is_instance_valid(tgt):
		return null
	var bullet: Node
	if bullet_pool and scene == null:
		bullet = bullet_pool.acquire()
		if bullet == null:
			bullet = BULLET_SCENE.instantiate()
		else:
			bullet._pool = bullet_pool
	else:
		var s: PackedScene = scene if scene else BULLET_SCENE
		bullet = s.instantiate()
	bullet.global_position = global_position
	bullet.target          = tgt
	bullet.damage          = dmg
	bullet.move_speed      = spd
	bullet.effects         = effects
	bullet.bullet_emoji    = emoji
	bullet.splash_radius   = splash
	bullet.splash_damage_ratio = splash_ratio
	bullet.source_tower = self
	if buff_giant_pierce:
		bullet.pierce_giant = true
	bullet.armor_penetration = armor_penetration
	get_tree().current_scene.add_child(bullet)
	return bullet

## 查找指定半径内的其他已放置塔楼
func get_nearby_towers(radius: float) -> Array:
	var result: Array = []
	for t in get_tree().get_nodes_in_group("tower"):
		if t == self or not is_instance_valid(t):
			continue
		if t.is_preview:
			continue
		if t.global_position.distance_to(global_position) <= radius:
			result.append(t)
	return result
#endregion

#region VISUALS
## 刷新炮台上方 buff 图标（仅选中时显示）
func _refresh_buff_icons() -> void:
	if is_preview:
		return
	# 未选中时隐藏 buff 图标
	if not show_range:
		if is_instance_valid(_buff_icon_container):
			_buff_icon_container.visible = false
		_last_buff_count = -1   # 下次选中时强制重建
		return
	# 去重：按 source_id 只显示一个图标
	var seen_ids: Dictionary = {}
	var unique_emojis: Array[String] = []
	for bs in buff_sources:
		var sid = bs.get("source_id", 0)
		if not seen_ids.has(sid):
			seen_ids[sid] = true
			unique_emojis.append(str(bs.get("emoji", "⬆")))

	if unique_emojis.size() == _last_buff_count:
		return   # 无变化，跳过重建
	_last_buff_count = unique_emojis.size()

	# 清理旧容器
	if is_instance_valid(_buff_icon_container):
		_buff_icon_container.queue_free()
		_buff_icon_container = null

	if unique_emojis.is_empty():
		return

	# 创建图标行
	_buff_icon_container = HBoxContainer.new()
	_buff_icon_container.add_theme_constant_override("separation", 2)
	_buff_icon_container.position = Vector2(-unique_emojis.size() * 13.0, -80)
	_buff_icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buff_icon_container.z_index = 8

	for emoji in unique_emojis:
		var lbl := Label.new()
		lbl.text = emoji
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_buff_icon_container.add_child(lbl)

	add_child(_buff_icon_container)


func flash_attack_range(color: Color) -> void:
	_flash_color = color
	_flash_alpha = 0.4
	queue_redraw()

## 触发更强烈的爆炸闪光（炸弹类塔专用，alpha 更高、更醒目）
func flash_explosion(color: Color = Color(1.0, 0.5, 0.0)) -> void:
	_flash_color = color
	_flash_alpha = 0.8
	queue_redraw()


## 公开方法：返回实际攻击间隔（供 BattleScene 升级面板显示）
func _get_display_range() -> float:
	if _effective_range >= 0.0:
		return _effective_range
	return tower_data.attack_range if tower_data else 50.0

## 英雄升级时调用（更新技能参数 + 射程）
func on_hero_level_up() -> void:
	if _ability and _ability.has_method("on_level_changed"):
		_ability.on_level_changed(hero_level)

func notify_damage(amount: float) -> void:
	stat_damage_dealt += amount

func notify_kill() -> void:
	stat_kills += 1

func get_effective_attack_interval() -> float:
	return _get_effective_attack_interval()


#endregion

#region GLOBAL_UPGRADES
## 应用全局升级加成（由 BattleScene 在升级选中或新塔放置时调用）
## upgrades:       当前局已选的 Array[GlobalUpgradeData]
## synergy_active: Dictionary{ upgrade_id → true }，由 BattleScene._check_synergies() 计算
func apply_global_buffs(upgrades: Array, synergy_active: Dictionary = {}) -> void:
	global_damage_bonus  = 0.0
	global_speed_bonus   = 0.0
	global_range_bonus   = 0.0
	global_cost_discount = 0.0
	global_armor_pen_bonus = 0.0
	global_dot_bonus     = 0.0
	global_crit_bonus    = 0.0
	global_mark_bonus    = 0.0
	global_slow_bonus    = 0.0
	var td := tower_data as TowerCollectionData
	if td == null:
		return
	for upg_raw in upgrades:
		var upg := upg_raw as GlobalUpgradeData
		if upg == null:
			continue
		if not _upgrade_matches_tower(upg, td.tower_id, synergy_active):
			continue
		if upg.stat_type == GlobalUpgradeData.StatType.DAMAGE:
			global_damage_bonus  += upg.stat_bonus
		elif upg.stat_type == GlobalUpgradeData.StatType.SPEED:
			global_speed_bonus   += upg.stat_bonus
		elif upg.stat_type == GlobalUpgradeData.StatType.RANGE:
			global_range_bonus   += upg.stat_bonus
		elif upg.stat_type == GlobalUpgradeData.StatType.COST:
			global_cost_discount += upg.stat_bonus
		elif upg.stat_type == GlobalUpgradeData.StatType.ARMOR_PEN:
			global_armor_pen_bonus += upg.stat_bonus
		elif upg.stat_type == GlobalUpgradeData.StatType.DOT_BONUS:
			global_dot_bonus     += upg.stat_bonus
		elif upg.stat_type == GlobalUpgradeData.StatType.CRIT:
			global_crit_bonus    += upg.stat_bonus
		elif upg.stat_type == GlobalUpgradeData.StatType.MARK:
			global_mark_bonus    += upg.stat_bonus
		elif upg.stat_type == GlobalUpgradeData.StatType.CONTROL:
			global_slow_bonus    += upg.stat_bonus
	# 立刻刷新攻击范围（range 加成需同步到 attack_range.attack_radius）
	if attack_range and td:
		var path_bonus: float = 0.0
		for i in td.upgrade_paths.size():
			var p := td.upgrade_paths[i] as TowerUpgradePath
			if p:
				path_bonus += p.range_bonus_per_tier * _in_game_path_levels[i]
		var hero_range: float = (hero_level - 1) * 0.06   # +6% range per level
		var new_r: float = td.attack_range * (1.0 + path_bonus + global_range_bonus + hero_range)
		attack_range.attack_radius = new_r
		if attack_shape and attack_shape.shape is CircleShape2D:
			attack_shape.shape.radius = new_r
		_effective_range = new_r
		queue_redraw()


## 判断一条全局升级是否作用于本炮台
func _upgrade_matches_tower(upg: GlobalUpgradeData, tid: String, synergy_active: Dictionary) -> bool:
	if upg.upgrade_type == GlobalUpgradeData.UpgradeType.GLOBAL_STAT:
		return true
	elif upg.upgrade_type == GlobalUpgradeData.UpgradeType.TOWER_STAT:
		return upg.target_tower_id == "" or upg.target_tower_id == tid
	elif upg.upgrade_type == GlobalUpgradeData.UpgradeType.COST_REDUCTION:
		return upg.target_tower_id == "" or upg.target_tower_id == tid
	elif upg.upgrade_type == GlobalUpgradeData.UpgradeType.SYNERGY:
		# 羁绊升级：必须已激活（required_tower_ids 全部已放置）
		if not synergy_active.get(upg.upgrade_id, false):
			return false
		# 目标判定：target_tower_ids（多目标）或 target_tower_id（单目标）
		if upg.target_tower_ids.size() > 0:
			return tid in upg.target_tower_ids
		return upg.target_tower_id == "" or upg.target_tower_id == tid
	return false
#endregion

#region PLACEMENT
## 处理炮台点击（放置后）— 单击/单次 tap 即可打开升级面板
func _on_tower_input(_viewport, event, _shape_idx) -> void:
	if is_preview:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tower_tapped.emit(self)
	elif event is InputEventScreenTouch and event.pressed:
		tower_tapped.emit(self)


func _update_can_place():

	var overlapping = get_overlapping_areas()

	if tower_data and tower_data.place_on_path_only:
		# 路面陷阱（捕兽夹/带刺铁网）：必须压在路上，且不能压其他塔
		var on_path := false
		can_place = true
		for area in overlapping:
			if area.is_in_group("path"):
				on_path = true
			if area.is_in_group("block") or area.is_in_group("tower"):
				can_place = false
				break
		if not on_path:
			can_place = false
	else:
		can_place = true
		for area in overlapping:
			if area.is_in_group("block") or area.is_in_group("path") or area.is_in_group("tower"):
				can_place = false
				break

	queue_redraw()


func _draw():

	# ── 英雄地形圆（受范围显示设置控制）──
	var _rd_terrain: int = SettingsManager.range_display if SettingsManager else 1
	var _show_terrain: bool = (_rd_terrain == 2) or (_rd_terrain == 1 and show_range)
	if not is_preview and terrain_radius > 0.0 and terrain_color.a > 0.0 and _show_terrain:
		draw_circle(Vector2.ZERO, terrain_radius, terrain_color)
		var edge_color := Color(terrain_color.r, terrain_color.g, terrain_color.b, 0.45)
		draw_arc(Vector2.ZERO, terrain_radius, 0.0, TAU, 64, edge_color, 2.5)

	# 持续范围圆（根据设置：0=关闭, 1=仅选中, 2=常驻）
	var _rd: int = SettingsManager.range_display if SettingsManager else 1
	var _should_show_range: bool = (_rd == 2) or (_rd == 1 and show_range)
	if not is_preview and _should_show_range:
		var r: float = terrain_radius if terrain_radius > 0.0 else (_get_display_range() if tower_data else 50.0)
		var alpha_fill: float = 0.18 if show_range else 0.08   # 常驻时更淡
		var alpha_edge: float = 0.6 if show_range else 0.25
		draw_circle(Vector2.ZERO, r, Color(1.0, 1.0, 0.0, alpha_fill))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1.0, 1.0, 0.0, alpha_edge), 3.0)
		if show_range:
			return

	# 攻击闪光（已放置的瞬发塔）
	if not is_preview and _flash_alpha > 0.0:
		var flash := Color(_flash_color.r, _flash_color.g, _flash_color.b, _flash_alpha)
		var radius := 50.0
		if tower_data:
			radius = _get_display_range()
		draw_circle(Vector2.ZERO, radius, flash)
		return

	if not is_preview:
		return

	# 英雄预览：显示地形圆 + 放置有效性
	if terrain_radius > 0.0 and terrain_color.a > 0.0:
		draw_circle(Vector2.ZERO, terrain_radius, terrain_color)
		var edge_color := Color(terrain_color.r, terrain_color.g, terrain_color.b, 0.45)
		draw_arc(Vector2.ZERO, terrain_radius, 0.0, TAU, 64, edge_color, 2.5)

	var color: Color

	if can_place:
		color = Color(0, 1, 0, 0.4)
	else:
		color = Color(1, 0, 0, 0.4)

	var radius = 50.0
	if terrain_radius > 0.0:
		radius = terrain_radius
	elif tower_data:
		radius = _get_display_range()

	draw_circle(Vector2.ZERO, radius, color)
#endregion
