extends Node
class_name FallDownCalculator

@export var area: GameArea

# 下落计算器，只负责计算不执行动画

# 使用Arena中定义的MoveInfo类

func _ready() -> void:
	pass

# 计算下落并返回移动信息
func calculate_fall_down() -> Array[MoveInfo]:
	"""计算宝石下落逻辑，返回所有移动信息"""
	if not area or not area.game_grid:
		push_error("FallDownCalculator: area或game_grid未设置")
		return []
	# 使用波次计算，并扁平化为列表
	var waves: Array[Array] = calculate_fall_down_waves()
	var all_moves: Array[MoveInfo] = []
	for w in waves:
		all_moves.append_array(w)
	return all_moves

# 计算所有下落移动（按波次返回，不修改真实网格）
func calculate_fall_down_waves() -> Array[Array]:
	var waves: Array[Array] = []
	if not area or not area.game_grid:
		return waves
	var grid_size = area.game_grid.size
	# 创建虚拟网格副本
	var virtual_grid = _create_grid_copy(_get_current_grid(), grid_size)
	# 持续计算直到没有更多移动
	while true:
		var move_list: Array[MoveInfo] = _collect_all_moves(virtual_grid, grid_size)
		if move_list.is_empty():
			break
		waves.append(move_list)
		# 应用到虚拟网格，不影响真实网格
		_apply_moves_to_grid(move_list, virtual_grid)
	return waves

# 计算所有下落移动
func _calculate_all_moves() -> Array[MoveInfo]:
	"""计算所有下落移动，返回移动信息数组"""
	var all_moves: Array[MoveInfo] = []
	var grid = _get_current_grid()
	if not grid:
		return all_moves
	
	var grid_size = area.game_grid.size
	
	# 持续计算直到没有更多移动
	while true:
		var move_list: Array[MoveInfo] = _collect_all_moves(grid, grid_size)
		
		if move_list.size() == 0:
			break
		
		
		
		# 将移动信息添加到总列表
		all_moves.append_array(move_list)
		
		# 更新网格状态（不执行动画）
		_apply_moves_to_grid(move_list, grid)

	return all_moves

# 收集所有需要移动的gem信息
func _collect_all_moves(grid: Array[Array], grid_size: Vector2i) -> Array[MoveInfo]:
	"""
	收集所有需要移动的gem信息
	返回Arena.MoveInfo数组
	"""
	var move_list: Array[MoveInfo] = []
	
	# 创建grid的副本用于计算，避免影响原始数据
	var temp_grid = _create_grid_copy(grid, grid_size)
	
	# 遍历网格：x从0到结尾，y从结尾到0
	for x in range(grid_size.x):
		_collect_column_moves(x, temp_grid, grid_size, move_list)
	
	return move_list

# 创建网格副本
func _create_grid_copy(grid: Array[Array], grid_size: Vector2i) -> Array[Array]:
	"""
	创建网格的副本
	"""
	var copy: Array[Array] = []
	copy.resize(grid_size.x)
	
	for x in range(grid_size.x):
		copy[x] = []
		copy[x].resize(grid_size.y)
		for y in range(grid_size.y):
			copy[x][y] = grid[x][y]
	
	return copy

# 收集单列的移动信息
func _collect_column_moves(x: int, grid: Array[Array], grid_size: Vector2i, move_list: Array[MoveInfo]) -> void:
	"""
	收集单列的移动信息
	"""
	# y从结尾到0遍历（从下到上）
	for y in range(grid_size.y - 1, -1, -1):
		var current_tile = Vector2i(x, y)
		
		# 如果当前位置为空，向上查找非空tile
		if _is_tile_empty(current_tile, grid):
			var source_tile = _find_gem_above(current_tile, grid)
			
			if source_tile != Vector2i(-1, -1):
				# 找到了上方的gem，添加到移动列表
				var gem = grid[source_tile.x][source_tile.y] as Gem
				if gem:
					var from_global = area.get_global_from_tile(source_tile) - Gem.HALF_GEM_SIZE
					var to_global = area.get_global_from_tile(current_tile) - Gem.HALF_GEM_SIZE
					var move_info = MoveInfo.new(source_tile, current_tile, gem, from_global, to_global)
					move_list.append(move_info)
					
					# 在临时网格中标记这个移动，避免重复处理
					grid[source_tile.x][source_tile.y] = null
					grid[current_tile.x][current_tile.y] = gem

# 将移动应用到网格（不执行动画）
func _apply_moves_to_grid(move_list: Array[MoveInfo], grid: Array[Array]) -> void:
	"""将移动应用到网格状态，不执行动画"""
	for move_info in move_list:
		var from_tile = move_info.from_tile
		var to_tile = move_info.to_tile
		var gem = move_info.gem
		
		# 更新网格数据
		grid[from_tile.x][from_tile.y] = null
		grid[to_tile.x][to_tile.y] = gem



# 获取当前网格
func _get_current_grid() -> Array[Array]:
	"""获取当前网格的引用"""
	if not area or not area.game_grid:
		return []
	return area.game_grid.gems

# 检查指定位置是否为空
func _is_tile_empty(tile: Vector2i, grid: Array[Array]) -> bool:
	"""检查指定位置是否为空"""
	if not _is_valid_position(tile):
		return false
	return grid[tile.x][tile.y] == null

# 检查位置是否有效
func _is_valid_position(tile: Vector2i) -> bool:
	"""检查位置是否在网格范围内"""
	if not area or not area.game_grid:
		return false
	var size = area.game_grid.size
	return tile.x >= 0 and tile.x < size.x and tile.y >= 0 and tile.y < size.y

# 向上查找非空的tile
func _find_gem_above(empty_tile: Vector2i, grid: Array[Array]) -> Vector2i:
	"""
	从指定的空位置向上查找第一个非空的tile
	返回找到的tile位置，如果没找到返回(-1, -1)
	"""
	# 从empty_tile的上方开始向上查找
	for y in range(empty_tile.y - 1, -1, -1):
		var check_tile = Vector2i(empty_tile.x, y)
		if not _is_tile_empty(check_tile, grid):
			return check_tile
	
	# 没有找到非空的tile
	return Vector2i(-1, -1)

# 将下落移动应用到真实网格（不执行动画），仅处理原有宝石的下落
func apply_fall_moves_to_real_grid(move_infos: Array[MoveInfo]) -> void:
	if not area or not area.game_grid:
		return
	for move_info in move_infos:
		var from_tile := move_info.from_tile
		var to_tile := move_info.to_tile
		var gem := move_info.gem
		# 仅处理网格内的原有宝石
		if from_tile.y >= 0 and gem and is_instance_valid(gem):
			area.game_grid.remove_gem(from_tile)
			area.game_grid.add_gem(to_tile, gem)
