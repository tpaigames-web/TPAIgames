class_name ObjectPool extends Node

## 通用对象池
## 用法：
##   var pool = ObjectPool.new()
##   pool.pool_scene = preload("res://bullet/Bullet.tscn")
##   pool.initial_size = 20
##   add_child(pool)          # _ready 中自动预热
##   var obj = pool.acquire() # 获取对象（需手动 add_child 到目标父节点）
##   pool.release(obj)        # 回收（自动 reparent 到池内部）

## 池化场景
@export var pool_scene: PackedScene
## 初始预热数量
@export var initial_size: int = 20
## 最大池容量（超过则直接销毁）
@export var max_size: int = 100

var _available: Array[Node] = []
var _total_created: int = 0


func _ready() -> void:
	for i in initial_size:
		var obj: Node = _create_instance()
		if obj:
			_store(obj)


## 从池中获取一个对象（调用者需 add_child 到目标父节点）
func acquire() -> Node:
	var obj: Node
	if _available.size() > 0:
		obj = _available.pop_back()
	else:
		obj = _create_instance()
	if obj == null:
		return null
	# 从池容器移除（调用者会 add_child 到目标位置）
	if obj.get_parent() == self:
		remove_child(obj)
	obj.set_process(true)
	obj.set_physics_process(true)
	obj.visible = true
	return obj


## 回收对象到池中
func release(obj: Node) -> void:
	if obj == null:
		return
	if _available.size() >= max_size:
		obj.queue_free()
		return
	# 停止处理
	obj.set_process(false)
	obj.set_physics_process(false)
	obj.visible = false
	# 调用 reset（如果对象实现了）
	if obj.has_method("reset"):
		obj.reset()
	# 从当前父节点移除，存入池
	if obj.get_parent() and obj.get_parent() != self:
		obj.get_parent().remove_child(obj)
	if obj.get_parent() != self:
		add_child(obj)
	_available.append(obj)


## 获取池状态信息
func get_stats() -> Dictionary:
	return {
		"available": _available.size(),
		"total_created": _total_created,
		"max_size": max_size,
	}


func _create_instance() -> Node:
	if pool_scene == null:
		push_error("ObjectPool: pool_scene 为空")
		return null
	var obj: Node = pool_scene.instantiate()
	_total_created += 1
	return obj


func _store(obj: Node) -> void:
	obj.set_process(false)
	obj.set_physics_process(false)
	obj.visible = false
	add_child(obj)
	_available.append(obj)
