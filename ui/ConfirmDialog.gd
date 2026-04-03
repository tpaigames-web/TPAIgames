class_name ConfirmDialog extends CanvasLayer

## 通用确认弹窗 — 在编辑器中调整 ConfirmDialog.tscn 的布局
## 面板大小会根据文本内容自动适配
##
## 使用方式:
##   var dlg = ConfirmDialog.show_dialog(self, "提示", "确认", "取消")
##   dlg.confirmed.connect(my_callback)

signal confirmed
signal canceled

@onready var _overlay: ColorRect = $Overlay
@onready var _panel: TextureRect = $Panel
@onready var _margin: MarginContainer = $Panel/Margin
@onready var _message_label: Label = $Panel/Margin/VBox/MessageLabel
@onready var _confirm_btn: TextureButton = $Panel/Margin/VBox/ButtonRow/ConfirmBtn
@onready var _cancel_btn: TextureButton = $Panel/Margin/VBox/ButtonRow/CancelBtn
@onready var _confirm_label: Label = $Panel/Margin/VBox/ButtonRow/ConfirmBtn/ConfirmLabel
@onready var _cancel_label: Label = $Panel/Margin/VBox/ButtonRow/CancelBtn/CancelLabel

## 面板最小/最大宽度（高度自动）
@export var min_width: float = 500.0
@export var max_width: float = 700.0
@export var padding_h: float = 60.0  ## 左右总内边距
@export var padding_v: float = 80.0  ## 上下总内边距
@export var btn_row_height: float = 60.0  ## 按钮行高度


func _ready() -> void:
	_confirm_btn.pressed.connect(_on_confirm)
	_cancel_btn.pressed.connect(_on_cancel)
	_overlay.gui_input.connect(_on_overlay_input)


## 设置弹窗内容并自动调整面板大小
func setup(message: String, confirm_text: String, cancel_text: String) -> void:
	if not is_node_ready():
		await ready
	_message_label.text = message
	_confirm_label.text = confirm_text
	_cancel_label.text = cancel_text

	# 等一帧让 Label 计算好文本尺寸
	await get_tree().process_frame
	_auto_resize()


## 隐藏取消按钮（用于纯提示弹窗）
func hide_cancel() -> void:
	if not is_node_ready():
		await ready
	_cancel_btn.visible = false


## 以指定位置为中心定位面板
func set_center_position(pos: Vector2) -> void:
	if not is_node_ready():
		await ready
	await get_tree().process_frame
	var panel_size: Vector2 = _panel.size
	_panel.position = Vector2(
		clampf(pos.x - panel_size.x / 2, 10, 1070 - panel_size.x),
		clampf(pos.y - panel_size.y / 2, 10, 1910 - panel_size.y)
	)


## 暂停安全模式
func set_pause_safe(enabled: bool) -> void:
	if enabled:
		process_mode = Node.PROCESS_MODE_ALWAYS


## 静态快捷方法 — 一行代码创建弹窗
static func show_dialog(
	parent: Node,
	message: String,
	confirm_text: String,
	cancel_text: String,
	pause_safe: bool = false,
	center_pos: Vector2 = Vector2.ZERO
) -> ConfirmDialog:
	var dlg: ConfirmDialog = preload("res://ui/ConfirmDialog.tscn").instantiate()
	parent.add_child(dlg)
	if pause_safe:
		dlg.set_pause_safe(true)  # 必须在 setup 之前，因为 setup 里有 await
	dlg.setup(message, confirm_text, cancel_text)
	if center_pos != Vector2.ZERO:
		dlg.set_center_position(center_pos)
	return dlg


# ── 内部 ──

func _auto_resize() -> void:
	# 计算文本需要的宽度
	var font: Font = _message_label.get_theme_font("font")
	var font_size: int = _message_label.get_theme_font_size("font_size")
	var text_size: Vector2 = font.get_multiline_string_size(
		_message_label.text, HORIZONTAL_ALIGNMENT_CENTER,
		max_width - padding_h, font_size
	)

	# 按钮大小根据文本自适应
	_auto_fit_button(_confirm_btn, _confirm_label)
	_auto_fit_button(_cancel_btn, _cancel_label)

	# 面板宽度：文本宽度 + 内边距，限制在 min~max 范围
	var btn_total_w: float = _confirm_btn.custom_minimum_size.x + _cancel_btn.custom_minimum_size.x + 30
	var panel_w: float = clampf(maxf(text_size.x + padding_h, btn_total_w + padding_h), min_width, max_width)
	# 面板高度：文本高度 + 按钮行 + 内边距
	var panel_h: float = text_size.y + btn_row_height + padding_v

	# 居中定位
	var vp_size: Vector2 = Vector2(1080, 1920)
	_panel.position = Vector2(
		(vp_size.x - panel_w) / 2,
		(vp_size.y - panel_h) / 2
	)
	_panel.size = Vector2(panel_w, panel_h)

	# 重置 Margin 填充整个 Panel
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _auto_fit_button(btn: TextureButton, lbl: Label) -> void:
	var btn_font: Font = lbl.get_theme_font("font")
	var btn_fs: int = lbl.get_theme_font_size("font_size")
	var text_w: float = btn_font.get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_CENTER, -1, btn_fs).x
	# 按钮宽度 = 文本宽度 + 左右内边距(80px)，最小 140
	var btn_w: float = maxf(text_w + 80, 140)
	btn.custom_minimum_size = Vector2(btn_w, 50)


func _on_confirm() -> void:
	confirmed.emit()
	queue_free()


func _on_cancel() -> void:
	canceled.emit()
	queue_free()


func _on_overlay_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		canceled.emit()
		queue_free()
