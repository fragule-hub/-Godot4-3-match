extends Node
class_name GemSpawner

signal gem_spawned(gem: Gem)
signal all_gems_regenerated(gems: Array[Gem])

const GEM = preload("res://scenes/gem/gem.tscn")

@export var area: GameArea

var _grid_size: Vector2i
var _is_initialized: bool = false

func _ready() -> void:
	_initialize()

# 初始化spawner，缓存必要信息
func _initialize() -> void:
	if not area or not area.game_grid:
		push_error("GemSpawner: area 或 game_grid 未正确设置")
		return
	
	_grid_size = area.game_grid.size
	_is_initialized = true

# 生成单个宝石
func spawn_gem(tile: Vector2i, gem_stat: GemStat) -> Gem:
	if not _is_initialized:
		_initialize()
	if not _is_valid_spawn_position(tile):
		push_warning("GemSpawner: 尝试在无效位置生成宝石: " + str(tile))
		return null
	
	var new_gem := _create_gem_instance(gem_stat)
	if not new_gem:
		return null
	
	_place_gem_in_grid(tile, new_gem)
	gem_spawned.emit(new_gem)
	
	return new_gem

# 重新生成所有gem
func regenerate_all_gems(gem_stats: Array[GemStat]) -> Array[Gem]:
	if not _is_initialized:
		_initialize()
	if gem_stats.is_empty():
		push_warning("GemSpawner: gem_stats数组为空，无法生成宝石")
		return []
	
	# 清空当前网格
	_clear_grid()
	
	# 获取网格大小
	var grid_size = area.game_grid.size
	
	var generated_gems: Array[Gem] = []
	
	# 遍历网格并生成随机宝石直到网格被占满
	for x in grid_size.x:
		for y in grid_size.y:
			var tile_pos = Vector2i(x, y)
			var random_gem_stat = _get_random_gem_stat(gem_stats)
			
			var new_gem = spawn_gem(tile_pos, random_gem_stat)
			if new_gem:
				generated_gems.append(new_gem)
	
	all_gems_regenerated.emit(generated_gems)
	return generated_gems

# 获取随机gem stat
func _get_random_gem_stat(gem_stats: Array[GemStat]) -> GemStat:
	if gem_stats.is_empty():
		push_error("GemSpawner: gem_stats数组为空")
		return null
	
	var random_index = randi() % gem_stats.size()
	return gem_stats[random_index]


# 批量生成宝石（优化版本）
func spawn_gems_batch(positions_and_stats: Array[Dictionary]) -> Array[Gem]:
	var spawned_gems: Array[Gem] = []
	
	for item in positions_and_stats:
		if not item.has("position") or not item.has("gem_stat"):
			push_warning("GemSpawner: 批量生成数据格式错误")
			continue
		
		var gem = spawn_gem(item.position, item.gem_stat)
		if gem:
			spawned_gems.append(gem)
	
	return spawned_gems


# 清空网格中的所有宝石
func _clear_grid() -> void:
	var all_gems = area.game_grid.get_all_gems()
	
	# 移除所有宝石节点
	for gem in all_gems:
		if is_instance_valid(gem):
			gem.queue_free()
	
	# 清空网格数据
	for x in _grid_size.x:
		for y in _grid_size.y:
			area.game_grid.remove_gem(Vector2i(x, y))

# 验证生成位置是否有效
func _is_valid_spawn_position(tile: Vector2i) -> bool:
	if not area or not area.game_grid:
		return false
	
	return area.game_grid._is_valid_position(tile)

# 创建宝石实例
func _create_gem_instance(gem_stat: GemStat) -> Gem:
	if not gem_stat:
		push_error("GemSpawner: gem_stat为null")
		return null

	var new_gem := GEM.instantiate() as Gem
	if not new_gem:
		push_error("GemSpawner: 无法实例化宝石")
		return null

	# 为每个宝石复制独立的 GemStat，避免共享资源被修改时影响所有同色宝石
	var per_gem_stat := gem_stat.duplicate(true) as GemStat
	if per_gem_stat == null:
		per_gem_stat = gem_stat.duplicate() as GemStat
	new_gem.gem_stat = per_gem_stat
	return new_gem

# 将宝石放置到网格中
func _place_gem_in_grid(tile: Vector2i, gem: Gem) -> void:
	# 添加到场景树
	area.game_grid.add_child(gem)
	
	# 添加到网格
	area.game_grid.add_gem(tile, gem)
	
	# 设置位置
	gem.global_position = area.get_global_from_tile(tile) - Gem.HALF_GEM_SIZE


# 生成宝石在上方位置（用于下落动画），支持列偏移
func spawn_gem_above_grid(tile: Vector2i, gem_stat: GemStat, y_offset: int = 1) -> MoveInfo:
	"""
	在指定tile位置生成宝石，但将宝石放置在上方（y=-y_offset），
	返回移动信息以便后续执行下落动画
	"""
	if not _is_initialized:
		_initialize()
	
	if not _is_valid_spawn_position(tile):
		push_warning("GemSpawner: 尝试在无效位置生成宝石: " + str(tile))
		return null
	# 目标位置必须为空，避免覆盖已有宝石
	if not area.game_grid.is_empty(tile):
		push_warning("GemSpawner: 目标位置已有宝石，禁止上方生成: " + str(tile))
		return null
	
	var new_gem := _create_gem_instance(gem_stat)
	if not new_gem:
		return null
	
	# 添加到场景树
	area.game_grid.add_child(new_gem)
	
	# 添加到网格的目标位置
	area.game_grid.add_gem(tile, new_gem)
	
	# 计算上方位置（y=-y_offset 对应的全局位置）
	var above_tile = Vector2i(tile.x, -y_offset)
	var from_global_position = area.get_global_from_tile(above_tile) - Gem.HALF_GEM_SIZE
	var to_global_position = area.get_global_from_tile(tile) - Gem.HALF_GEM_SIZE
	
	# 设置宝石的初始位置为上方
	new_gem.global_position = from_global_position
	
	# 创建移动信息
	var move_info = MoveInfo.new(above_tile, tile, new_gem, from_global_position, to_global_position)
	
	gem_spawned.emit(new_gem)
	return move_info

# 随机生成宝石填充空位（生成在上方，固定y=-1）
func spawn_random_gems_for_empty_positions(gem_stats: Array[GemStat]) -> Array[MoveInfo]:
	"""
	获取网格中所有空位，随机生成宝石填充，
	宝石生成在上方位置，返回移动信息数组
	"""
	if not _is_initialized:
		_initialize()
	
	if gem_stats.is_empty():
		push_warning("GemSpawner: gem_stats数组为空，无法生成宝石")
		return []
	
	# 获取所有空位
	var empty_positions = _get_all_empty_positions()
	if empty_positions.is_empty():
		return []
	
	var move_infos: Array[MoveInfo] = []
	
	# 为每个空位随机生成宝石（统一y=-1）
	for empty_pos in empty_positions:
		var random_gem_stat = _get_random_gem_stat(gem_stats)
		var move_info = spawn_gem_above_grid(empty_pos, random_gem_stat, 1)
		if move_info:
			move_infos.append(move_info)
	
	return move_infos

# 按列偏移生成：同列多个空位将使用 y=-1, -2, ...
func spawn_gems_for_empty_positions_with_offsets(gem_stats: Array[GemStat]) -> Array[MoveInfo]:
	if not _is_initialized:
		_initialize()
	if gem_stats.is_empty():
		push_warning("GemSpawner: gem_stats数组为空，无法生成宝石")
		return []
	var grid_size = area.game_grid.size
	var move_infos: Array[MoveInfo] = []
	for x in range(grid_size.x):
		var spawn_index: int = 1
		for y in range(grid_size.y):
			var tile := Vector2i(x, y)
			if area.game_grid.is_empty(tile):
				var random_gem_stat = _get_random_gem_stat(gem_stats)
				var move_info = spawn_gem_above_grid(tile, random_gem_stat, spawn_index)
				if move_info:
					move_infos.append(move_info)
					spawn_index += 1
	return move_infos

# 获取所有空位
func _get_all_empty_positions() -> Array[Vector2i]:
	"""获取网格中所有空位的位置"""
	var empty_positions: Array[Vector2i] = []
	
	if not area or not area.game_grid:
		return empty_positions
	
	var grid_size = area.game_grid.size
	var grid = area.game_grid.gems
	
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos = Vector2i(x, y)
			if grid[x][y] == null:
				empty_positions.append(pos)
	
	return empty_positions
