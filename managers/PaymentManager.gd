extends Node

## 支付管理器 —— Google Play Billing 接入预留
## ─────────────────────────────────────────────────────────────────────
## 使用方式：
##   PaymentManager.purchase(product_id, price_rm, on_success, on_failure)
##
## 开发阶段（is_real_payment_enabled = false）：
##   直接触发 on_success，无需任何外部服务。
##
## 上架前（is_real_payment_enabled = true）：
##   走真实 Google Play Billing 流程。
##   只需改这一个布尔值，其余代码无需修改。
## ─────────────────────────────────────────────────────────────────────

## 切换开关：false = 模拟付款（开发）  true = 真实付款（上架）
var is_real_payment_enabled: bool = false

# ── 公开接口 ──────────────────────────────────────────────────────────

## 发起购买统一入口
## @param product_id  商品 ID（应与 Google Play Console 中的 SKU 一致）
## @param price_rm    马来西亚令吉价格（显示用，不影响逻辑）
## @param on_success  支付成功回调（无参数）
## @param on_failure  支付失败回调（参数：error_msg: String）
func purchase(product_id: String, price_rm: float,
		on_success: Callable, on_failure: Callable = Callable()) -> void:
	if is_real_payment_enabled:
		_real_google_purchase(product_id, price_rm, on_success, on_failure)
	else:
		_fake_purchase(product_id, on_success)

# ── 内部实现 ──────────────────────────────────────────────────────────

## 模拟付款 —— 开发/测试阶段使用，直接触发成功回调
func _fake_purchase(product_id: String, on_success: Callable) -> void:
	print("[PaymentManager] 模拟付款成功：%s" % product_id)
	if on_success.is_valid():
		on_success.call()

## 真实 Google Play Billing 入口
## 接入时：替换下方 TODO 块，保留函数签名不变
func _real_google_purchase(product_id: String, price_rm: float,
		_on_success: Callable, on_failure: Callable) -> void:
	# ─────────────────────────────────────────────────────────────────
	# TODO: 接入 Google Play Billing SDK
	#
	# 推荐方案：Godot Android Plugin（GodotGooglePlayBilling）
	#
	# 接入步骤：
	#   1. 下载插件 aar 并放入 android/plugins/
	#   2. Project Settings → Export → Android → 勾选 GodotGooglePlayBilling
	#   3. 将下方注释代码取消注释并删除 push_error：
	#
	#      var billing = Engine.get_singleton("GodotGooglePlayBilling")
	#      if billing == null:
	#          if on_failure.is_valid():
	#              on_failure.call("Billing 插件未初始化，请检查导出配置")
	#          return
	#
	#      # 启动连接
	#      billing.startConnection()
	#
	#      # 连接成功后发起购买
	#      billing.connected.connect(
	#          func(): billing.purchase(product_id), CONNECT_ONE_SHOT)
	#
	#      # 购买成功回调
	#      billing.purchases_updated.connect(
	#          func(_purchases): _on_success.call(), CONNECT_ONE_SHOT)
	#
	#      # 购买失败回调
	#      billing.purchase_error.connect(
	#          func(_code, msg):
	#              if on_failure.is_valid(): on_failure.call(str(msg)),
	#          CONNECT_ONE_SHOT)
	#
	# 注意：product_id 必须与 Google Play Console 中配置的 SKU 完全一致。
	# price_rm 参数在真实付款中不使用（价格由 Google Play 后台管理）。
	# ─────────────────────────────────────────────────────────────────
	push_error("[PaymentManager] 真实付款尚未接入  product_id=%s  price=RM%.2f" \
			% [product_id, price_rm])
	if on_failure.is_valid():
		on_failure.call("Google Play Billing 接入中，敬请期待")
