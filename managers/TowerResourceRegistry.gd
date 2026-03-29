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
