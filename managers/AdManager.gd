extends Node

## 激励广告管理器
## - Android 真机：使用 Google AdMob SDK（通过 poing-studios/godot-admob-plugin）
## - PC / 无插件：fallback 到占位弹窗（开发测试用）

# ── AdMob 配置 ──────────────────────────────────────────────────────────
## 正式 App ID 和广告单元 ID（上架前切换 _use_test_ads = false）
const APP_ID: String           = "ca-app-pub-4350879495767907~4281290936"
const REWARDED_AD_ID: String   = "ca-app-pub-4350879495767907/9201477527"
## Google 官方测试 ID（开发阶段必须使用，避免违反 AdMob 政策）
const TEST_REWARDED_ID: String = "ca-app-pub-3940256099942544/5224354917"

## 开发阶段使用测试广告（上架前改为 false）
@export var use_test_ads: bool = true

# ── 内部状态 ────────────────────────────────────────────────────────────
var _admob = null                         # AdMob 单例（Engine.get_singleton）
var _rewarded_loaded: bool = false        # 激励广告是否已加载
var _on_reward_callback: Callable = Callable()
var _on_cancel_callback: Callable = Callable()
var _reward_earned: bool = false          # 用户是否已获得奖励（防止关闭时重复回调）


func _ready() -> void:
	# 检查 AdMob 插件是否可用（仅 Android 真机 + 安装插件时有效）
	if Engine.has_singleton("AdMob"):
		_admob = Engine.get_singleton("AdMob")
		var config := {
			"is_for_child_directed_treatment": false,
			"is_real": not use_test_ads,
			"max_ad_content_rating": "G",
		}
		_admob.initialize(config)

		# 连接 AdMob 信号
		if _admob.has_signal("rewarded_ad_loaded"):
			_admob.rewarded_ad_loaded.connect(_on_rewarded_loaded)
		if _admob.has_signal("rewarded_ad_failed_to_load"):
			_admob.rewarded_ad_failed_to_load.connect(_on_rewarded_failed)
		if _admob.has_signal("rewarded_interstitial_ad_loaded"):
			_admob.rewarded_interstitial_ad_loaded.connect(_on_rewarded_loaded)
		if _admob.has_signal("user_earned_reward"):
			_admob.user_earned_reward.connect(_on_user_earned_reward)
		if _admob.has_signal("rewarded_ad_closed"):
			_admob.rewarded_ad_closed.connect(_on_rewarded_closed)

		# 预加载第一个广告
		_load_rewarded_ad()
	else:
		push_warning("[AdManager] AdMob 插件未安装，使用占位模式（PC开发）")


# ═══════════════════════════════════════════════════════════════════════
# 公开接口（与原来完全兼容，5个调用位置无需修改）
# ═══════════════════════════════════════════════════════════════════════

## 显示激励广告
## on_complete: 广告成功看完后调用
## on_cancel:   用户跳过/关闭/加载失败时调用
func show_rewarded_ad(on_complete: Callable, on_cancel: Callable = Callable()) -> void:
	_on_reward_callback = on_complete
	_on_cancel_callback = on_cancel
	_reward_earned = false

	if _admob != null and _rewarded_loaded:
		_admob.show_rewarded_ad()
	else:
		# 插件不可用 或 广告未加载 → 占位模式
		_show_placeholder_ad(on_complete, on_cancel)


## 广告是否已准备好（可选：UI 可用此判断是否显示广告按钮）
func is_rewarded_ad_ready() -> bool:
	return _admob != null and _rewarded_loaded


# ═══════════════════════════════════════════════════════════════════════
# AdMob 内部
# ═══════════════════════════════════════════════════════════════════════

func _load_rewarded_ad() -> void:
	if _admob == null:
		return
	var ad_id: String = TEST_REWARDED_ID if use_test_ads else REWARDED_AD_ID
	_admob.load_rewarded_ad(ad_id)


func _on_rewarded_loaded() -> void:
	_rewarded_loaded = true


func _on_rewarded_failed(_error_code) -> void:
	_rewarded_loaded = false
	# 加载失败，30秒后自动重试
	get_tree().create_timer(30.0).timeout.connect(_load_rewarded_ad, CONNECT_ONE_SHOT)


func _on_user_earned_reward(_type, _amount) -> void:
	_reward_earned = true
	if _on_reward_callback.is_valid():
		_on_reward_callback.call()
	_on_reward_callback = Callable()
	# 预加载下一个广告
	_rewarded_loaded = false
	_load_rewarded_ad()


func _on_rewarded_closed() -> void:
	# 如果用户关闭广告但没有获得奖励 → 视为取消
	if not _reward_earned:
		if _on_cancel_callback.is_valid():
			_on_cancel_callback.call()
		_on_cancel_callback = Callable()
	# 重新加载
	if not _rewarded_loaded:
		_load_rewarded_ad()


# ═══════════════════════════════════════════════════════════════════════
# 占位模式（PC 开发 / 插件未安装时的 fallback）
# ═══════════════════════════════════════════════════════════════════════

func _show_placeholder_ad(on_complete: Callable, on_cancel: Callable) -> void:
	var dlg := ConfirmDialog.show_dialog(
		get_tree().get_root(),
		"（模拟激励广告）\n\n点击「领取奖励」获得广告奖励",
		"领取奖励",
		"跳过广告"
	)
	dlg.confirmed.connect(func():
		if on_complete.is_valid(): on_complete.call()
	)
	dlg.canceled.connect(func():
		if on_cancel.is_valid(): on_cancel.call()
	)
