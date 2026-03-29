class_name TutorialGuide
extends CanvasLayer

## 新手教学引导控制器
## 类似植物大战僵尸「疯狂戴夫」风格：底部对话框 + 左侧阿福立绘
## 12 步教学：欢迎 → 炮台 → 金币 → 放塔 → 点击塔 → 升级 → 开始 → 波次强化说明 → 选强化 → 飞行教学 → 放蜂巢 → 结束

signal tutorial_finished
signal request_upgrade_panel   ## 请求 BattleScene 弹出全局升级面板

# ── 教学步骤定义 ────────────────────────────────────────────────────────
# advance: "tap" / "tower_placed" / "game_started" / "tower_tapped"
#          "upgrade_chosen_single" / "upgrade_chosen" / "wave_cleared_1" / "wave_cleared_2"
const STEPS: Array[Dictionary] = [
	# Step 0: 阿福打招呼
	{ "dialog": "农场主你好！我是阿福！\n我们的农场被害虫入侵了，快来帮忙守住农场吧！",
	  "highlight": "", "advance": "tap", "pause": true, "dialog_pos": "bottom" },
	# Step 1: 介绍炮台
	{ "dialog": "这里是炮台区，你可以选择不同的炮台来防御农场。\n每个炮台都有独特的攻击方式！",
	  "highlight": "bottom_panel", "advance": "tap", "pause": true, "dialog_pos": "top" },
	# Step 2: 介绍金币
	{ "dialog": "放置炮台需要金币 🪙\n消灭敌人可以获得更多金币！合理花费很重要哦！",
	  "highlight": "gold_panel", "advance": "tap", "pause": true, "dialog_pos": "bottom" },
	# Step 3: 让玩家放置炮台
	{ "dialog": "试试看！从下面拖一个稻草人炮台\n放到地图上的任意空地。",
	  "highlight": "place_zone", "advance": "tower_placed", "pause": false, "dialog_pos": "top" },
	# Step 4: 点击炮台看看
	{ "dialog": "太棒了！现在点击你刚放置的炮台\n看看它的升级选项！",
	  "highlight": "first_tower", "advance": "tower_tapped", "pause": true, "dialog_pos": "bottom" },
	# Step 5: 让玩家升级一项
	{ "dialog": "每个炮台有多条升级路线\n选择一个升级方向，让炮台变得更强吧！",
	  "highlight": "", "advance": "upgrade_chosen_single", "pause": false, "dialog_pos": "top" },
	# Step 6: 点击播放开始游戏
	{ "dialog": "很好！准备就绪了！\n点击右上角的播放按钮，开始迎击敌人！",
	  "highlight": "speed_btn", "advance": "game_started", "pause": false, "dialog_pos": "bottom" },
	# Step 7: 波1结束后，说明波次强化升级（等 wave_cleared_1 触发）
	{ "dialog": "干得漂亮！每次开始游戏和每隔5波\n你都可以选择一个全局强化，提升所有炮台的能力！",
	  "highlight": "", "advance": "tap", "pause": true, "dialog_pos": "bottom" },
	# Step 8: 让玩家选择波次强化
	{ "dialog": "选一个强化试试吧！",
	  "highlight": "", "advance": "upgrade_chosen", "pause": false, "dialog_pos": "top" },
	# Step 9: 波2刷乌鸦，暂停说明飞行敌人（wave_started_2 触发）
	{ "dialog": "注意！乌鸦是飞行敌人 🐦\n只有标记「全部」的炮台才能攻击它们！\n稻草人打不到飞行敌人哦！",
	  "highlight": "", "advance": "tap", "pause": true, "dialog_pos": "bottom" },
	# Step 10: 提示放蜂巢
	{ "dialog": "试试放一个蜂巢 🍯\n蜂巢可以攻击空中和地面的全部敌人！",
	  "highlight": "place_zone", "advance": "tower_placed", "pause": false, "dialog_pos": "top" },
	# Step 11: 波2结束后，教学结束（wave_cleared_2 触发）
	{ "dialog": "教学结束！接下来就靠你自己了！\n合理搭配炮台，守住我们的农场吧！💪",
	  "highlight": "", "advance": "tap", "pause": true, "dialog_pos": "bottom" },
]

# ── 外部引用（由 BattleScene 设置）────────────────────────────────────
var tutorial_scene: Node = null

# ── 内部状态 ────────────────────────────────────────────────────────────
var _step: int = -1
var _waiting_for_event: bool = false
var _typing_active: bool = false
var _type_timer: float = 0.0
var _visible_chars: int = 0
var _full_text: String = ""
var _active: bool = false
## 教学期间暂存的 time_scale（退出教学时恢复）
var _saved_time_scale: float = 1.0
## 首个被放置的炮台引用（Step 5 高亮用）
var _first_tower: Area2D = null
## 放置引导圈动画计时
var _place_pulse_time: float = 0.0
## （已移除旧 _step5_tap_mode）

# ── 打字机速度 ──────────────────────────────────────────────────────────
const TYPE_SPEED: float = 0.03   ## 每字符间隔（秒）
const PLACE_GUIDE_POS := Vector2(700.0, 320.0)   ## 引导放置位置（敌人入口旁边空地）
const PLACE_GUIDE_RADIUS: float = 80.0

# ── UI 节点 ─────────────────────────────────────────────────────────────
var _overlay: ColorRect
var _highlight_ctrl: Control
var _arrow_lbl: Label
var _bubble_container: Control   ## 气泡框容器（角色+气泡一体）
var _dialog_box: PanelContainer
var _char_sprite: TextureRect
var _name_lbl: Label
var _dialog_lbl: Label
var _tap_hint: Label
var _arrow_tween: Tween
var _place_guide: Node2D   ## 放置引导圈（加到场景树中非 CanvasLayer）


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS   # 即使暂停也能运行
	_build_ui()
	visible = false


# ═══════════════════════════════════════════════════════════════════════════
#  公开 API（由 BattleScene 调用）
# ═══════════════════════════════════════════════════════════════════════════

func start_tutorial(scene: Node) -> void:
	tutorial_scene = scene
	_active = true
	visible = true
	_step = -1
	_advance_step()


## 外部事件通知 ────────────────────────────────────────────────────────────

func notify_tower_placed(tower: Area2D) -> void:
	if not _active: return
	if _first_tower == null:
		_first_tower = tower
	# Step 3: 放置第一个炮台 / Step 10: 放蜂巢
	if (_step == 3 or _step == 10) and _waiting_for_event:
		_waiting_for_event = false
		_hide_place_guide()
		_advance_step()

func notify_game_started() -> void:
	if not _active: return
	if _step == 6 and _waiting_for_event:
		_waiting_for_event = false
		_advance_step()

func notify_tower_tapped() -> void:
	if not _active: return
	if _step == 4 and _waiting_for_event:
		_waiting_for_event = false
		# 恢复暂停让玩家操作升级面板
		if Engine.time_scale == 0.0:
			Engine.time_scale = _saved_time_scale if _saved_time_scale > 0.0 else 1.0
		_advance_step()

## 单塔升级面板中选择了一项升级
func notify_single_upgrade_chosen() -> void:
	if not _active: return
	if _step == 5 and _waiting_for_event:
		_waiting_for_event = false
		_advance_step()

func notify_wave_started(wave_num: int) -> void:
	if not _active: return
	# Wave 2 开始时 → 触发 Step 9（飞行敌人暂停教学）
	if wave_num == 2 and _step >= 9:
		# 已在或超过 Step 9，正常处理
		pass
	elif wave_num == 2 and _step < 9:
		# 强制跳到 Step 9（暂停游戏教学飞行）
		_step = 8
		_advance_step()

## 波次清场通知（由 WaveManager.wave_cleared 信号触发）
func notify_wave_cleared(wave_num: int) -> void:
	if not _active: return
	# Wave 1 清场 → 触发 Step 7（波次强化说明）
	if wave_num == 1 and _step == 6:
		# Step 6 已完成（game_started），推进到 Step 7
		_advance_step()
	elif wave_num == 1 and _step < 7:
		_step = 6
		_advance_step()
	# Wave 2 清场 → 触发 Step 11（教学结束）
	if wave_num == 2 and _step == 10:
		_advance_step()
	elif wave_num == 2 and _step < 11:
		_step = 10
		_advance_step()

## 全局升级面板中选择了一项强化
func notify_upgrade_chosen() -> void:
	if not _active: return
	if _step == 8 and _waiting_for_event:
		_waiting_for_event = false
		_advance_step()


# ═══════════════════════════════════════════════════════════════════════════
#  步骤控制
# ═══════════════════════════════════════════════════════════════════════════

func _advance_step() -> void:
	_step += 1
	if _step >= STEPS.size():
		_finish_tutorial()
		return

	var s: Dictionary = STEPS[_step]

	# 暂停控制
	if s.get("pause", false):
		_saved_time_scale = Engine.time_scale if Engine.time_scale > 0.0 else 1.0
		Engine.time_scale = 0.0

	# 显示对话（根据 dialog_pos 决定在上方还是下方）
	var pos: String = s.get("dialog_pos", "bottom")
	_set_dialog_position(pos)
	_show_dialog(s["dialog"])

	# 高亮处理
	_update_highlight(s.get("highlight", ""))

	# 输入模式
	var adv: String = s.get("advance", "tap")
	if adv == "tap":
		_waiting_for_event = false
		_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		_tap_hint.visible = true
	else:
		_waiting_for_event = true
		_tap_hint.visible = false
		# 需要交互的步骤：遮罩设为 IGNORE 让下层 UI 接收事件
		if adv in ["tower_placed", "game_started", "upgrade_chosen", "upgrade_chosen_single", "tower_tapped"]:
			_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_highlight_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Step 8：请求弹出全局升级面板
	if _step == 8:
		request_upgrade_panel.emit()


func _finish_tutorial() -> void:
	_active = false
	visible = false
	_char_sprite.visible = false
	_bubble_container.visible = false
	_hide_place_guide()
	_hide_arrow()
	# 恢复游戏速度
	if Engine.time_scale == 0.0:
		Engine.time_scale = _saved_time_scale if _saved_time_scale > 0.0 else 1.0
	tutorial_finished.emit()


# ═══════════════════════════════════════════════════════════════════════════
#  对话框显示
# ═══════════════════════════════════════════════════════════════════════════

## 切换对话框位置：top=左上角, bottom=左下角
func _set_dialog_position(pos: String) -> void:
	if pos == "top":
		_char_sprite.position = Vector2(10, 60)
		_bubble_container.position = Vector2(10, _char_sprite.position.y + 310)
	else:
		_char_sprite.position = Vector2(10, 1300)
		_bubble_container.position = Vector2(10, _char_sprite.position.y + 310)

func _show_dialog(text: String) -> void:
	_full_text = text
	_dialog_lbl.text = text
	_visible_chars = 0
	_dialog_lbl.visible_characters = 0
	_typing_active = true
	_type_timer = 0.0
	_char_sprite.visible = true
	_bubble_container.visible = true
	_dialog_box.visible = true


func _process(delta: float) -> void:
	if not _active:
		return

	# 打字机效果（不受 Engine.time_scale 影响，用真实时间）
	var real_delta: float = delta
	if Engine.time_scale > 0.0:
		real_delta = delta
	else:
		# time_scale=0 时 _process 仍运行（PROCESS_MODE_ALWAYS），delta 可能为 0
		# 用 OS 时间计算
		real_delta = 1.0 / 60.0   # 假设 60fps

	if _typing_active:
		_type_timer += real_delta
		var chars_to_show: int = int(_type_timer / TYPE_SPEED)
		if chars_to_show > _visible_chars:
			_visible_chars = chars_to_show
			_dialog_lbl.visible_characters = mini(_visible_chars, _full_text.length())
			if _visible_chars >= _full_text.length():
				_typing_active = false

	# 放置引导圈脉冲动画
	if is_instance_valid(_place_guide) and _place_guide.visible:
		_place_pulse_time += real_delta * 3.0
		_place_guide.queue_redraw()

	# 点击继续提示闪烁
	if _tap_hint.visible and not _typing_active:
		var blink: float = sin(Time.get_ticks_msec() / 500.0)
		_tap_hint.modulate.a = 0.5 + blink * 0.5


func _input(event: InputEvent) -> void:
	if not _active:
		return

	var is_tap: bool = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_tap = true
	elif event is InputEventScreenTouch and event.pressed:
		is_tap = true

	if not is_tap:
		return

	# 打字中 → 直接显示全文
	if _typing_active:
		_typing_active = false
		_visible_chars = _full_text.length()
		_dialog_lbl.visible_characters = _visible_chars
		get_viewport().set_input_as_handled()
		return

	# tap 推进模式
	if not _waiting_for_event:
		var adv: String = STEPS[_step].get("advance", "tap") if _step < STEPS.size() else "tap"
		if adv == "tap":
			# 恢复暂停
			if STEPS[_step].get("pause", false) and Engine.time_scale == 0.0:
				Engine.time_scale = _saved_time_scale if _saved_time_scale > 0.0 else 1.0
			_advance_step()
			get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════
#  高亮系统
# ═══════════════════════════════════════════════════════════════════════════

func _update_highlight(highlight_key: String) -> void:
	_highlight_ctrl.visible = false
	_hide_arrow()
	_hide_place_guide()

	if highlight_key == "" or highlight_key == null:
		_overlay.color = Color(0, 0, 0, 0.6)
		_overlay.visible = true
		return

	match highlight_key:
		"bottom_panel":
			var bp: Control = _get_hud_node("BottomPanel")
			if bp:
				var r := _control_screen_rect(bp)
				_show_highlight_rect(r)
				_show_arrow(Vector2(r.position.x + r.size.x * 0.5, r.position.y - 30))
			else:
				_show_highlight_rect(Rect2(0, 1430, 1080, 490))
				_show_arrow(Vector2(540, 1400))
		"gold_panel":
			var gp: Control = _get_hud_node("TopBar/GoldPanel")
			if gp:
				var r := _control_screen_rect(gp)
				_show_highlight_rect(r)
				_show_arrow(Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y + 10))
			else:
				_show_highlight_rect(Rect2(614, 0, 306, 80))
				_show_arrow(Vector2(767, 90))
		"speed_btn":
			var sb: Control = _get_hud_node("TopBar/SpeedBtn")
			if sb:
				var r := _control_screen_rect(sb)
				_show_highlight_rect(r)
				_show_arrow(Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y + 10))
			else:
				_show_highlight_rect(Rect2(960, 0, 120, 80))
				_show_arrow(Vector2(1020, 90))
		"place_zone":
			_overlay.color = Color(0, 0, 0, 0.3)   # 减淡遮罩允许操作
			_show_place_guide()
		"first_tower":
			if is_instance_valid(_first_tower):
				var canvas_xform := get_viewport().get_canvas_transform()
				var pos: Vector2 = canvas_xform * _first_tower.global_position
				_show_highlight_rect(Rect2(pos.x - 60, pos.y - 60, 120, 120))
				_show_arrow(Vector2(pos.x, pos.y - 70))
			else:
				_overlay.color = Color(0, 0, 0, 0.4)
		_:
			_overlay.color = Color(0, 0, 0, 0.6)


## 获取 HUD 下的节点（tutorial_scene.get_node("HUD/xxx")）
func _get_hud_node(path: String) -> Control:
	if not tutorial_scene:
		return null
	var node = tutorial_scene.get_node_or_null("HUD/" + path)
	return node as Control


## 获取 Control 节点在屏幕上的实际矩形（考虑 CanvasLayer 变换）
func _control_screen_rect(ctrl: Control) -> Rect2:
	var pos: Vector2 = ctrl.global_position
	var sz: Vector2 = ctrl.size
	return Rect2(pos, sz)


func _show_highlight_rect(rect: Rect2) -> void:
	_overlay.visible = true
	_overlay.color = Color(0, 0, 0, 0.0)   # 遮罩透明，让镂空控件处理
	_highlight_ctrl.visible = true
	_highlight_ctrl.set_meta("hole_rect", rect)
	_highlight_ctrl.queue_redraw()


func _show_arrow(pos: Vector2) -> void:
	_arrow_lbl.visible = true
	_arrow_lbl.position = pos - Vector2(20, 50)
	# 上下浮动动画
	if _arrow_tween:
		_arrow_tween.kill()
	_arrow_tween = create_tween().set_loops()
	_arrow_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_arrow_tween.tween_property(_arrow_lbl, "position:y", pos.y - 65, 0.5)
	_arrow_tween.tween_property(_arrow_lbl, "position:y", pos.y - 35, 0.5)

func _hide_arrow() -> void:
	_arrow_lbl.visible = false
	if _arrow_tween:
		_arrow_tween.kill()
		_arrow_tween = null


# ── 放置引导圈 ──────────────────────────────────────────────────────────

func _show_place_guide() -> void:
	if _place_guide == null:
		_place_guide = _PlaceGuideCircle.new()
		_place_guide.name = "PlaceGuide"
		_place_guide.z_index = 100
		# 加到 BattleScene 的地图层（不是 CanvasLayer）
		if tutorial_scene:
			tutorial_scene.add_child(_place_guide)
	_place_guide.position = PLACE_GUIDE_POS
	_place_guide.visible = true
	_place_pulse_time = 0.0
	# 箭头指向放置区域
	_show_arrow(Vector2(PLACE_GUIDE_POS.x, PLACE_GUIDE_POS.y - 100))

func _hide_place_guide() -> void:
	if is_instance_valid(_place_guide):
		_place_guide.visible = false


# ═══════════════════════════════════════════════════════════════════════════
#  UI 构建（纯代码，无 .tscn 依赖）
# ═══════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# ── 全屏遮罩 ──
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# ── 镂空高亮控件 ──
	_highlight_ctrl = Control.new()
	_highlight_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_highlight_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_ctrl.visible = false
	_highlight_ctrl.draw.connect(_on_highlight_draw)
	add_child(_highlight_ctrl)

	# ── 箭头 ──
	_arrow_lbl = Label.new()
	_arrow_lbl.text = "👇"
	_arrow_lbl.add_theme_font_size_override("font_size", 56)
	_arrow_lbl.visible = false
	_arrow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrow_lbl)

	# ── 阿福立绘（独立显示，不在对话框内）──
	_char_sprite = TextureRect.new()
	var tex: Texture2D = load("res://assets/sprites/tower/Scarecrow/Scarecrow_Idle.png")
	if tex:
		_char_sprite.texture = tex
	_char_sprite.custom_minimum_size = Vector2(280, 300)
	_char_sprite.size = Vector2(280, 300)
	_char_sprite.position = Vector2(10, 60)
	_char_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_char_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_char_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_char_sprite)

	# ── 气泡框（角色下方）──
	_bubble_container = Control.new()
	_bubble_container.position = Vector2(10, 370)
	_bubble_container.size = Vector2(600, 260)
	_bubble_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble_container)

	# 气泡背景（自定义绘制）
	var bubble_bg := Control.new()
	bubble_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubble_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_bg.draw.connect(_on_bubble_draw.bind(bubble_bg))
	_bubble_container.add_child(bubble_bg)

	# 气泡内容（文字区域）
	_dialog_box = PanelContainer.new()
	_dialog_box.offset_left   = 0
	_dialog_box.offset_top    = 20   # 尖角高度下方
	_dialog_box.offset_right  = 600
	_dialog_box.offset_bottom = 260
	_dialog_box.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)   # 透明（背景由 bubble_bg 绘制）
	_dialog_box.add_theme_stylebox_override("panel", style)
	_bubble_container.add_child(_dialog_box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_box.add_child(vbox)

	# ── 名字标签 ──
	_name_lbl = Label.new()
	_name_lbl.text = "阿福"
	_name_lbl.add_theme_font_size_override("font_size", 30)
	_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_name_lbl)

	# ── 对话文字 ──
	_dialog_lbl = Label.new()
	_dialog_lbl.text = ""
	_dialog_lbl.add_theme_font_size_override("font_size", 26)
	_dialog_lbl.add_theme_color_override("font_color", Color(0.15, 0.12, 0.08))
	_dialog_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_lbl.custom_minimum_size = Vector2(550, 0)
	_dialog_lbl.clip_text = false
	_dialog_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_dialog_lbl)

	# ── 点击继续提示（气泡右下角）──
	_tap_hint = Label.new()
	_tap_hint.text = "点击继续 ▶"
	_tap_hint.add_theme_font_size_override("font_size", 20)
	_tap_hint.add_theme_color_override("font_color", Color(0.45, 0.4, 0.3))
	_tap_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tap_hint.position = Vector2(380, 220)
	_tap_hint.size = Vector2(200, 30)
	_tap_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tap_hint.visible = false
	_bubble_container.add_child(_tap_hint)


# ── 气泡框绘制 ──────────────────────────────────────────────────────────

func _on_bubble_draw(ctrl: Control) -> void:
	var w: float = 600.0
	var h: float = 240.0
	var arrow_h: float = 20.0   # 尖角高度
	var arrow_w: float = 30.0
	var arrow_x: float = 60.0   # 尖角 x 位置（靠左，对准角色）
	var r: float = 18.0         # 圆角半径

	var bg_color := Color(1.0, 0.97, 0.88, 0.95)    # 米白色
	var border_color := Color(0.55, 0.42, 0.25, 1.0) # 棕色边框

	# 尖角朝上（指向角色）
	var arrow_pts := PackedVector2Array([
		Vector2(arrow_x, 0),
		Vector2(arrow_x + arrow_w * 0.5, arrow_h),
		Vector2(arrow_x - arrow_w * 0.5, arrow_h),
	])
	ctrl.draw_colored_polygon(arrow_pts, bg_color)
	ctrl.draw_polyline(arrow_pts, border_color, 2.5)

	# 圆角矩形主体
	var rect := Rect2(0, arrow_h, w, h)
	# 填充
	ctrl.draw_rect(Rect2(rect.position.x + r, rect.position.y, rect.size.x - r * 2, rect.size.y), bg_color)
	ctrl.draw_rect(Rect2(rect.position.x, rect.position.y + r, rect.size.x, rect.size.y - r * 2), bg_color)
	# 四个圆角
	ctrl.draw_circle(Vector2(rect.position.x + r, rect.position.y + r), r, bg_color)
	ctrl.draw_circle(Vector2(rect.end.x - r, rect.position.y + r), r, bg_color)
	ctrl.draw_circle(Vector2(rect.position.x + r, rect.end.y - r), r, bg_color)
	ctrl.draw_circle(Vector2(rect.end.x - r, rect.end.y - r), r, bg_color)

	# 边框
	ctrl.draw_arc(Vector2(rect.position.x + r, rect.position.y + r), r, PI, PI * 1.5, 16, border_color, 2.5)
	ctrl.draw_arc(Vector2(rect.end.x - r, rect.position.y + r), r, PI * 1.5, TAU, 16, border_color, 2.5)
	ctrl.draw_arc(Vector2(rect.end.x - r, rect.end.y - r), r, 0, PI * 0.5, 16, border_color, 2.5)
	ctrl.draw_arc(Vector2(rect.position.x + r, rect.end.y - r), r, PI * 0.5, PI, 16, border_color, 2.5)
	# 直线边框
	ctrl.draw_line(Vector2(rect.position.x + r, rect.position.y), Vector2(arrow_x - arrow_w * 0.5, rect.position.y), border_color, 2.5)
	ctrl.draw_line(Vector2(arrow_x + arrow_w * 0.5, rect.position.y), Vector2(rect.end.x - r, rect.position.y), border_color, 2.5)
	ctrl.draw_line(Vector2(rect.end.x, rect.position.y + r), Vector2(rect.end.x, rect.end.y - r), border_color, 2.5)
	ctrl.draw_line(Vector2(rect.end.x - r, rect.end.y), Vector2(rect.position.x + r, rect.end.y), border_color, 2.5)
	ctrl.draw_line(Vector2(rect.position.x, rect.end.y - r), Vector2(rect.position.x, rect.position.y + r), border_color, 2.5)


# ── 镂空绘制 ────────────────────────────────────────────────────────────

func _on_highlight_draw() -> void:
	if not _highlight_ctrl.visible:
		return
	var hole: Rect2 = _highlight_ctrl.get_meta("hole_rect", Rect2())
	if hole.size == Vector2.ZERO:
		return
	var screen := Rect2(0, 0, 1080, 1920)
	var overlay_color := Color(0, 0, 0, 0.6)
	var border_color := Color(1.0, 0.9, 0.3, 0.8)

	# 四个遮罩矩形围绕镂空区域
	# 上方
	_highlight_ctrl.draw_rect(Rect2(0, 0, 1080, hole.position.y), overlay_color)
	# 下方
	_highlight_ctrl.draw_rect(Rect2(0, hole.end.y, 1080, 1920 - hole.end.y), overlay_color)
	# 左侧
	_highlight_ctrl.draw_rect(Rect2(0, hole.position.y, hole.position.x, hole.size.y), overlay_color)
	# 右侧
	_highlight_ctrl.draw_rect(Rect2(hole.end.x, hole.position.y, 1080 - hole.end.x, hole.size.y), overlay_color)

	# 高亮边框
	_highlight_ctrl.draw_rect(hole, border_color, false, 3.0)


# ═══════════════════════════════════════════════════════════════════════════
#  放置引导圈（内部类）
# ═══════════════════════════════════════════════════════════════════════════

class _PlaceGuideCircle extends Node2D:
	func _draw() -> void:
		var t: float = Time.get_ticks_msec() / 300.0
		var alpha: float = 0.3 + sin(t) * 0.25
		var radius: float = 80.0
		draw_circle(Vector2.ZERO, radius, Color(0.2, 1.0, 0.3, alpha))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.4, 1.0, 0.5, alpha + 0.3), 4.0)

	func _process(_d: float) -> void:
		queue_redraw()
