class_name MapData extends Resource
## 地图数据容器 — 存储地图编辑器的所有放置信息
##
## 保存格式: user://maps/{map_name}.json
## 每个 objects 元素: {"type": "path_h", "x": 540.0, "y": 200.0, "rot": 0.0}

@export var map_name: String = "新地图"

## 已放置对象列表
@export var objects: Array[Dictionary] = []

## 敌人行进路线航点（世界坐标，顺序即行进顺序）
@export var waypoints: Array[Vector2] = []

## 目标区域位置（GoalArea）
@export var goal_pos: Vector2 = Vector2(540, 1700)

## 地面背景类型（"grass" | "highland" | "farmland" | "dirt"）
@export var background_type: String = "grass"

const SAVE_DIR := "user://maps/"

## 保存到 user://maps/{map_name}.json
func save_to_file() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var wp_array: Array = []
	for v: Vector2 in waypoints:
		wp_array.append([v.x, v.y])
	var data := {
		"map_name":        map_name,
		"objects":         objects,
		"waypoints":       wp_array,
		"goal_pos":        [goal_pos.x, goal_pos.y],
		"background_type": background_type,
	}
	var path := SAVE_DIR + map_name + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("MapData: 无法写入文件 " + path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

## 从文件加载（静态工厂方法）
static func load_from_file(path: String) -> MapData:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("MapData: 无法读取文件 " + path)
		return null
	var text    := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("MapData: JSON 解析失败 " + path)
		return null
	var d := parsed as Dictionary
	var md      := MapData.new()
	md.map_name  = d.get("map_name", "未知地图")
	# Array[Dictionary] 需要显式 for 循环，JSON 解析结果是无类型 Array
	var raw_obj: Array = d.get("objects", [])
	var obj_list: Array[Dictionary] = []
	for item in raw_obj:
		if item is Dictionary:
			obj_list.append(item as Dictionary)
	md.objects = obj_list
	var raw_wp: Array = d.get("waypoints", [])
	for pair in raw_wp:
		if pair is Array and pair.size() >= 2:
			md.waypoints.append(Vector2(pair[0], pair[1]))
	var gp: Array = d.get("goal_pos", [540, 1700])
	md.goal_pos = Vector2(gp[0], gp[1])
	md.background_type = d.get("background_type", "grass")
	return md

## 列出 user://maps/ 目录下所有已保存的地图路径
static func list_saved_maps() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(SAVE_DIR)
	if not dir:
		return result
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			result.append(SAVE_DIR + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	return result
