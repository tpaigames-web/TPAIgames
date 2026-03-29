extends CanvasLayer

const LEVEL_UP_PANEL = preload("res://scenes/profile/LevelUpPanel.tscn")

const AVATAR_PATHS: Array[String] = [
	"res://assets/sprites/tower/scarecrow.png",
	"res://assets/sprites/enemy/rat_small.png",
	"res://assets/sprites/enemy/squirrel.png",
]
const AVATAR_EMOJIS: Array[String] = ["🌾", "🐭", "🐿"]

# ── 节点引用 ────────────────────────────────────────────
@onready var close_btn:    Button    = $Card/CloseBtn
@onready var avatar_btn:   Button    = $Card/HeaderRow/AvatarBtn
@onready var avatar_emoji: Label     = $Card/HeaderRow/AvatarBtn/AvatarEmoji
@onready var avatar_texture: TextureRect = $Card/HeaderRow/AvatarBtn/AvatarTexture
@onready var name_label:   Label     = $Card/HeaderRow/NameInfoVBox/NameRow/NameLabel
@onready var edit_name_btn: Button   = $Card/HeaderRow/NameInfoVBox/NameRow/EditNameBtn
@onready var level_label:  Label     = $Card/HeaderRow/NameInfoVBox/LevelRow/LevelLabel
@onready var level_row:    HBoxContainer = $Card/HeaderRow/NameInfoVBox/LevelRow
@onready var xp_bar_container: Control  = $Card/HeaderRow/NameInfoVBox/XpBarContainer
@onready var xp_fill:      ColorRect = $Card/HeaderRow/NameInfoVBox/XpBarContainer/XpFill
@onready var xp_label:     Label     = $Card/HeaderRow/NameInfoVBox/XpBarContainer/XpLabel
@onready var id_label:     Label     = $Card/HeaderRow/NameInfoVBox/IdLabel

@onready var games_played_label:    Label = $Card/BottomRow/StatsBox/GamesPlayedLabel
@onready var games_won_label:       Label = $Card/BottomRow/StatsBox/GamesWonLabel
@onready var enemies_label:         Label = $Card/BottomRow/StatsBox/EnemiesLabel
@onready var achiev_unlocked_label: Label = $Card/BottomRow/StatsBox/AchievUnlockedLabel

@onready var achiev_box:         Panel = $Card/AchievSection/AchievBox
@onready var achiev_placeholder: Label = $Card/AchievSection/AchievBox/AchievPlaceholder

@onready var avatar_picker:    Panel  = $Card/AvatarPicker
@onready var picker_close_btn: Button = $Card/AvatarPicker/PickerCloseBtn
@onready var avatar_opts: Array = [
	$Card/AvatarPicker/PickerRow/AvatarOpt0,
	$Card/AvatarPicker/PickerRow/AvatarOpt1,
	$Card/AvatarPicker/PickerRow/AvatarOpt2,
]
@onready var avatar_texs: Array = [
	$Card/AvatarPicker/PickerRow/AvatarOpt0/AvatarTex0,
	$Card/AvatarPicker/PickerRow/AvatarOpt1/AvatarTex1,
	$Card/AvatarPicker/PickerRow/AvatarOpt2/AvatarTex2,
]
@onready var picker_emojis: Array = [
	$Card/AvatarPicker/PickerRow/AvatarOpt0/AvatarEmoji0,
	$Card/AvatarPicker/PickerRow/AvatarOpt1/AvatarEmoji1,
	$Card/AvatarPicker/PickerRow/AvatarOpt2/AvatarEmoji2,
]

@onready var rename_box:   Panel    = $Card/RenameBox
@onready var name_input:   LineEdit = $Card/RenameBox/NameInput
@onready var confirm_btn:  Button   = $Card/RenameBox/RenameButtons/ConfirmBtn
@onready var cancel_btn:   Button   = $Card/RenameBox/RenameButtons/CancelBtn

# ── 初始化 ───────────────────────────────────────────────
func _ready() -> void:
	avatar_picker.hide()
	rename_box.hide()

	# 等一帧确保 Control 尺寸已计算完成（XP 条宽度需要 Container 尺寸）
	await get_tree().process_frame
	_populate_data()

	# 按钮连接
	close_btn.pressed.connect(_on_close)
	avatar_btn.pressed.connect(func(): avatar_picker.show())
	edit_name_btn.pressed.connect(_on_edit_name)
	level_row.gui_input.connect(_on_level_row_input)
	picker_close_btn.pressed.connect(func(): avatar_picker.hide())
	confirm_btn.pressed.connect(_on_rename_confirmed)
	cancel_btn.pressed.connect(func(): rename_box.hide())

	_setup_avatar_picker()

# ── 数据填充 ─────────────────────────────────────────────
func _populate_data() -> void:
	name_label.text  = UserManager.player_name
	level_label.text = "Lv. %d" % UserManager.level
	id_label.text    = "ID: " + UserManager.player_uuid.substr(0, 8).to_upper()
	_update_avatar_display()
	_update_xp_bar()
	games_played_label.text = "游戏场次：%d" % UserManager.games_played
	games_won_label.text    = "胜场：%d"     % UserManager.games_won
	enemies_label.text      = "击败敌人：%d" % UserManager.enemies_defeated
	_populate_achievements()

# ── 成就区域 ─────────────────────────────────────────────
func _populate_achievements() -> void:
	# 清除上次动态生成的成就列表（避免重复）
	var old := achiev_box.get_node_or_null("AchievList")
	if old:
		old.queue_free()

	# 根据现有战绩数据判断解锁的成就
	var unlocked: Array[String] = []
	if UserManager.games_played  >= 1:    unlocked.append("🎮 初次出征")
	if UserManager.games_won     >= 1:    unlocked.append("🏆 首次胜利")
	if UserManager.games_played  >= 10:   unlocked.append("⚔️ 久经沙场（游玩10场）")
	if UserManager.games_won     >= 10:   unlocked.append("🌟 常胜将军（赢得10场）")
	if UserManager.enemies_defeated >= 100:  unlocked.append("💀 百战老将（击败100个敌人）")
	if UserManager.enemies_defeated >= 1000: unlocked.append("🔥 千敌斩（击败1000个敌人）")

	# 同步成就解锁计数
	UserManager.achievements_unlocked = unlocked.size()
	achiev_unlocked_label.text = "成就解锁：%d" % unlocked.size()

	if unlocked.is_empty():
		achiev_placeholder.show()
		return

	achiev_placeholder.hide()

	var vbox := VBoxContainer.new()
	vbox.name = "AchievList"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	achiev_box.add_child(vbox)

	for text: String in unlocked:
		var lbl := Label.new()
		lbl.text = "✅ " + text
		lbl.add_theme_font_size_override("font_size", 26)
		lbl.modulate = Color(1.0, 0.85, 0.3)
		vbox.add_child(lbl)

func _update_xp_bar() -> void:
	var ratio := clampf(float(UserManager.xp) / float(UserManager.xp_to_next_level), 0.0, 1.0)
	xp_fill.size.x = xp_bar_container.size.x * ratio
	xp_label.text  = "%d / %d XP" % [UserManager.xp, UserManager.xp_to_next_level]

func _update_avatar_display() -> void:
	var idx := UserManager.selected_avatar
	# 始终显示对应 emoji（图片加载成功后会覆盖）
	avatar_emoji.text = AVATAR_EMOJIS[idx]
	var tex = load(AVATAR_PATHS[idx])
	avatar_texture.texture = tex  # null 时 TextureRect 透明，emoji 可见

# ── 头像选择器 ───────────────────────────────────────────
func _setup_avatar_picker() -> void:
	for i in avatar_texs.size():
		# 先设 emoji（永远可见作为底色）
		picker_emojis[i].text = AVATAR_EMOJIS[i]
		var tex = load(AVATAR_PATHS[i])
		if tex:
			avatar_texs[i].texture = tex
		avatar_opts[i].pressed.connect(_on_avatar_selected.bind(i))

func _on_avatar_selected(index: int) -> void:
	UserManager.set_avatar(index)
	_update_avatar_display()
	SaveManager.save()
	avatar_picker.hide()

# ── 改名 ─────────────────────────────────────────────────
func _on_edit_name() -> void:
	name_input.text = UserManager.player_name
	rename_box.show()

func _on_rename_confirmed() -> void:
	UserManager.set_player_name(name_input.text)
	name_label.text = UserManager.player_name
	SaveManager.save()
	rename_box.hide()

# ── 升级界面 ─────────────────────────────────────────────
func _on_level_row_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var panel = LEVEL_UP_PANEL.instantiate()
		get_tree().root.add_child(panel)

# ── 关闭 ─────────────────────────────────────────────────
func _on_close() -> void:
	var home = get_tree().get_first_node_in_group("home_scene")
	if home:
		home.refresh_player_info()
	queue_free()
