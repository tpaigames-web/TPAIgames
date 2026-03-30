extends Node

## 炮台资源注册表 Autoload
## 集中管理所有炮台资源路径、稀有度颜色等全局常量，
## 避免各 UI 脚本重复定义。

# ── 炮台资源路径 ──────────────────────────────────────────────────────
const TOWER_RESOURCE_PATHS: Array[String] = [
	"res://data/towers/scarecrow_collection.tres",
	"res://data/towers/water_pipe_collection.tres",
	"res://data/towers/farmer_collection.tres",
	"res://data/towers/bear_trap_collection.tres",
	"res://data/towers/beehive_collection.tres",
	"res://data/towers/farm_cannon_collection.tres",
	"res://data/towers/barbed_wire_collection.tres",
	"res://data/towers/windmill_collection.tres",
	"res://data/towers/seed_shooter_collection.tres",
	"res://data/towers/mushroom_bomb_collection.tres",
	"res://data/towers/chili_flamer_collection.tres",
	"res://data/towers/watchtower_collection.tres",
	"res://data/towers/sunflower_collection.tres",
	"res://data/towers/hero_farmer_collection.tres",
	"res://data/towers/farm_guardian_collection.tres",
]

# ── 稀有度常量 ────────────────────────────────────────────────────────
const RARITY_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.85),  # 0 白
	Color(0.2,  0.75, 0.2 ),  # 1 绿
	Color(0.2,  0.5,  0.95),  # 2 蓝
	Color(0.7,  0.2,  0.9 ),  # 3 紫
	Color(1.0,  0.55, 0.0 ),  # 4 橙
]
const RARITY_NAMES: Array[String] = ["白", "绿", "蓝", "紫", "橙"]

# ── 翻译辅助 ─────────────────────────────────────────────────────────
## 通过 game_data.csv 的 TOWER_xxx 键获取炮台显示名称
## 若翻译键不存在则回退到 data.display_name
static func get_tower_display_name(tower_id: String, fallback: String = "") -> String:
	var key := "TOWER_" + tower_id.to_upper()
	var result := tr(key)
	if result != key:
		return result
	return fallback

## 通过 game_data.csv 的 ENEMY_xxx 键获取敌人显示名称
## 若翻译键不存在则回退到 data.display_name
static func get_enemy_display_name(enemy_id: String, fallback: String = "") -> String:
	var key := "ENEMY_" + enemy_id.to_upper()
	var result := tr(key)
	if result != key:
		return result
	return fallback

## 通过 game_data.csv 的 ITEM_xxx 键获取道具显示名称
static func get_item_display_name(item_id: String, fallback: String = "") -> String:
	var key := "ITEM_" + item_id.to_upper()
	var result := tr(key)
	if result != key:
		return result
	return fallback

## 通用显示名称：优先用翻译键，否则用 data.display_name
static func tr_tower_name(data: Resource) -> String:
	var tid: String = data.get("tower_id") as String
	var dname: String = data.get("display_name") as String
	if tid == null or tid == "":
		return dname if dname else ""
	return get_tower_display_name(tid, dname if dname else tid)

static func tr_item_name(data: Resource) -> String:
	var iid: String = data.get("item_id") as String
	var dname: String = data.get("display_name") as String
	if iid == null or iid == "":
		return dname if dname else ""
	return get_item_display_name(iid, dname if dname else iid)

static func tr_enemy_name(data: Resource) -> String:
	var eid: String = data.get("enemy_id") as String
	var dname: String = data.get("display_name") as String
	if eid == null or eid == "":
		return dname if dname else ""
	return get_enemy_display_name(eid, dname if dname else eid)

# ── 缓存 ──────────────────────────────────────────────────────────────
var _all_resources: Array = []
var _by_rarity: Dictionary = {}

## 获取所有炮台资源（懒加载，首次调用时读取 .tres 文件）
func get_all_resources() -> Array:
	_ensure_loaded()
	return _all_resources

## 获取按稀有度分组的字典：{rarity:int → [TowerCollectionData, ...]}
func get_towers_by_rarity() -> Dictionary:
	_ensure_loaded()
	return _by_rarity

func _ensure_loaded() -> void:
	if not _all_resources.is_empty():
		return
	for path in TOWER_RESOURCE_PATHS:
		var res = load(path)
		if res == null:
			push_warning("TowerResourceRegistry: 无法加载 " + path)
			continue
		_all_resources.append(res)
		var rarity_val = res.get("rarity")
		if rarity_val == null:
			continue
		var r: int = int(rarity_val)
		if r not in _by_rarity:
			_by_rarity[r] = []
		_by_rarity[r].append(res)
