extends Node2D
class_name GameGrid

signal game_grid_changed

@export var size: Vector2i

var gems: Array[Array] = []
var empty_count: int = 0  # 当前网格中空位的数量


func _ready() -> void:
	_initialize_grid()

# 初始化二维数组
func _initialize_grid() -> void:
	gems.clear()
	gems.resize(size.x)
	for i in size.x:
		gems[i] = []
		gems[i].resize(size.y)
		for j in size.y:
			gems[i][j] = null
	
	# 初始化时所有位置都是空的
	empty_count = size.x * size.y

# 边界检查
func _is_valid_position(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < size.x and tile.y >= 0 and tile.y < size.y

# 获取宝石
func get_gem(tile: Vector2i) -> Gem:
	if not _is_valid_position(tile):
		return null
	return gems[tile.x][tile.y]


func add_gem(tile: Vector2i, gem: Gem) -> void:
	if not _is_valid_position(tile):
		push_warning("尝试在无效位置添加宝石: " + str(tile))
		return
	
	# 如果位置已有宝石，先移除
	if gems[tile.x][tile.y]:
		remove_gem(tile)
	
	gems[tile.x][tile.y] = gem
	
	empty_count -= 1
	
	game_grid_changed.emit()

func remove_gem(tile: Vector2i) -> void:
	if not _is_valid_position(tile):
		push_warning("尝试在无效位置移除宝石: " + str(tile))
		return
		
	var gem := gems[tile.x][tile.y] as Gem
	if not gem:
		return
	
	gems[tile.x][tile.y] = null
	
	# 增加空位计数
	empty_count += 1
	
	game_grid_changed.emit()


# 获取第一个为空的位置
func get_first_empty_position() -> Vector2i:
	for i in size.x:
		for j in size.y:
			if gems[i][j] == null:
				return Vector2i(i, j)
	return Vector2i(-1, -1)  # 返回无效位置表示没有空位

# 获取当前所有为空的位置
func get_all_empty_positions() -> Array[Vector2i]:
	var empty_positions: Array[Vector2i] = []
	for i in size.x:
		for j in size.y:
			if gems[i][j] == null:
				empty_positions.append(Vector2i(i, j))
	return empty_positions

# 获取当前存在的所有gem
func get_all_gems() -> Array[Gem]:
	var all_gems: Array[Gem] = []
	for i in size.x:
		for j in size.y:
			if gems[i][j] != null:
				all_gems.append(gems[i][j])
	return all_gems

# 获取当前存在的所有gem及其位置（返回字典数组）
func get_all_gems_with_positions() -> Array[Dictionary]:
	var gems_with_positions: Array[Dictionary] = []
	for i in size.x:
		for j in size.y:
			if gems[i][j] != null:
				gems_with_positions.append({
					"gem": gems[i][j],
					"position": Vector2i(i, j)
				})
	return gems_with_positions

# 获取随机位置（包括空位和有宝石的位置）
func get_random_position() -> Vector2i:
	if size.x <= 0 or size.y <= 0:
		return Vector2i(-1, -1)  # 无效网格大小
	var random_x = randi() % size.x
	var random_y = randi() % size.y
	return Vector2i(random_x, random_y)

# 检查位置是否为空
func is_empty(tile: Vector2i) -> bool:
	if not _is_valid_position(tile):
		return false
	return gems[tile.x][tile.y] == null

# 获取当前空位数量
func get_empty_count() -> int:
	return empty_count

# 获取已占用(不为空的)位置数量
func get_occupied_count() -> int:
	return (size.x * size.y) - empty_count

# 检查网格是否已满
func is_full() -> bool:
	return empty_count == 0

# 检查网格是否全空
func is_grid_empty() -> bool:
	return empty_count == size.x * size.y
