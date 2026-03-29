extends Node

## 金币或钻石发生变化时发出（UI 监听此信号自动刷新显示）
signal currency_changed

## 玩家等级提升时发出
signal level_changed(new_level: int)

const MAX_LEVEL: int = 100

var is_guest: bool = false
var player_name: String = "农场主"
var level: int = 1
var gold: int = 0
var gems: int = 0
var vouchers: int = 0

## 经验值
var xp: int = 0
var xp_to_next_level: int = 1000   # 首级需 1000 XP；公式：1000 + (level-1)*500

## 付费通行证（RM 8.88 永久激活）
var has_paid_pass: bool = false

## 已领取奖励记录（存储等级编号，避免重复领取）
var claimed_free_rewards: Array[int] = []
var claimed_paid_rewards: Array[int] = []

## 头像索引（0=稻草人  1=老鼠  2=松鼠）
var selected_avatar: int = 0

## 战绩统计
var games_played: int = 0
var games_won: int = 0
var enemies_defeated: int = 0
var achievements_unlocked: int = 0

## 各关卡星级存档（key: "day1" / "day1_challenge" / "day2" / ... → 0~3 星，0 = 未通关）
var level_stars: Dictionary = {}

## 关卡宝箱领取记录（key: "day1_normal" / "day1_challenge" → true = 已领取）
var level_chest_claimed: Dictionary = {}

## 上次领取广告奖励的 Unix 时间戳（0 = 从未领取，新账号必定有奖励）
var last_ad_reward_time: int = 0

## 已解锁到的最大关卡（Day 1 初始解锁）
var max_unlocked_day: int = 1

## 无限模式最高波数记录（key: "day1" → 最高波数）
var best_endless_wave: Dictionary = {}
## 临时标记：刚解锁的关卡编号，BattleTab 播放解锁动画后清零
var newly_unlocked_day: int = 0

## 待领取宝箱类型（-1=无，0=木，1=铁，2=金）
## 槽位满时看广告保留，下次有空槽位时可领取
var pending_chest_type: int = -1

## ── 宝箱槽位系统 ─────────────────────────────────────────────────────
## chest_type: -1=空, 0=木, 1=铁, 2=金
## unlock_start_unix: -1=未开始解锁, >=0=开始时间戳
var chest_slots: Array = [
	{"chest_type": -1, "unlock_start_unix": -1},
	{"chest_type": -1, "unlock_start_unix": -1},
	{"chest_type": -1, "unlock_start_unix": -1},
	{"chest_type": -1, "unlock_start_unix": -1},
]

## 各宝箱类型的解锁时间（秒）：木3h / 铁8h / 金12h
const CHEST_UNLOCK_SECS: Array[int] = [10800, 28800, 43200]

## 宝箱资源路径（按类型索引）
const CHEST_PATHS_BY_TYPE: Array[String] = [
	"res://data/chests/wooden_chest.tres",
	"res://data/chests/iron_chest.tres",
	"res://data/chests/golden_chest.tres",
]

## 将宝箱加入首个空槽位；无空槽返回 false
func add_chest_to_slot(chest_type: int) -> bool:
	for i in chest_slots.size():
		if chest_slots[i]["chest_type"] == -1:
			chest_slots[i] = {"chest_type": chest_type, "unlock_start_unix": -1}
			return true
	return false

## 检查是否有任意槽位正在解锁
func _is_any_chest_unlocking() -> bool:
	for slot in chest_slots:
		if slot["chest_type"] != -1 and slot["unlock_start_unix"] != -1:
			return true
	return false

## 开始解锁指定槽位宝箱；已有其他槽位在解锁中则返回 false
func start_chest_unlock(slot_idx: int) -> bool:
	if _is_any_chest_unlocking():
		return false
	if chest_slots[slot_idx]["chest_type"] == -1:
		return false
	chest_slots[slot_idx]["unlock_start_unix"] = int(Time.get_unix_time_from_system())
	return true

## 判断指定槽位的宝箱是否已解锁完毕
func is_chest_ready(slot_idx: int) -> bool:
	var slot: Dictionary = chest_slots[slot_idx]
	if slot["chest_type"] == -1 or slot["unlock_start_unix"] == -1:
		return false
	var elapsed: int = int(Time.get_unix_time_from_system()) - slot["unlock_start_unix"]
	return elapsed >= CHEST_UNLOCK_SECS[slot["chest_type"]]

## 返回指定槽位剩余解锁秒数（-1=未开始，0=已完成）
func get_chest_remaining_secs(slot_idx: int) -> int:
	var slot: Dictionary = chest_slots[slot_idx]
	if slot["chest_type"] == -1 or slot["unlock_start_unix"] == -1:
		return -1
	var elapsed: int = int(Time.get_unix_time_from_system()) - slot["unlock_start_unix"]
	return maxi(0, CHEST_UNLOCK_SECS[slot["chest_type"]] - elapsed)

## 领取指定槽位宝箱（清空槽位，返回 ChestData；未就绪返回 null）
func claim_chest(slot_idx: int) -> ChestData:
	if not is_chest_ready(slot_idx):
		return null
	var chest_type: int = chest_slots[slot_idx]["chest_type"]
	chest_slots[slot_idx] = {"chest_type": -1, "unlock_start_unix": -1}
	return load(CHEST_PATHS_BY_TYPE[chest_type])

## 加速宝箱解锁（将 unlock_start_unix 提前 speed_secs 秒）
func speed_up_chest(slot_idx: int, speed_secs: int) -> void:
	var slot: Dictionary = chest_slots[slot_idx]
	if slot["chest_type"] == -1 or slot["unlock_start_unix"] == -1:
		return
	var new_start: int = slot["unlock_start_unix"] - speed_secs
	# 最多提前到"恰好解锁完成"时刻，不允许超头
	var earliest: int = int(Time.get_unix_time_from_system()) - CHEST_UNLOCK_SECS[slot["chest_type"]]
	chest_slots[slot_idx]["unlock_start_unix"] = maxi(new_start, earliest)

## 宝石立即完成解锁（将 start_unix 调为"恰好已完成"）
func instant_unlock_chest(slot_idx: int) -> void:
	var slot: Dictionary = chest_slots[slot_idx]
	if slot["chest_type"] == -1 or slot["unlock_start_unix"] == -1:
		return
	chest_slots[slot_idx]["unlock_start_unix"] = int(Time.get_unix_time_from_system()) - CHEST_UNLOCK_SECS[slot["chest_type"]]

func set_guest() -> void:
	is_guest = true
	player_name = "游客"

func set_player_name(new_name: String) -> void:
	var trimmed := new_name.strip_edges()
	if trimmed != "":
		player_name = trimmed

func set_avatar(index: int) -> void:
	selected_avatar = clampi(index, 0, 2)

## 消耗金币。返回 true = 成功（余额足够）
func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	currency_changed.emit()
	return true

func add_gold(amount: int) -> void:
	gold += amount
	currency_changed.emit()

func add_gems(amount: int) -> void:
	gems += amount
	currency_changed.emit()

## 消耗钻石。返回 true = 成功（余额足够）
func spend_gems(amount: int) -> bool:
	if gems < amount:
		return false
	gems -= amount
	currency_changed.emit()
	return true

func add_vouchers(amount: int) -> void:
	vouchers += amount
	currency_changed.emit()

## 消耗券。返回 true = 成功（余额足够）
func spend_vouchers(amount: int) -> bool:
	if vouchers < amount:
		return false
	vouchers -= amount
	currency_changed.emit()
	return true

## 获得经验值，自动处理连续多次升级
func add_xp(amount: int) -> void:
	if level >= MAX_LEVEL:
		xp = 0
		currency_changed.emit()
		return
	xp += amount
	while xp >= xp_to_next_level and level < MAX_LEVEL:
		xp -= xp_to_next_level
		_level_up()
	if level >= MAX_LEVEL:
		xp = 0
	currency_changed.emit()   # XP 条通过 currency_changed 一并刷新

## 内部升级处理（每次只升一级，循环调用）
func _level_up() -> void:
	level += 1
	xp_to_next_level = 1000 + (level - 1) * 500
	level_changed.emit(level)

## 记录已领取的免费奖励等级
func claim_free_reward(lv: int) -> void:
	if lv not in claimed_free_rewards:
		claimed_free_rewards.append(lv)

## 记录已领取的付费奖励等级
func claim_paid_reward(lv: int) -> void:
	if lv not in claimed_paid_rewards:
		claimed_paid_rewards.append(lv)

## 新手教学是否已完成（完成后 BattleTab 隐藏入口卡片）
var tutorial_completed: bool = false

## 剧情是否已观看（观看/跳过后为 true，下次启动跳过剧情）
var story_watched: bool = false

## 商店购买次数追踪（product_id → count）
var shop_purchases: Dictionary = {}

func get_purchase_count(product_id: String) -> int:
	return shop_purchases.get(product_id, 0)

func record_purchase(product_id: String) -> void:
	shop_purchases[product_id] = shop_purchases.get(product_id, 0) + 1

## 消耗品道具库存（item_id → count）
var item_inventory: Dictionary = {}

func get_item_count(item_id: String) -> int:
	return item_inventory.get(item_id, 0)

func add_item(item_id: String, count: int = 1) -> void:
	item_inventory[item_id] = item_inventory.get(item_id, 0) + count
	currency_changed.emit()

func use_item(item_id: String) -> bool:
	if get_item_count(item_id) <= 0:
		return false
	item_inventory[item_id] -= 1
	if item_inventory[item_id] <= 0:
		item_inventory.erase(item_id)
	currency_changed.emit()
	return true

## 碎片商店周期内购买记录（key = "{rng_seed}_{tower_id}"，防止重启后重复购买同周期商品）
var fragment_shop_purchases: Dictionary = {}

## 玩家本地唯一 ID（首次启动生成，持久化存档；日后可与 Google/Firebase ID 绑定）
var player_uuid: String = ""

## 生成标准格式 UUID（使用 Crypto 模块保证随机性）
func _generate_uuid() -> String:
	var crypto := Crypto.new()
	var h := crypto.generate_random_bytes(16).hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]

## ── 木宝箱限时免费（每 6 小时一次）─────────────────────────────────

## 冷却秒数：6 小时
const FREE_WOODEN_CHEST_COOLDOWN_SECS: int = 6 * 3600

## 上次成功领取的 Unix 时间戳（0 = 从未领取过，即立即可领）
var free_wooden_chest_last_unix: int = 0

## 返回是否可以领取（冷却已结束）
func is_free_wooden_chest_ready() -> bool:
	return get_free_wooden_chest_cooldown_remaining() <= 0

## 返回距离下次可领取剩余的秒数（0 表示立即可领）
func get_free_wooden_chest_cooldown_remaining() -> int:
	var now: int = int(Time.get_unix_time_from_system())
	return maxi(0, FREE_WOODEN_CHEST_COOLDOWN_SECS - (now - free_wooden_chest_last_unix))

## 记录本次领取时间戳
func claim_free_wooden_chest() -> void:
	free_wooden_chest_last_unix = int(Time.get_unix_time_from_system())

# ── 存档序列化 ────────────────────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	return {
		"player_name":               player_name,
		"level":                     level,
		"xp":                        xp,
		"xp_to_next_level":          xp_to_next_level,
		"gold":                      gold,
		"gems":                      gems,
		"vouchers":                  vouchers,
		"selected_avatar":           selected_avatar,
		"has_paid_pass":             has_paid_pass,
		"claimed_free_rewards":      claimed_free_rewards,
		"claimed_paid_rewards":      claimed_paid_rewards,
		"shop_purchases":            shop_purchases,
		"item_inventory":            item_inventory,
		"tutorial_completed":        tutorial_completed,
		"story_watched":             story_watched,
		"games_played":              games_played,
		"games_won":                 games_won,
		"enemies_defeated":          enemies_defeated,
		"achievements_unlocked":     achievements_unlocked,
		"free_wooden_chest_last_unix": free_wooden_chest_last_unix,
		"fragment_shop_purchases":    fragment_shop_purchases,
		"player_uuid":                player_uuid,
		"level_stars":                level_stars,
		"level_chest_claimed":        level_chest_claimed,
		"max_unlocked_day":           max_unlocked_day,
		"best_endless_wave":          best_endless_wave,
		"chest_slots":                chest_slots,
		"pending_chest_type":         pending_chest_type,
		"last_ad_reward_time":        last_ad_reward_time,
	}

func load_save_data(dict: Dictionary) -> void:
	player_name               = str(dict.get("player_name",           player_name))
	level                     = int(dict.get("level",                 level))
	xp                        = int(dict.get("xp",                    xp))
	xp_to_next_level          = int(dict.get("xp_to_next_level",      xp_to_next_level))
	gold                      = int(dict.get("gold",                   gold))
	gems                      = int(dict.get("gems",                   gems))
	vouchers                  = int(dict.get("vouchers",               0))
	selected_avatar           = int(dict.get("selected_avatar",        selected_avatar))
	has_paid_pass             = bool(dict.get("has_paid_pass",         has_paid_pass))
	tutorial_completed        = bool(dict.get("tutorial_completed",    tutorial_completed))
	story_watched             = bool(dict.get("story_watched",         story_watched))
	games_played              = int(dict.get("games_played",           games_played))
	games_won                 = int(dict.get("games_won",              games_won))
	enemies_defeated          = int(dict.get("enemies_defeated",       enemies_defeated))
	achievements_unlocked     = int(dict.get("achievements_unlocked",  achievements_unlocked))
	free_wooden_chest_last_unix = int(dict.get("free_wooden_chest_last_unix", 0))

	# Array[int] 字段：JSON 解析后为普通 Array，需逐元素转换
	claimed_free_rewards.clear()
	for v in dict.get("claimed_free_rewards", []):
		claimed_free_rewards.append(int(v))

	claimed_paid_rewards.clear()
	for v in dict.get("claimed_paid_rewards", []):
		claimed_paid_rewards.append(int(v))

	# Dictionary：JSON 保留 key/value 类型，直接赋值
	var sp = dict.get("shop_purchases", {})
	if sp is Dictionary:
		shop_purchases = sp

	var fsp = dict.get("fragment_shop_purchases", {})
	if fsp is Dictionary:
		fragment_shop_purchases = fsp

	var ii = dict.get("item_inventory", {})
	if ii is Dictionary:
		item_inventory = ii

	# UUID：兼容旧存档（字段缺失时自动生成）
	player_uuid = str(dict.get("player_uuid", ""))
	if player_uuid.is_empty():
		player_uuid = _generate_uuid()

	# 关卡星级（兼容旧存档，字段缺失时保持空字典）
	var ls = dict.get("level_stars", {})
	if ls is Dictionary:
		level_stars = ls

	# 关卡宝箱领取记录（兼容旧存档）
	var lc = dict.get("level_chest_claimed", {})
	if lc is Dictionary:
		level_chest_claimed = lc

	# 最大解锁关卡（兼容旧存档，缺失时保持默认 1）
	max_unlocked_day = int(dict.get("max_unlocked_day", 1))

	var bew = dict.get("best_endless_wave", {})
	if bew is Dictionary:
		best_endless_wave = bew

	# 宝箱槽位（兼容旧存档：字段缺失时保持默认空槽）
	var cs = dict.get("chest_slots", null)
	if cs is Array and cs.size() == 4:
		for i in 4:
			var s = cs[i]
			if s is Dictionary:
				chest_slots[i] = {
					"chest_type":        int(s.get("chest_type", -1)),
					"unlock_start_unix": int(s.get("unlock_start_unix", -1)),
				}

	# 待领取宝箱（兼容旧存档）
	pending_chest_type = int(dict.get("pending_chest_type", -1))

	# 广告奖励时间戳（兼容旧存档，缺失 = 0 = 新账号必有奖励）
	last_ad_reward_time = int(dict.get("last_ad_reward_time", 0))
