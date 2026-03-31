extends CanvasLayer

## 加载过渡画面 — 封面图 + 进度条 + 加载详情
## 使用 ResourceLoader 异步加载目标场景，加载完成后淡出过渡

const COVER_TEXTURE = preload("res://assets/sprites/ui/Cover/cover.png")

@export var fade_duration: float = 0.4

var _target_path: String = ""
var _elapsed: float = 0.0
var _load_done: bool = false

@onready var cover_image: TextureRect = $CoverImage
@onready var loading_label: Label = $LoadingLabel
@onready var anim_player: AnimationPlayer = $AnimPlayer

var _progress_bar: ProgressBar = null


func _ready() -> void:
	cover_image.texture = COVER_TEXTURE
	_create_progress_bar()
	# 淡入
	anim_player.play("fade_in")
	# 开始异步加载
	if _target_path != "":
		ResourceLoader.load_threaded_request(_target_path)


func setup(scene_path: String) -> void:
	_target_path = scene_path


func _create_progress_bar() -> void:
	_progress_bar = ProgressBar.new()
	_progress_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_progress_bar.offset_top = -50.0
	_progress_bar.offset_bottom = -20.0
	_progress_bar.offset_left = 60.0
	_progress_bar.offset_right = -60.0
	_progress_bar.min_value = 0
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	_progress_bar.show_percentage = false
	add_child(_progress_bar)


func _process(delta: float) -> void:
	_elapsed += delta

	# 加载中动画（省略号循环）
	var dots: int = int(_elapsed * 2.0) % 4
	loading_label.text = tr("UI_LOADING").trim_suffix("...") + ".".repeat(dots)

	# 检查加载状态 + 更新进度
	if not _load_done and _target_path != "":
		var progress: Array = []
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_target_path, progress)
		if _progress_bar and progress.size() > 0:
			_progress_bar.value = progress[0] * 100.0
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_load_done = true
			if _progress_bar:
				_progress_bar.value = 100.0

	# 加载完成即刻过渡（不再强制等待）
	if _load_done:
		_transition_to_scene()
		set_process(false)


func _transition_to_scene() -> void:
	# 淡出
	anim_player.play("fade_out")
	await anim_player.animation_finished

	# 切换场景
	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(_target_path)
	get_tree().change_scene_to_packed(packed_scene)

	# 自我销毁
	queue_free()
