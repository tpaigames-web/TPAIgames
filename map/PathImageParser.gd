class_name PathImageParser
extends RefCounted

## 从路径图片自动提取 Path2D 曲线 + 碰撞多边形
## 图片规格：1080×1920 PNG，透明背景+不透明路径
##
## 用法：
##   var result = PathImageParser.parse("res://assets/sprites/map/map_02/path_02.png")
##   # result = {"curve": Curve2D, "collision": PackedVector2Array, "goal_pos": Vector2}

const ALPHA_THRESHOLD: float = 0.4     ## 像素 alpha 阈值
const ROW_SAMPLE_STEP: int = 4         ## 每 N 行采样一次（加速）
const RDP_EPSILON: float = 8.0         ## 路径简化精度（像素）
const MIN_RUN_WIDTH: int = 10          ## 最小连续像素宽度（过滤噪点）


## 主入口：从路径图片路径解析，返回 {curve, collision, goal_pos}
static func parse(image_path: String) -> Dictionary:
	var tex: Texture2D = load(image_path)
	if tex == null:
		push_error("PathImageParser: 无法加载 " + image_path)
		return {}
	return parse_from_texture(tex)


## 从 Texture2D 解析
static func parse_from_texture(tex: Texture2D) -> Dictionary:
	var img: Image = tex.get_image()
	if img == null:
		push_error("PathImageParser: 无法获取 Image")
		return {}

	var w: int = img.get_width()
	var h: int = img.get_height()

	# ── 1. 构建 BitMap ──────────────────────────────────────────
	var bm := BitMap.new()
	bm.create(Vector2i(w, h))
	for y in h:
		for x in w:
			var c: Color = img.get_pixel(x, y)
			bm.set_bit(x, y, c.a > ALPHA_THRESHOLD)

	# ── 2. 提取碰撞多边形 ───────────────────────────────────────
	var polygons: Array = bm.opaque_to_polygons(Rect2i(0, 0, w, h))
	var collision: PackedVector2Array = PackedVector2Array()
	if polygons.size() > 0:
		# 取最大的多边形（按顶点数）
		var best_idx: int = 0
		var best_size: int = 0
		for i in polygons.size():
			if polygons[i].size() > best_size:
				best_size = polygons[i].size()
				best_idx = i
		collision = polygons[best_idx]

	# ── 3. 提取中心线（逐行扫描）─────────────────────────────────
	var center_points: Array[Vector2] = _extract_center_line(bm, w, h)

	# ── 4. 简化路径点 ───────────────────────────────────────────
	var simplified: Array[Vector2] = _rdp_simplify(center_points, RDP_EPSILON)

	# ── 5. 构建 Curve2D ─────────────────────────────────────────
	var curve := Curve2D.new()
	for pt in simplified:
		curve.add_point(pt)

	# ── 6. 终点位置（路径最后一个点）─────────────────────────────
	var goal_pos: Vector2 = simplified[simplified.size() - 1] if simplified.size() > 0 else Vector2(540, 1800)

	return {
		"curve": curve,
		"collision": collision,
		"goal_pos": goal_pos,
	}


## 逐行扫描提取路径中心线
static func _extract_center_line(bm: BitMap, w: int, h: int) -> Array[Vector2]:
	# Phase 1: 收集每行的"运行段"（连续不透明像素区间）
	var row_runs: Array = []  # [Array of {start, end, center}]
	for y in range(0, h, ROW_SAMPLE_STEP):
		var runs: Array = []
		var in_run: bool = false
		var run_start: int = 0
		for x in w:
			if bm.get_bit(x, y):
				if not in_run:
					in_run = true
					run_start = x
			else:
				if in_run:
					in_run = false
					var run_end: int = x - 1
					if run_end - run_start >= MIN_RUN_WIDTH:
						runs.append({
							"start": run_start,
							"end": run_end,
							"center": (run_start + run_end) / 2
						})
		if in_run:
			var run_end: int = w - 1
			if run_end - run_start >= MIN_RUN_WIDTH:
				runs.append({
					"start": run_start,
					"end": run_end,
					"center": (run_start + run_end) / 2
				})
		row_runs.append({"y": y, "runs": runs})

	# Phase 2: 从上到下跟踪路径（选择与上一行重叠的运行段）
	var points: Array[Vector2] = []
	var prev_center: int = -1
	var prev_start: int = -1
	var prev_end: int = -1

	for row_data in row_runs:
		var y: int = row_data["y"]
		var runs: Array = row_data["runs"]
		if runs.is_empty():
			continue

		if prev_center == -1:
			# 第一行有路径 → 取第一个运行段
			var r: Dictionary = runs[0]
			prev_center = r["center"]
			prev_start = r["start"]
			prev_end = r["end"]
			points.append(Vector2(prev_center, y))
			continue

		# 查找与上一行重叠的运行段
		var best_run: Dictionary = {}
		var best_overlap: int = 0
		for r in runs:
			var overlap_start: int = maxi(r["start"], prev_start)
			var overlap_end: int = mini(r["end"], prev_end)
			var overlap: int = maxi(0, overlap_end - overlap_start)
			if overlap > best_overlap:
				best_overlap = overlap
				best_run = r

		if best_run.is_empty():
			# 无重叠 → U型弯，找最近的运行段
			var min_dist: int = 99999
			for r in runs:
				var dist: int = absi(r["center"] - prev_center)
				if dist < min_dist:
					min_dist = dist
					best_run = r

		if not best_run.is_empty():
			var new_center: int = best_run["center"]
			# 如果中心点跳跃大（水平段/U型弯），插入中间点
			if absi(new_center - prev_center) > 30:
				points.append(Vector2(new_center, y - ROW_SAMPLE_STEP / 2))
			points.append(Vector2(new_center, y))
			prev_center = new_center
			prev_start = best_run["start"]
			prev_end = best_run["end"]

	return points


## Ramer-Douglas-Peucker 路径简化
static func _rdp_simplify(points: Array[Vector2], epsilon: float) -> Array[Vector2]:
	if points.size() <= 2:
		return points

	# 找到离首尾连线最远的点
	var max_dist: float = 0.0
	var max_idx: int = 0
	var start: Vector2 = points[0]
	var end: Vector2 = points[points.size() - 1]

	for i in range(1, points.size() - 1):
		var d: float = _point_line_distance(points[i], start, end)
		if d > max_dist:
			max_dist = d
			max_idx = i

	if max_dist > epsilon:
		var left: Array[Vector2] = []
		for i in range(0, max_idx + 1):
			left.append(points[i])
		var right: Array[Vector2] = []
		for i in range(max_idx, points.size()):
			right.append(points[i])
		var left_simplified: Array[Vector2] = _rdp_simplify(left, epsilon)
		var right_simplified: Array[Vector2] = _rdp_simplify(right, epsilon)
		# 合并（去掉右边第一个点避免重复）
		var result: Array[Vector2] = []
		for pt in left_simplified:
			result.append(pt)
		for i in range(1, right_simplified.size()):
			result.append(right_simplified[i])
		return result
	else:
		return [start, end]


## 点到直线距离
static func _point_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec: Vector2 = line_end - line_start
	var len_sq: float = line_vec.length_squared()
	if len_sq < 0.001:
		return point.distance_to(line_start)
	var t: float = clampf((point - line_start).dot(line_vec) / len_sq, 0.0, 1.0)
	var projection: Vector2 = line_start + line_vec * t
	return point.distance_to(projection)
