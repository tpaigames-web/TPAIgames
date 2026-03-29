extends Node

const LOADING_SCREEN_SCENE = preload("res://scenes/loading/LoadingScreen.tscn")

var container: Node = null

# 由 GameRoot 在 _ready() 时调用，传入 CurrentScene 容器节点
func set_container(node: Node) -> void:
	container = node
	go_logo()

func clear_scene() -> void:
	for child in container.get_children():
		child.queue_free()

func go_logo() -> void:
	clear_scene()
	container.add_child(load("res://logo/LogoScene.tscn").instantiate())

func go_story() -> void:
	clear_scene()
	container.add_child(load("res://scenes/StoryScene.tscn").instantiate())

func go_login() -> void:
	clear_scene()
	container.add_child(load("res://scenes/LoginScene.tscn").instantiate())

func go_home() -> void:
	clear_scene()
	container.add_child(load("res://scenes/HomeScene.tscn").instantiate())


## 带加载画面的场景切换（封面图 + 淡入淡出 + 异步加载）
func go_with_loading(scene_path: String) -> void:
	var loading_screen = LOADING_SCREEN_SCENE.instantiate()
	loading_screen.setup(scene_path)
	get_tree().root.add_child(loading_screen)
