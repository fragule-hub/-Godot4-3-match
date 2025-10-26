extends Node
class_name GameCalculator

@export var area: GameArea

# 定义四个方向的向量
const DIRECTION_UP = Vector2i(0, -1)
const DIRECTION_DOWN = Vector2i(0, 1)
const DIRECTION_LEFT = Vector2i(-1, 0)
const DIRECTION_RIGHT = Vector2i(1, 0)


# 检测整个网格中的所有匹配（优化版本，避免重复检测）
func check_all_matches() -> Dictionary:
	if not area or not area.game_grid:
		return {}
	
	var all_matches: Dictionary = {}
	var grid_size = area.game_grid.size
	
	# 横向：仅从每段的最左端开始检测
	for y in grid_size.y:
		for x in grid_size.x:
			var tile = Vector2i(x, y)
			if not _is_segment_start(tile, DIRECTION_RIGHT):
				continue
			var color = _get_color(tile)
			if color == null:
				continue
			var matches: Array[Vector2i] = [tile]
			matches.append_array(_check_direction(tile, color, DIRECTION_RIGHT))
			if matches.size() >= 3:
				for pos in matches:
					var gem = area.game_grid.get_gem(pos)
					if gem:
						all_matches[pos] = gem
	
	# 纵向：仅从每段的最上端开始检测
	for x in grid_size.x:
		for y in grid_size.y:
			var tile = Vector2i(x, y)
			if not _is_segment_start(tile, DIRECTION_DOWN):
				continue
			var color = _get_color(tile)
			if color == null:
				continue
			var matches: Array[Vector2i] = [tile]
			matches.append_array(_check_direction(tile, color, DIRECTION_DOWN))
			if matches.size() >= 3:
				for pos in matches:
					var gem = area.game_grid.get_gem(pos)
					if gem:
						all_matches[pos] = gem
	
	return all_matches



# 检测单个方向的匹配
func _check_direction(start_tile: Vector2i, target_color: GemStat.GemColor, direction: Vector2i) -> Array[Vector2i]:
	var matched_positions: Array[Vector2i] = []
	var current_tile = start_tile + direction
	while _is_valid_position(current_tile):
		var color_next = _get_color(current_tile)
		if color_next == target_color:
			matched_positions.append(current_tile)
			current_tile += direction
		else:
			break
	return matched_positions

# 检查位置是否在网格范围内
func _is_valid_position(tile: Vector2i) -> bool:
	if not area or not area.game_grid:
		return false
	return area.game_grid._is_valid_position(tile)

# 获取某位置的颜色（真实网格）
func _get_color(tile: Vector2i):
	if not _is_valid_position(tile):
		return null
	var gem = area.game_grid.get_gem(tile)
	if gem and gem._gem_stat:
		return gem._gem_stat.color
	return null

# 判断是否为指定方向的段起点（前一格不同色或越界）
func _is_segment_start(tile: Vector2i, direction: Vector2i) -> bool:
	var color = _get_color(tile)
	if color == null:
		return false
	var prev_tile = tile - direction
	if _is_valid_position(prev_tile):
		var prev_color = _get_color(prev_tile)
		if prev_color == color:
			return false
	return true



# 检查某位置是否形成匹配（返回匹配位置列表，空则无）
func check_matches_at_position(tile: Vector2i) -> Array[Vector2i]:
	var color = _get_color(tile)
	if color == null:
		return []
	
	var horizontal: Array[Vector2i] = [tile]
	horizontal.append_array(_check_direction(tile, color, DIRECTION_LEFT))
	horizontal.append_array(_check_direction(tile, color, DIRECTION_RIGHT))
	
	var vertical: Array[Vector2i] = [tile]
	vertical.append_array(_check_direction(tile, color, DIRECTION_UP))
	vertical.append_array(_check_direction(tile, color, DIRECTION_DOWN))
	
	var result: Array[Vector2i] = []
	
	if horizontal.size() >= 3:
		result.append_array(horizontal)
	if vertical.size() >= 3:
		result.append_array(vertical)
	return result


# 检查交换两个位置后是否会产生匹配（基于虚拟网格，不改动真实网格）
func _would_create_match_after_swap(tile1: Vector2i, tile2: Vector2i) -> bool:
	if not area or not area.game_grid:
		return false
	var vgrid = _build_virtual_color_grid()
	return _would_create_match_after_swap_on_vgrid(tile1, tile2, vgrid)


# 检查是否有可能的匹配（用于游戏结束判断，使用虚拟网格）
func has_possible_matches() -> bool:
	if not area or not area.game_grid:
		return false
	var grid_size = area.game_grid.size
	var dirs: Array[Vector2i] = [DIRECTION_UP, DIRECTION_DOWN, DIRECTION_LEFT, DIRECTION_RIGHT]
	var vgrid = _build_virtual_color_grid()
	
	for x in grid_size.x:
		for y in grid_size.y:
			var tile = Vector2i(x, y)
			var color = vgrid[x][y]
			if color == null:
				continue
			for direction in dirs:
				var adjacent_tile = tile + direction
				if _is_valid_position(adjacent_tile):
					var adj_color = vgrid[adjacent_tile.x][adjacent_tile.y]
					# 同色无需交换
					if adj_color != null and adj_color == color:
						continue
					if _would_create_match_after_swap_on_vgrid(tile, adjacent_tile, vgrid):
						return true
	return false


# 初始化虚拟网格
func _initialize_virtual_grid(virtual_grid: Array[Array], grid_size: Vector2i) -> void:
	virtual_grid.clear()
	for x in grid_size.x:
		var column: Array = []
		for y in grid_size.y:
			column.append(null)
		virtual_grid.append(column)

# 构建颜色虚拟网格（用 null 表示空位）
func _build_virtual_color_grid() -> Array:
	var grid_size = area.game_grid.size
	var vgrid: Array[Array] = []
	_initialize_virtual_grid(vgrid, grid_size)
	for x in grid_size.x:
		for y in grid_size.y:
			var gem = area.game_grid.get_gem(Vector2i(x, y))
			if gem and gem._gem_stat:
				vgrid[x][y] = gem._gem_stat.color
			else:
				vgrid[x][y] = null
	return vgrid

# 从虚拟网格读取颜色
func _get_color_from_vgrid(vgrid: Array, tile: Vector2i):
	if not _is_valid_position(tile):
		return null
	return vgrid[tile.x][tile.y]

# 在虚拟网格上按方向检查匹配（不包含起点）
func _check_direction_on_vgrid(start_tile: Vector2i, target_color, direction: Vector2i, vgrid: Array) -> Array[Vector2i]:
	if target_color == null:
		return []
	var matches: Array[Vector2i] = []
	var current_tile = start_tile + direction
	while _is_valid_position(current_tile):
		var color_next = _get_color_from_vgrid(vgrid, current_tile)
		if color_next == target_color:
			matches.append(current_tile)
			current_tile += direction
		else:
			break
	return matches

# 在虚拟网格上检查某个位置的所有匹配（双向累积，避免漏判）
func check_matches_at_position_on_vgrid(tile: Vector2i, vgrid: Array) -> Array[Vector2i]:
	var start_color = _get_color_from_vgrid(vgrid, tile)
	if start_color == null:
		return []
	# 横向：左右两侧都累积（不包含起点的方向列表）
	var h_right = _check_direction_on_vgrid(tile, start_color, DIRECTION_RIGHT, vgrid)
	var h_left = _check_direction_on_vgrid(tile, start_color, DIRECTION_LEFT, vgrid)
	var horizontal_matches: Array[Vector2i] = [tile]
	horizontal_matches.append_array(h_right)
	horizontal_matches.append_array(h_left)
	# 纵向：上下两侧都累积（不包含起点的方向列表）
	var v_down = _check_direction_on_vgrid(tile, start_color, DIRECTION_DOWN, vgrid)
	var v_up = _check_direction_on_vgrid(tile, start_color, DIRECTION_UP, vgrid)
	var vertical_matches: Array[Vector2i] = [tile]
	vertical_matches.append_array(v_down)
	vertical_matches.append_array(v_up)
	
	var result: Array[Vector2i] = []
	
	if horizontal_matches.size() >= 3:
		result.append_array(horizontal_matches)
	if vertical_matches.size() >= 3:
		result.append_array(vertical_matches)
	return result

# 基于虚拟网格的模拟交换检查
func _would_create_match_after_swap_on_vgrid(tile1: Vector2i, tile2: Vector2i, vgrid: Array) -> bool:
	var c1 = _get_color_from_vgrid(vgrid, tile1)
	var c2 = _get_color_from_vgrid(vgrid, tile2)
	if c1 == null or c2 == null:
		return false
	# 同色无需交换
	if c1 == c2:
		return false
	# 临时交换
	vgrid[tile1.x][tile1.y] = c2
	vgrid[tile2.x][tile2.y] = c1
	# 检查两处是否有匹配
	var m1 = check_matches_at_position_on_vgrid(tile1, vgrid)
	var m2 = check_matches_at_position_on_vgrid(tile2, vgrid)
	var has_match = m1.size() > 0 or m2.size() > 0
	# 还原
	vgrid[tile1.x][tile1.y] = c1
	vgrid[tile2.x][tile2.y] = c2
	return has_match

# 生成初始三消布局（无三连），返回用于 spawn_gems_batch 的数组
func generate_safe_initial_spawn_batch(gem_stats: Array[GemStat]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not area or not area.game_grid:
		push_error("GameCalculator: area 或 game_grid 未设置")
		return result
	if gem_stats.is_empty():
		push_warning("GameCalculator: gem_stats 为空，无法生成布局")
		return result
	
	var grid_size = area.game_grid.size
	var vgrid: Array[Array] = []
	_initialize_virtual_grid(vgrid, grid_size) # 使用颜色占位（null 表示未填）
	
	# 构建颜色到可用 GemStat 的映射
	var color_to_stats_all: Dictionary = {}
	var all_colors: Array = []
	for stat in gem_stats:
		if stat == null:
			continue
		var color = stat.color
		if not color_to_stats_all.has(color):
			color_to_stats_all[color] = []
			all_colors.append(color)
		color_to_stats_all[color].append(stat)
	
	var pool_colors: Array = all_colors
	var pool_map: Dictionary = color_to_stats_all
	
	# 至少需要三种颜色来保证始终可避免三连
	var unique_color_count = pool_colors.size()
	if unique_color_count < 3:
		push_warning("GameCalculator: 可用颜色不足以生成安全布局（至少需要3种颜色）")
		return result
	
	# 辅助：根据当前约束挑选可用颜色（lambda）
	var pick_color_for_tile := func(x: int, y: int) -> GemStat.GemColor:
		var disallowed: Array = []
		# 左侧两格相同则禁止该颜色
		if x >= 2:
			var c1 = vgrid[x - 1][y]
			var c2 = vgrid[x - 2][y]
			if c1 != null and c2 != null and c1 == c2:
				disallowed.append(c1)
		# 上方两格相同则禁止该颜色
		if y >= 2:
			var u1 = vgrid[x][y - 1]
			var u2 = vgrid[x][y - 2]
			if u1 != null and u2 != null and u1 == u2:
				disallowed.append(u1)
		# 选择不在禁止列表中的颜色
		var candidates: Array = []
		for c in pool_colors:
			var blocked = false
			for d in disallowed:
				if c == d:
					blocked = true
					break
			if not blocked and pool_map.has(c) and pool_map[c].size() > 0:
				candidates.append(c)
		if candidates.is_empty():
			return GemStat.GemColor.OTHER
		return candidates[randi() % candidates.size()]
	
	# 填充整个虚拟网格（按行列）
	for y in grid_size.y:
		for x in grid_size.x:
			var chosen_color: GemStat.GemColor = pick_color_for_tile.call(x, y)
			if chosen_color == GemStat.GemColor.OTHER:
				push_warning("GameCalculator: 在位置 " + str(Vector2i(x, y)) + " 找不到可用颜色以避免三连")
				return []
			vgrid[x][y] = chosen_color
			# 按颜色挑选一个 GemStat
			var stats_pool: Array = pool_map[chosen_color]
			var chosen_stat: GemStat = stats_pool[randi() % stats_pool.size()]
			result.append({
				"position": Vector2i(x, y),
				"gem_stat": chosen_stat
			})
	
	return result
