extends CanvasLayer

## 加载过渡画面 — 显示封面图 + "加载中..." 文字
## 使用 ResourceLoader 异步加载目标场景，加载完成后淡出过渡

const COVER_TEXTURE = preload("res://assets/sprites/ui/Cover/cover.png")

@export var fade_duration: float = 0.4
@export var min_display_time: float = 0.6  ## 最短显示时间，避免一闪而过

var _target_path: String = ""
var _elapsed: float = 0.0
var _load_done: bool = false

@onready var cover_image: TextureRect = $CoverImage
@onready var loading_label: Label = $LoadingLabel
@onready var anim_player: AnimationPlayer = $AnimPlayer


func _ready() -> void:
	cover_image.texture = COVER_TEXTURE
	# 淡入
	anim_player.play("fade_in")
	# 开始异步加载
	if _target_path != "":
		ResourceLoader.load_threaded_request(_target_path)


func setup(scene_path: String) -> void:
	_target_path = scene_path


func _process(delta: float) -> void:
	_elapsed += delta

	# 加载中动画（省略号循环）
	var dots: int = int(_elapsed * 2.0) % 4
	loading_label.text = "加载中" + ".".repeat(dots)

	# 检查加载状态
	if not _load_done and _target_path != "":
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_target_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_load_done = true

	# 加载完成且满足最短显示时间
	if _load_done and _elapsed >= min_display_time:
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
