extends Node
class_name SpecialDeleteAnimator

# ==================== 特殊消除动画器 ====================
# 负责处理特殊宝石消除时的各种动画效果
# 包括：爆炸动画、闪电动画、震动效果等

# ==================== 核心依赖 ====================
@export var area: GameArea

# ==================== 动画时长配置 ====================
# 爆炸动画持续时间
@export var boom_duration_sec: float = 1.0
# 闪电动画持续时间
@export var lightning_duration_sec: float = 1.5

# ==================== 震动效果配置 ====================
# 震动动画持续时间
@export var shock_duration_sec: float = 0.25
# 震动延迟时间（让爆炸特效先播放）
@export var shock_delay_sec: float = 0.15

# 小爆炸震动参数
@export var small_shock_base_strength_px: float = 36.0
@export var small_shock_random_range: Vector2 = Vector2(0.85, 1.2)

# 大爆炸震动参数
@export var big_shock_base_strength_px: float = 54.0
@export var big_shock_random_range: Vector2 = Vector2(0.9, 1.35)

# ==================== 震动记录系统 ====================
# 记录被震动宝石的原始位置信息
# 结构：[{"gem": Gem实例, "original_position": Vector2}]
var _shaken_gems: Array[Dictionary] = []

# ==================== 爆炸动画跟踪系统 ====================
# 记录当前播放的爆炸动画实例
var _active_explosion_animations: Array[Boom] = []

# ==================== 清理系统 ====================
# 超时清理计时器
var _cleanup_timer: Timer

# ==================== 资源预加载 ====================
const BOOM_SCENE: PackedScene = preload("res://UI/boom/boom.tscn")
const LIGHTNING_SCENE: PackedScene = preload("res://UI/lightning_line/lightning_line.tscn")

# ==================== 初始化 ====================
func _ready() -> void:
	_setup_cleanup_timer()

## 设置清理计时器
func _setup_cleanup_timer() -> void:
	_cleanup_timer = Timer.new()
	_cleanup_timer.wait_time = 5.0  # 每5秒清理一次
	_cleanup_timer.autostart = true
	add_child(_cleanup_timer)

# ==================== 核心动画创建函数 ====================

## 创建小范围爆炸动画
## @param info: 包含center_tile和other_tiles的字典
func create_small_explosion(info: Dictionary) -> void:
	if not _validate_dependencies() or not _validate_delete_info(info):
		push_warning("SpecialDeleteAnimator: 小爆信息格式不正确")
		return

	# 计算爆炸参数
	var boom_size_px: float = Gem.GEM_SIZE.x * 2.0
	var center_tile: Vector2i = info["center_tile"]
	var other_tiles: Array[Vector2i] = info["other_tiles"]
	var center_global: Vector2 = _compute_small_explosion_center(center_tile, other_tiles)
	
	# 播放爆炸效果
	_spawn_boom_at_center(center_global, boom_size_px, boom_duration_sec)
	
	# 延迟触发震动效果
	_schedule_shock_animation(info, center_global, true)

## 创建大范围爆炸动画  
## @param info: 包含center_tile和other_tiles的字典
func create_explosion(info: Dictionary) -> void:
	if not _validate_dependencies() or not info.has("center_tile"):
		push_warning("SpecialDeleteAnimator: 爆炸信息缺少 center_tile")
		return

	# 计算爆炸参数
	var boom_size_px: float = Gem.GEM_SIZE.x * 3.0
	var center_tile: Vector2i = info["center_tile"]
	var center_global: Vector2 = _get_tile_center_global(center_tile)
	
	# 播放爆炸效果
	_spawn_boom_at_center(center_global, boom_size_px, boom_duration_sec)
	
	# 延迟触发震动效果
	_schedule_shock_animation(info, center_global, false)

## 创建水平闪电动画
## @param info: 包含center_tile的字典
func create_lightning_horizontal(info: Dictionary) -> void:
	if not _validate_dependencies() or not info.has("center_tile"):
		push_warning("SpecialDeleteAnimator: 横向闪电信息缺少 center_tile")
		return

	var center_tile: Vector2i = info["center_tile"]
	var lightning_data: Dictionary = _compute_horizontal_lightning_geometry(center_tile)
	var start_pos: Vector2 = lightning_data["start_global"]
	var length_px: float = lightning_data["length_px"]
	
	_spawn_lightning_line(start_pos, length_px, false, lightning_duration_sec)

## 创建垂直闪电动画
## @param info: 包含center_tile的字典
func create_lightning_vertical(info: Dictionary) -> void:
	if not _validate_dependencies() or not info.has("center_tile"):
		push_warning("SpecialDeleteAnimator: 纵向闪电信息缺少 center_tile")
		return

	var center_tile: Vector2i = info["center_tile"]
	var lightning_data: Dictionary = _compute_vertical_lightning_geometry(center_tile)
	var start_pos: Vector2 = lightning_data["start_global"]
	var length_px: float = lightning_data["length_px"]
	
	_spawn_lightning_line(start_pos, length_px, true, lightning_duration_sec)

## 创建十字闪电动画（水平+垂直）
## @param info: 包含center_tile的字典
func create_lightning_cross(info: Dictionary) -> void:
	create_lightning_horizontal(info)
	create_lightning_vertical(info)

# ==================== 私有动画实现函数 ====================

## 在指定位置生成爆炸效果
## @param center_global: 爆炸中心的世界坐标
## @param size_px: 爆炸大小（像素）
## @param duration_sec: 持续时间
func _spawn_boom_at_center(center_global: Vector2, size_px: float, duration_sec: float) -> void:
	# 参数验证
	if size_px <= 0.0 or duration_sec <= 0.0:
		push_warning("SpecialDeleteAnimator: 爆炸参数无效 - size_px: %f, duration_sec: %f" % [size_px, duration_sec])
		return
	
	if not BOOM_SCENE:
		push_error("SpecialDeleteAnimator: BOOM_SCENE 资源未加载")
		return
	
	# 创建爆炸实例
	var boom: Boom = BOOM_SCENE.instantiate() as Boom
	if not boom:
		push_error("SpecialDeleteAnimator: 无法实例化 Boom")
		return
	
	# 添加到活跃动画列表
	_active_explosion_animations.append(boom)
	print("SpecialDeleteAnimator: created explosion: ", boom, " total active: ", _active_explosion_animations.size())
	
	# 设置位置和播放动画
	add_child(boom)
	boom.global_position = center_global - Vector2(size_px, size_px) * 0.5
	boom.play(size_px, duration_sec)
	
	# 监听爆炸完成事件
	boom.tree_exited.connect(_on_explosion_animation_finished.bind(boom), Object.CONNECT_ONE_SHOT)
	print("SpecialDeleteAnimator: connected tree_exited signal for: ", boom)

## 生成闪电线条效果
## @param start_global: 起始位置
## @param length_px: 闪电长度
## @param vertical: 是否为垂直方向
## @param duration_sec: 持续时间
func _spawn_lightning_line(start_global: Vector2, length_px: float, vertical: bool, duration_sec: float) -> void:
	# 参数验证
	if length_px <= 0.0 or duration_sec <= 0.0:
		push_warning("SpecialDeleteAnimator: 闪电参数无效 - length_px: %f, duration_sec: %f" % [length_px, duration_sec])
		return
	
	if not LIGHTNING_SCENE:
		push_error("SpecialDeleteAnimator: LIGHTNING_SCENE 资源未加载")
		return
	
	# 创建闪电实例
	var line: LightningLine = LIGHTNING_SCENE.instantiate() as LightningLine
	if not line:
		push_error("SpecialDeleteAnimator: 无法实例化 LightningLine")
		return
	
	# 设置位置和播放动画
	add_child(line)
	line.global_position = start_global
	line.play(length_px, duration_sec, vertical)

# ==================== 震动效果系统 ====================

## 调度震动动画（延迟执行）
## @param info: 爆炸信息
## @param center_global: 爆炸中心世界坐标
## @param is_small: 是否为小爆炸
func _schedule_shock_animation(info: Dictionary, center_global: Vector2, is_small: bool) -> void:
	var shock_targets: Dictionary = _compute_shock_targets(info)
	if not shock_targets.has("gems") or not shock_targets.has("center_global"):
		push_warning("SpecialDeleteAnimator: 震荡目标计算失败")
		return
	
	var shock_gems: Array[Gem] = []
	shock_gems.append_array(shock_targets["gems"])
	if shock_gems.is_empty():
		return
	
	# 延迟触发震动动画
	if shock_delay_sec <= 0.0:
		_apply_shock_animation(shock_targets["center_global"], shock_gems, is_small)
	else:
		var timer := get_tree().create_timer(shock_delay_sec)
		timer.timeout.connect(func(): 
			_apply_shock_animation(shock_targets["center_global"], shock_gems, is_small)
		, Object.CONNECT_ONE_SHOT)

## 应用震动动画
## @param center_global: 震动中心
## @param gems: 受影响的宝石数组
## @param is_small: 是否为小震动
func _apply_shock_animation(center_global: Vector2, gems: Array[Gem], is_small: bool) -> void:
	if gems.is_empty():
		return
	
	# 选择震动参数
	var base_strength: float = small_shock_base_strength_px if is_small else big_shock_base_strength_px
	var rand_range: Vector2 = small_shock_random_range if is_small else big_shock_random_range
	
	# 对每个宝石应用震动
	for gem in gems:
		if not gem or not is_instance_valid(gem):
			continue
		
		_apply_shock_to_gem(gem, center_global, base_strength, rand_range)

## 对单个宝石应用震动效果
## @param gem: 宝石实例
## @param center_global: 震动中心
## @param base_strength: 基础震动强度
## @param rand_range: 随机范围
func _apply_shock_to_gem(gem: Gem, center_global: Vector2, base_strength: float, rand_range: Vector2) -> void:
	# 记录原始位置
	var original_position: Vector2 = gem.global_position
	_record_shaken_gem(gem, original_position)
	
	# 计算震动方向和强度
	var gem_center: Vector2 = gem.global_position + Gem.HALF_GEM_SIZE
	var delta: Vector2 = gem_center - center_global
	var distance: float = delta.length()
	
	# 确定推离方向
	var direction: Vector2
	if distance <= 0.001:
		direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		distance = 0.001
	else:
		direction = delta / distance
	
	# 计算震动强度（距离越近，强度越大）
	var strength_scale: float = base_strength / (distance / Gem.GEM_SIZE.x + 0.5)
	var randomness: float = randf_range(rand_range.x, rand_range.y)
	var displacement: Vector2 = direction * strength_scale * randomness
	
	# 计算目标位置
	var target_center: Vector2 = gem_center + displacement
	var target_position: Vector2 = target_center - Gem.HALF_GEM_SIZE
	
	# 执行移动动画
	gem.move_to_global_position(target_position, shock_duration_sec, false, false)

## 记录被震动宝石的信息
## @param gem: 宝石实例
## @param original_position: 原始位置
func _record_shaken_gem(gem: Gem, original_position: Vector2) -> void:
	# 检查是否已经记录过
	for record in _shaken_gems:
		if record.has("gem") and is_instance_valid(record["gem"]) and record["gem"] == gem:
			return
	
	# 添加新记录
	_shaken_gems.append({
		"gem": gem,
		"original_position": original_position
	})

# ==================== 几何计算函数 ====================

## 获取瓦片中心的世界坐标
## @param tile: 瓦片坐标
## @return: 世界坐标
func _get_tile_center_global(tile: Vector2i) -> Vector2:
	return area.get_global_from_tile(tile)

## 计算小爆炸的几何中心（2x2区域）
## @param center_tile: 中心瓦片
## @param other_tiles: 其他瓦片
## @return: 几何中心的世界坐标
func _compute_small_explosion_center(center_tile: Vector2i, other_tiles: Array[Vector2i]) -> Vector2:
	var all_tiles: Array[Vector2i] = [center_tile]
	all_tiles.append_array(other_tiles)
	
	# 计算平均位置
	var sum_x: float = 0
	var sum_y: float = 0
	for tile in all_tiles:
		sum_x += tile.x
		sum_y += tile.y
	
	var avg_x: float = sum_x / all_tiles.size()
	var avg_y: float = sum_y / all_tiles.size()
	var base_pos: Vector2 = area.get_global_from_tile(center_tile)
	
	return Vector2(avg_x, avg_y) + base_pos

## 计算水平闪电的几何参数
## @param center_tile: 中心瓦片
## @return: 包含start_global和length_px的字典
func _compute_horizontal_lightning_geometry(center_tile: Vector2i) -> Dictionary:
	var y: int = center_tile.y
	var start_tile: Vector2i = Vector2i(0, y)
	var start_pos: Vector2 = _get_tile_center_global(start_tile) - Vector2(Gem.HALF_GEM_SIZE.x, 0) - Vector2(8, 0)
	var grid_width: int = area.game_grid.size.x
	var length_px: float = float(grid_width) * Gem.GEM_SIZE.x
	
	return {"start_global": start_pos, "length_px": length_px}

## 计算垂直闪电的几何参数
## @param center_tile: 中心瓦片
## @return: 包含start_global和length_px的字典
func _compute_vertical_lightning_geometry(center_tile: Vector2i) -> Dictionary:
	var x: int = center_tile.x
	var start_tile: Vector2i = Vector2i(x, 0)
	var start_pos: Vector2 = _get_tile_center_global(start_tile) - Vector2(0, Gem.HALF_GEM_SIZE.y) - Vector2(0, 8)
	var grid_height: int = area.game_grid.size.y
	var length_px: float = float(grid_height) * Gem.GEM_SIZE.y
	
	return {"start_global": start_pos, "length_px": length_px}

## 计算震动目标（受影响的宝石）
## @param info: 爆炸信息
## @return: 包含center_global和gems的字典
func _compute_shock_targets(info: Dictionary) -> Dictionary:
	var result: Dictionary = {"center_global": Vector2.ZERO, "gems": []}
	
	if not info.has("center_tile") or not info.has("other_tiles") or not info.has("special_type"):
		return result
	
	var center_tile: Vector2i = info["center_tile"]
	var other_tiles: Array[Vector2i] = info["other_tiles"]
	var special_type: GemStat.SpecialType = info["special_type"]
	
	# 收集所有爆炸区域的瓦片
	var explosion_tiles: Array[Vector2i] = [center_tile]
	explosion_tiles.append_array(other_tiles)
	
	# 计算中心位置
	var center_global: Vector2
	match special_type:
		GemStat.SpecialType.SMALL_EXPLOSION:
			center_global = _compute_small_explosion_center(center_tile, other_tiles)
		GemStat.SpecialType.EXPLOSION:
			center_global = _get_tile_center_global(center_tile)
		_:
			center_global = _get_tile_center_global(center_tile)
	
	result["center_global"] = center_global
	
	# 计算包围矩形
	var bounds = _calculate_bounding_rect(explosion_tiles)
	
	# 收集外环的宝石
	var affected_gems: Array[Gem] = _collect_surrounding_gems(bounds)
	result["gems"] = affected_gems
	
	return result

## 计算瓦片数组的包围矩形
## @param tiles: 瓦片数组
## @return: 包含min_x, max_x, min_y, max_y的字典
func _calculate_bounding_rect(tiles: Array[Vector2i]) -> Dictionary:
	if tiles.is_empty():
		return {"min_x": 0, "max_x": 0, "min_y": 0, "max_y": 0}
	
	var min_x: int = tiles[0].x
	var max_x: int = tiles[0].x
	var min_y: int = tiles[0].y
	var max_y: int = tiles[0].y
	
	for tile in tiles:
		min_x = min(min_x, tile.x)
		max_x = max(max_x, tile.x)
		min_y = min(min_y, tile.y)
		max_y = max(max_y, tile.y)
	
	return {"min_x": min_x, "max_x": max_x, "min_y": min_y, "max_y": max_y}

## 收集包围矩形外环的宝石
## @param bounds: 包围矩形
## @return: 受影响的宝石数组
func _collect_surrounding_gems(bounds: Dictionary) -> Array[Gem]:
	var affected_gems: Array[Gem] = []
	
	if not area or not area.game_grid:
		return affected_gems
	
	var min_x: int = bounds["min_x"]
	var max_x: int = bounds["max_x"]
	var min_y: int = bounds["min_y"]
	var max_y: int = bounds["max_y"]
	
	# 计算搜索范围（外环）
	var grid_size: Vector2i = area.game_grid.size
	var search_min_x: int = max(0, min_x - 1)
	var search_max_x: int = min(grid_size.x - 1, max_x + 1)
	var search_min_y: int = max(0, min_y - 1)
	var search_max_y: int = min(grid_size.y - 1, max_y + 1)
	
	# 遍历外环区域
	for x in range(search_min_x, search_max_x + 1):
		for y in range(search_min_y, search_max_y + 1):
			# 跳过内部区域
			var is_inside: bool = (x >= min_x and x <= max_x and y >= min_y and y <= max_y)
			if is_inside:
				continue
			
			# 收集有效的宝石
			var tile := Vector2i(x, y)
			var gem: Gem = area.game_grid.get_gem(tile)
			if gem and is_instance_valid(gem):
				affected_gems.append(gem)
	
	return affected_gems

# ==================== 震动记录管理 ====================

## 恢复所有被震动宝石到原始位置
func restore_shaken_gems_to_original_positions() -> void:
	if _shaken_gems.is_empty():
		return
	
	const RESTORE_DURATION: float = 0.3  # 恢复动画持续时间
	
	for gem_data in _shaken_gems:
		# 安全地获取gem对象，避免访问已释放的实例
		if not gem_data.has("gem") or not gem_data.has("original_position"):
			continue
			
		var gem_ref = gem_data["gem"]
		if not is_instance_valid(gem_ref):
			continue
			
		var gem: Gem = gem_ref as Gem
		var original_position: Vector2 = gem_data["original_position"]
		
		if gem:
			gem.move_to_global_position(original_position, RESTORE_DURATION, false, false)
	
	# 清理记录
	clear_shaken_gems_record()

## 清理震动宝石记录
func clear_shaken_gems_record() -> void:
	_shaken_gems.clear()

## 获取当前被震动宝石的数量
## @return: 被震动宝石的数量
func get_shaken_gems_count() -> int:
	return _shaken_gems.size()

# ==================== 验证函数 ====================

## 验证依赖项是否正确设置
## @return: 验证结果
func _validate_dependencies() -> bool:
	if not area or not area.game_grid:
		push_error("SpecialDeleteAnimator: area 或 game_grid 未设置")
		return false
	return true

## 验证删除信息的格式
## @param info: 删除信息字典
## @return: 验证结果
func _validate_delete_info(info: Dictionary) -> bool:
	if not info:
		return false
	
	if not info.has("center_tile") or not info.has("other_tiles"):
		return false
	
	# 验证center_tile是否为有效的Vector2i
	var center_tile = info.get("center_tile")
	if not center_tile is Vector2i:
		return false
	
	# 验证other_tiles是否为有效的Array
	var other_tiles = info.get("other_tiles")
	if not other_tiles is Array:
		return false
	
	return true

# ==================== 调试和工具函数 ====================

## 打印当前震动记录的调试信息
func debug_print_shaken_gems() -> void:
	print("当前震动宝石记录数量: ", _shaken_gems.size())
	for i in range(_shaken_gems.size()):
		var record = _shaken_gems[i]
		if not record.has("gem") or not record.has("original_position"):
			print("  [", i, "] 无效记录")
			continue
			
		var gem_ref = record["gem"]
		var original_pos: Vector2 = record["original_position"]
		
		if is_instance_valid(gem_ref):
			print("  [", i, "] 宝石: ", gem_ref, " 原始位置: ", original_pos)
		else:
			print("  [", i, "] 宝石: [已释放] 原始位置: ", original_pos)

## 验证所有记录的宝石是否仍然有效
func validate_shaken_gems_records() -> void:
	var invalid_count = 0
	for record in _shaken_gems:
		if not record.has("gem"):
			invalid_count += 1
			continue
			
		var gem_ref = record["gem"]
		if not is_instance_valid(gem_ref):
			invalid_count += 1
	
	if invalid_count > 0:
		print("警告: 发现 ", invalid_count, " 个无效的震动宝石记录")

# ==================== 清理函数 ====================

## 清理所有动画和记录
func cleanup_all() -> void:
	# 停止所有正在进行的动画
	var tweens = get_tree().get_nodes_in_group("special_delete_tweens")
	for tween in tweens:
		if is_instance_valid(tween):
			tween.kill()
	
	# 清理震动记录
	clear_shaken_gems_record()
	
	print("特殊消除动画器已清理完毕")

# ==================== 兼容性函数 ====================
# 以下函数保持原有接口，确保向后兼容

## 小爆炸震动动画（兼容接口）
func animate_explosion_shockwave_small(center_global: Vector2, gems: Array[Gem]) -> void:
	_apply_shock_animation(center_global, gems, true)

## 大爆炸震动动画（兼容接口）
func animate_explosion_shockwave_big(center_global: Vector2, gems: Array[Gem]) -> void:
	_apply_shock_animation(center_global, gems, false)

## 计算小爆炸中心（兼容接口）
func compute_small_explosion_center(center_tile: Vector2i, other_tiles: Array[Vector2i]) -> Vector2:
	return _compute_small_explosion_center(center_tile, other_tiles)

## 计算爆炸中心（兼容接口）
func compute_explosion_center(center_tile: Vector2i) -> Vector2:
	return _get_tile_center_global(center_tile)

## 计算水平闪电几何（兼容接口）
func compute_horizontal_lightning_geometry(center_tile: Vector2i) -> Dictionary:
	return _compute_horizontal_lightning_geometry(center_tile)

## 计算垂直闪电几何（兼容接口）
func compute_vertical_lightning_geometry(center_tile: Vector2i) -> Dictionary:
	return _compute_vertical_lightning_geometry(center_tile)

## 计算震动目标（兼容接口）
func compute_shockwave_targets(info: Dictionary) -> Dictionary:
	return _compute_shock_targets(info)

# ==================== 爆炸动画管理 ====================

## 爆炸动画完成时的回调函数
## @param boom: 完成的爆炸动画实例
func _on_explosion_animation_finished(boom: Boom) -> void:
	print("SpecialDeleteAnimator: explosion animation finished: ", boom)
	# 从活跃动画列表中移除
	var index = _active_explosion_animations.find(boom)
	if index >= 0:
		_active_explosion_animations.remove_at(index)
		print("SpecialDeleteAnimator: removed explosion from list, remaining: ", _active_explosion_animations.size())
	else:
		print("SpecialDeleteAnimator: WARNING - explosion not found in active list!")
	
	# 检查是否所有爆炸动画都已完成
	_check_all_explosions_finished()

## 检查是否有爆炸动画正在播放
## @return: 如果有爆炸动画正在播放则返回true
func has_active_explosion_animations() -> bool:
	# 清理无效的动画引用
	_cleanup_invalid_explosion_animations()
	return not _active_explosion_animations.is_empty()

## 获取当前活跃的爆炸动画数量
## @return: 活跃爆炸动画的数量
func get_active_explosion_count() -> int:
	_cleanup_invalid_explosion_animations()
	return _active_explosion_animations.size()

## 清理无效的爆炸动画引用
func _cleanup_invalid_explosion_animations() -> void:
	var valid_animations: Array[Boom] = []
	for boom in _active_explosion_animations:
		if is_instance_valid(boom) and boom.get_parent() != null:
			valid_animations.append(boom)
	_active_explosion_animations = valid_animations

## 等待所有爆炸动画完成
## @return: 返回一个信号，当所有爆炸动画完成时触发
signal all_explosion_animations_finished

## 检查并触发所有爆炸动画完成信号
func _check_all_explosions_finished() -> void:
	if not has_active_explosion_animations():
		all_explosion_animations_finished.emit()

# ==================== 震动记录管理 ====================
