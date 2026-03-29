extends Node

## 存档管理器 Autoload
## 负责将 UserManager 和 CollectionManager 的数据序列化写入本地 JSON 文件，
## 并在游戏启动时读取恢复。
##
## 存档文件路径：user://save.json
## 关键操作（开宝箱、解锁炮台、购买、领取奖励、改名换头像）后请调用 SaveManager.save()。

const SAVE_PATH: String = "user://save.json"
const SAVE_VERSION: int = 1

func _ready() -> void:
	# Autoload 顺序：SaveManager 排在 UserManager / CollectionManager 之后
	# 此时两者的 _ready() 已完成（基础炮台已写入 unlocked_towers），可安全读档覆盖。
	load_game()

# ── 存档 ────────────────────────────────────────────────────────────────────

func save() -> void:
	var data: Dictionary = {
		"version":    SAVE_VERSION,
		"user":       UserManager.get_save_data(),
		"collection": CollectionManager.get_save_data(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: 无法写入存档 " + SAVE_PATH
				   + "  error=" + str(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

# ── 读档 ────────────────────────────────────────────────────────────────────

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_apply_new_player_defaults()
		save()   # 立即生成存档文件
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: 无法读取存档 " + SAVE_PATH
				   + "  error=" + str(FileAccess.get_open_error()))
		_apply_new_player_defaults()
		return

	var text: String = file.get_as_text()
	file.close()

	var result = JSON.parse_string(text)
	if result == null or not result is Dictionary:
		push_error("SaveManager: 存档格式损坏，使用默认值")
		_apply_new_player_defaults()
		return

	var file_version: int = int(result.get("version", 0))
	if file_version < SAVE_VERSION:
		push_warning("SaveManager: 存档版本 %d < 当前版本 %d，部分字段可能缺失" % [file_version, SAVE_VERSION])

	if result.has("user") and result["user"] is Dictionary:
		UserManager.load_save_data(result["user"])
	if result.has("collection") and result["collection"] is Dictionary:
		CollectionManager.load_save_data(result["collection"])

# ── 新玩家默认值 ──────────────────────────────────────────────────────────────

# ── 战局存档（独立文件，不影响主存档）─────────────────────────────────────────

const BATTLE_SAVE_PATH: String = "user://battle_save.json"

## 判断是否存在有效的战局存档
func has_battle_save() -> bool:
	if not FileAccess.file_exists(BATTLE_SAVE_PATH):
		return false
	var f := FileAccess.open(BATTLE_SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	return data is Dictionary and not data.is_empty()

## 保存战局状态到独立文件
func save_battle(battle_data: Dictionary) -> void:
	var f := FileAccess.open(BATTLE_SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: 无法写入战局存档 " + BATTLE_SAVE_PATH)
		return
	f.store_string(JSON.stringify(battle_data, "\t"))
	f.close()

## 读取战局存档，失败返回空字典
func load_battle() -> Dictionary:
	if not FileAccess.file_exists(BATTLE_SAVE_PATH):
		return {}
	var f := FileAccess.open(BATTLE_SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	return data if data is Dictionary else {}

## 清除战局存档（游戏胜利/失败后调用）
func clear_battle_save() -> void:
	if FileAccess.file_exists(BATTLE_SAVE_PATH):
		DirAccess.remove_absolute(BATTLE_SAVE_PATH)

# ── 新玩家默认值 ──────────────────────────────────────────────────────────────

## 首次启动时给予启动资源，让新玩家可以立即体验购买/开箱流程。
func _apply_new_player_defaults() -> void:
	UserManager.gold = 500
	UserManager.gems = 50
	UserManager.vouchers = 0
	# 新玩家：生成本地唯一 UUID（旧玩家在 load_save_data 内兼容处理）
	if UserManager.player_uuid.is_empty():
		UserManager.player_uuid = UserManager._generate_uuid()
	# BASE_TOWERS 由 CollectionManager._ready() 已默认解锁，此处无需重复处理。
