extends Node
class_name SpecialDelete

# ==================== 特殊消除处理器 ====================
# 负责根据特殊宝石类型执行对应的"特殊删除"策略，并生成删除信息
# 
# 主要功能：
# - 从匹配结果中筛选特殊宝石并生成删除信息
# - 根据已捕获的特殊信息执行策略（支持连锁）
# - 提供多种特殊消除策略：小爆炸、大爆炸、闪电等

# ==================== 核心依赖 ====================
@export var gem_delete: GemDelete
@export var area: GameArea

# ==================== 配置参数 ====================
# 允许参与特殊删除的类型集合（在Inspector中设置）
# 如果为空，则默认允许所有非NONE的特殊类型
@export var special_delete_array: Array[GemStat.SpecialType]

# ==================== 公共接口函数 ====================

## 处理特殊宝石删除（从匹配结果）
## @param all_matches: GameCalculator返回的allmatches字典 {Vector2i: Gem}
## @return: 特殊宝石删除信息数组，每个元素包含center_tile、other_tiles、special_type
func process_special_gems(all_matches: Dictionary) -> Array[Dictionary]:
	if not _validate_dependencies():
		return []
	
	# 筛选出所有特殊宝石
	var special_gem_infos: Array[Dictionary] = _filter_special_gems(all_matches)
	if special_gem_infos.is_empty():
		return []
	
	# 为每个特殊宝石执行对应策略
	return _process_special_gem_list(special_gem_infos)

## 根据已捕获的特殊宝石信息执行删除策略（支持连锁）
## @param gem_infos: 特殊宝石信息数组 [{"position": Vector2i, "special_type": GemStat.SpecialType}]
## @return: 删除信息数组，每个元素包含center_tile、other_tiles、special_type
func process_special_gem_infos(gem_infos: Array[Dictionary]) -> Array[Dictionary]:
	if not _validate_dependencies():
		return []

	return _process_special_gem_list(gem_infos)

# ==================== 私有处理函数 ====================

## 处理特殊宝石列表
## @param gem_infos: 特殊宝石信息数组
## @return: 删除信息数组
func _process_special_gem_list(gem_infos: Array[Dictionary]) -> Array[Dictionary]:
	var delete_infos: Array[Dictionary] = []
	
	for info in gem_infos:
		if not _validate_gem_info(info):
			continue
			
		var delete_info = _execute_special_strategy(info)
		if not delete_info.is_empty():
			delete_infos.append(delete_info)

	return delete_infos

## 从allmatches中筛选出所有特殊宝石
## @param all_matches: GameCalculator返回的allmatches字典
## @return: 特殊宝石信息数组 [{"position": Vector2i, "gem": Gem, "special_type": GemStat.SpecialType}]
func _filter_special_gems(all_matches: Dictionary) -> Array[Dictionary]:
	var special_gems: Array[Dictionary] = []
	
	for position in all_matches.keys():
		var gem = all_matches[position]
		if not _is_valid_gem(gem):
			continue
		
		var special_type = gem._gem_stat.special_type
		if _is_allowed_special_type(special_type):
			special_gems.append(_create_gem_info(position, gem, special_type))
	
	return special_gems

## 为单个特殊宝石执行对应策略
## @param gem_info: 特殊宝石信息 {"position": Vector2i, "special_type": GemStat.SpecialType}
## @return: 删除信息字典 {"center_tile": Vector2i, "other_tiles": Array[Vector2i], "special_type": GemStat.SpecialType}
func _execute_special_strategy(gem_info: Dictionary) -> Dictionary:
	var position: Vector2i = gem_info["position"]
	var special_type: GemStat.SpecialType = gem_info["special_type"]
	
	match special_type:
		GemStat.SpecialType.SMALL_EXPLOSION:
			return _execute_small_explosion_strategy(position, special_type)
		GemStat.SpecialType.EXPLOSION:
			return _execute_explosion_strategy(position, special_type)
		GemStat.SpecialType.LIGHTING:
			return _execute_lightning_strategy(position, special_type)
		_:
			push_warning("SpecialDelete: 未知的特殊类型 %s" % special_type)
			return {}

# ==================== 特殊消除策略实现 ====================

## 小型爆炸策略：2x2方块消除，智能边界处理
## @param center: 特殊宝石位置
## @param special_type: 特殊类型
## @return: 删除信息字典
func _execute_small_explosion_strategy(center: Vector2i, special_type: GemStat.SpecialType) -> Dictionary:
	var best_area_tiles: Array[Vector2i] = _find_best_2x2_area(center)
	var other_tiles: Array[Vector2i] = _exclude_center_from_tiles(best_area_tiles, center)
	
	return _create_delete_info(center, other_tiles, special_type)

## 大型爆炸策略：3x3方块消除，边界跳过
## @param center: 特殊宝石位置
## @param special_type: 特殊类型
## @return: 删除信息字典
func _execute_explosion_strategy(center: Vector2i, special_type: GemStat.SpecialType) -> Dictionary:
	var other_tiles: Array[Vector2i] = _get_3x3_area_tiles(center)
	
	return _create_delete_info(center, other_tiles, special_type)

## 闪电策略：同横列和同纵列消除
## @param center: 特殊宝石位置
## @param special_type: 特殊类型
## @return: 删除信息字典
func _execute_lightning_strategy(center: Vector2i, special_type: GemStat.SpecialType) -> Dictionary:
	var other_tiles: Array[Vector2i] = _get_cross_line_tiles(center)
	
	return _create_delete_info(center, other_tiles, special_type)

# ==================== 区域计算辅助函数 ====================

## 寻找最佳的2x2区域（以center为其中一个角落）
## @param center: 中心位置
## @return: 最佳区域的所有瓦片
func _find_best_2x2_area(center: Vector2i) -> Array[Vector2i]:
	# 定义四个可能的2x2区域（以center为不同角落）
	var possible_areas = [
		_get_2x2_area_top_left(center),      # center为左上角
		_get_2x2_area_top_right(center),     # center为右上角
		_get_2x2_area_bottom_left(center),   # center为左下角
		_get_2x2_area_bottom_right(center)   # center为右下角
	]
	
	# 选择最多有效位置的区域
	var best_area: Array[Vector2i] = []
	var max_valid_count = 0
	
	for area_tiles in possible_areas:
		var valid_tiles: Array[Vector2i] = _filter_valid_tiles(area_tiles)
		
		if valid_tiles.size() > max_valid_count:
			max_valid_count = valid_tiles.size()
			best_area = valid_tiles
	
	return best_area

## 获取2x2区域（center为左上角）
## @param center: 左上角位置
## @return: 2x2区域的所有瓦片
func _get_2x2_area_top_left(center: Vector2i) -> Array[Vector2i]:
	return [
		center,
		center + Vector2i(1, 0),
		center + Vector2i(0, 1),
		center + Vector2i(1, 1)
	]

## 获取2x2区域（center为右上角）
## @param center: 右上角位置
## @return: 2x2区域的所有瓦片
func _get_2x2_area_top_right(center: Vector2i) -> Array[Vector2i]:
	return [
		center + Vector2i(-1, 0),
		center,
		center + Vector2i(-1, 1),
		center + Vector2i(0, 1)
	]

## 获取2x2区域（center为左下角）
## @param center: 左下角位置
## @return: 2x2区域的所有瓦片
func _get_2x2_area_bottom_left(center: Vector2i) -> Array[Vector2i]:
	return [
		center + Vector2i(0, -1),
		center + Vector2i(1, -1),
		center,
		center + Vector2i(1, 0)
	]

## 获取2x2区域（center为右下角）
## @param center: 右下角位置
## @return: 2x2区域的所有瓦片
func _get_2x2_area_bottom_right(center: Vector2i) -> Array[Vector2i]:
	return [
		center + Vector2i(-1, -1),
		center + Vector2i(0, -1),
		center + Vector2i(-1, 0),
		center
	]

## 获取3x3区域的其他瓦片（排除中心）
## @param center: 中心位置
## @return: 3x3区域的其他瓦片
func _get_3x3_area_tiles(center: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	
	# 3x3区域，以center为中心
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var tile = center + Vector2i(dx, dy)
			# 跳过中心位置，只添加有效位置
			if tile != center and _is_valid_position(tile):
				tiles.append(tile)
	
	return tiles

## 获取十字线的所有瓦片（排除中心）
## @param center: 中心位置
## @return: 十字线的所有瓦片
func _get_cross_line_tiles(center: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var grid_size = area.game_grid.size
	
	# 同横列（相同y坐标）
	for x in range(grid_size.x):
		var tile = Vector2i(x, center.y)
		if tile != center and _is_valid_position(tile):
			tiles.append(tile)
	
	# 同纵列（相同x坐标）
	for y in range(grid_size.y):
		var tile = Vector2i(center.x, y)
		if tile != center and _is_valid_position(tile):
			tiles.append(tile)
	
	return tiles

## 从瓦片列表中排除中心位置
## @param tiles: 瓦片列表
## @param center: 中心位置
## @return: 排除中心后的瓦片列表
func _exclude_center_from_tiles(tiles: Array[Vector2i], center: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile in tiles:
		if tile != center:
			result.append(tile)
	return result

## 过滤出有效的瓦片
## @param tiles: 瓦片列表
## @return: 有效的瓦片列表
func _filter_valid_tiles(tiles: Array[Vector2i]) -> Array[Vector2i]:
	var valid_tiles: Array[Vector2i] = []
	for tile in tiles:
		if _is_valid_position(tile):
			valid_tiles.append(tile)
	return valid_tiles

# ==================== 验证和工具函数 ====================

## 检查位置是否有效
## @param tile: 位置
## @return: 是否有效
func _is_valid_position(tile: Vector2i) -> bool:
	return area and area.game_grid and area.game_grid._is_valid_position(tile)

## 验证宝石是否有效
## @param gem: 宝石实例
## @return: 是否有效
func _is_valid_gem(gem: Gem) -> bool:
	return gem and gem._gem_stat

## 检查特殊类型是否被允许
## @param special_type: 特殊类型
## @return: 是否被允许
func _is_allowed_special_type(special_type: GemStat.SpecialType) -> bool:
	# 如果未在Inspector配置允许类型，则默认允许所有非NONE的特殊类型
	var allow_all: bool = special_delete_array.is_empty()
	return special_type != GemStat.SpecialType.NONE and (allow_all or special_type in special_delete_array)

## 验证宝石信息是否有效
## @param gem_info: 宝石信息
## @return: 是否有效
func _validate_gem_info(gem_info: Dictionary) -> bool:
	return gem_info.has("position") and gem_info.has("special_type")

## 验证依赖项
## @return: 是否验证通过
func _validate_dependencies() -> bool:
	if not gem_delete:
		push_error("SpecialDelete: gem_delete 未设置")
		return false
	if not area or not area.game_grid:
		push_error("SpecialDelete: area 或 game_grid 未设置")
		return false
	return true

# ==================== 数据构造函数 ====================

## 创建宝石信息字典
## @param position: 位置
## @param gem: 宝石实例
## @param special_type: 特殊类型
## @return: 宝石信息字典
func _create_gem_info(position: Vector2i, gem: Gem, special_type: GemStat.SpecialType) -> Dictionary:
	return {
		"position": position,
		"gem": gem,
		"special_type": special_type
	}

## 构造统一的删除信息字典
## @param center: 中心位置
## @param other_tiles: 其他瓦片
## @param special_type: 特殊类型
## @return: 删除信息字典
func _create_delete_info(center: Vector2i, other_tiles: Array[Vector2i], special_type: GemStat.SpecialType) -> Dictionary:
	return {
		"center_tile": center,
		"other_tiles": other_tiles,
		"special_type": special_type
	}

# ==================== 调试函数 ====================

## 打印删除信息的调试信息
## @param delete_infos: 删除信息数组
func debug_print_delete_infos(delete_infos: Array[Dictionary]) -> void:
	print("特殊删除信息数量: ", delete_infos.size())
	for i in range(delete_infos.size()):
		var info = delete_infos[i]
		print("  [", i, "] 中心: ", info.get("center_tile"), " 类型: ", info.get("special_type"), " 其他瓦片数: ", info.get("other_tiles", []).size())

# ==================== 兼容性函数 ====================
# 以下函数保持原有接口，确保向后兼容

## 构造删除信息字典（兼容接口）
func _make_delete_info(center: Vector2i, other_tiles: Array[Vector2i], special_type: GemStat.SpecialType) -> Dictionary:
	return _create_delete_info(center, other_tiles, special_type)
