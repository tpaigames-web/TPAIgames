extends Control

const ACCOUNTS_PATH: String = "user://accounts.json"

@onready var start_button: TextureButton = $StartButton

var _accounts_data: Dictionary = {}


func _ready():
	start_button.pressed.connect(_on_start_pressed)

	_load_accounts()

	# 自动登录上次账号
	var last: String = _accounts_data.get("last_account", "")
	if last != "":
		for acc in _accounts_data.get("accounts", []):
			if acc.get("account") == last:
				_login_as(acc)
				return


func _on_start_pressed() -> void:
	UserManager.set_guest()
	SceneManager.go_home()


# ═══════════════════════════════════════════════════════════════════════
# 账号数据管理（保留以支持自动登录）
# ═══════════════════════════════════════════════════════════════════════
func _load_accounts() -> void:
	if not FileAccess.file_exists(ACCOUNTS_PATH):
		_accounts_data = {"accounts": [], "last_account": ""}
		return
	var file := FileAccess.open(ACCOUNTS_PATH, FileAccess.READ)
	if not file:
		_accounts_data = {"accounts": [], "last_account": ""}
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		_accounts_data = json.data
	else:
		_accounts_data = {"accounts": [], "last_account": ""}


func _login_as(acc: Dictionary) -> void:
	_accounts_data["last_account"] = acc.get("account", "")
	var file := FileAccess.open(ACCOUNTS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_accounts_data, "\t"))
	UserManager.player_name = acc.get("name", "玩家")
	UserManager.is_guest = false
	SaveManager.save()
	SceneManager.go_home()
