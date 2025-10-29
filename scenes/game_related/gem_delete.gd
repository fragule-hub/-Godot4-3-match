extends Node
class_name GemDelete

# 负责删除宝石：先移除数据，再播放动画，收敛信号
# 简化版：收敛为“完成/失败”两类信号
signal delete_completed(tile: Vector2i)         # 单个删除完成（逻辑移除 + 动画结束后释放节点，或无动画立即完成）
signal batch_delete_completed(tiles: Array)     # 批量删除完成（所有项完成时一次性发射）
signal delete_failed(tile: Vector2i, reason: String)

@export var area: GameArea
@export var destroy_duration := 0.3

var _pending_destroy_count := 0
var _in_batch := false
var _batch_tiles: Array = []

# 单个删除（默认含动画）
func delete_gem(tile: Vector2i, animate: bool = true) -> void:
	if not _validate_position(tile):
		delete_failed.emit(tile, "无效位置")
		return
	var gem := area.game_grid.get_gem(tile)
	if gem == null:
		delete_failed.emit(tile, "位置为空，无法删除")
		return
	# 逻辑层：从网格移除
	area.game_grid.remove_gem(tile)
	# 表现层：动画或直接完成
	if animate:
		_pending_destroy_count = 1
		_in_batch = false
		_batch_tiles = [tile]
		gem.destroy_completed.connect(_on_destroy_completed.bind(tile, gem), Object.CONNECT_ONE_SHOT)
		gem.destroy_animation(destroy_duration)
	else:
		if is_instance_valid(gem):
			gem.queue_free()
		delete_completed.emit(tile)

# 批量删除（默认含动画）
func delete_gems_batch(tiles: Array, animate: bool = true) -> void:
	if not _validate_context():
		for t in tiles:
			if t is Vector2i:
				delete_failed.emit(t, "area或game_grid未正确设置")

	# 去重与校验
	var unique_tiles := {}
	var operations: Array = []
	for t in tiles:
		if not (t is Vector2i):
			continue
		if unique_tiles.has(t):
			continue
		if not area.game_grid._is_valid_position(t):
			delete_failed.emit(t, "无效位置")
			continue
		unique_tiles[t] = true
		var gem := area.game_grid.get_gem(t)
		if gem == null:
			delete_failed.emit(t, "位置为空，无法删除")
			continue
		# 逻辑层：先移除
		area.game_grid.remove_gem(t)
		operations.append({"tile": t, "gem": gem})
		# 无动画：直接完成
		if not animate:
			if is_instance_valid(gem):
				gem.queue_free()
			delete_completed.emit(t)
	# 统一动画触发与收敛
	if animate and not operations.is_empty():
		_in_batch = true
		_batch_tiles = []
		_pending_destroy_count = operations.size()
		for op in operations:
			var tile: Vector2i = op["tile"]
			if not op.has("gem") or not is_instance_valid(op["gem"]):
				continue
			var gem: Gem = op["gem"]
			_batch_tiles.append(tile)
			gem.destroy_completed.connect(_on_destroy_completed.bind(tile, gem), Object.CONNECT_ONE_SHOT)
			gem.destroy_animation(destroy_duration)
	elif not animate:
		if not operations.is_empty():
			var deleted_tiles: Array = []
			for op in operations:
				deleted_tiles.append(op["tile"])
			batch_delete_completed.emit(deleted_tiles)

# 动画收敛：逐个完成 + 批量结束
func _on_destroy_completed(tile: Vector2i, gem: Gem) -> void:
	if is_instance_valid(gem):
		gem.queue_free()
	delete_completed.emit(tile)
	_pending_destroy_count -= 1
	if _pending_destroy_count <= 0 and _in_batch:
		batch_delete_completed.emit(_batch_tiles)
		_batch_tiles.clear()

# 根据 RemoveInfo 数组批量删除宝石
func delete_gems_from_remove_infos(remove_infos: Array[RemoveInfo], animate: bool = true) -> void:
	if remove_infos.is_empty():
		# 如果数组为空，直接发出完成信号
		batch_delete_completed.emit([])
		return
	
	# 收集所有需要删除的位置
	var all_tiles: Array[Vector2i] = []
	
	for remove_info in remove_infos:
		if remove_info == null:
			continue
		
		# 获取每个 RemoveInfo 的所有位置
		var tiles_from_info = remove_info.get_all_tiles()
		
		# 将位置添加到总数组中
		for tile in tiles_from_info:
			if tile is Vector2i:
				all_tiles.append(tile)
	
	# 调用现有的批量删除方法
	delete_gems_batch(all_tiles, animate)

# 校验
func _validate_context() -> bool:
	return area != null and area.game_grid != null

func _validate_position(tile: Vector2i) -> bool:
	return _validate_context() and area.game_grid._is_valid_position(tile)
