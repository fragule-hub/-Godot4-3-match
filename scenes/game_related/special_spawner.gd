extends Node
class_name SpecialSpawner

# SpecialSpawner
# - 负责在匹配产生的 RemoveInfo 中，识别并生成对应的特殊宝石
# - 内部包含两层：
#   1) 计算层：将 RemoveInfo 分为需要特殊生成与普通消除两类
#   2) 执行层：对需要特殊生成的条目，调度移动+销毁动画，并把中心宝石转换为特殊类型
# - 对外保持原有接口：process_remove_infos 与 special_spawning_completed 信号

@export var gem_delete: GemDelete
@export var area: GameArea

@export_category("特殊宝石生成准则")
# 四消/五消/十字/大十字/长连 对应的特殊类型（保持导出名不变，避免破坏已有场景）
@export var 四消 := GemStat.SpecialType.SMALL_EXPLOSION
@export var 五消 := GemStat.SpecialType.SMALL_EXPLOSION
@export var 十字 := GemStat.SpecialType.SMALL_EXPLOSION
@export var 大十字 := GemStat.SpecialType.SMALL_EXPLOSION
@export var 长连 := GemStat.SpecialType.SMALL_EXPLOSION

# 信号：特殊宝石生成完成
signal special_spawning_completed(remaining_remove_infos: Array[RemoveInfo])

# 当前处理的动画计数器
var _pending_animations: int = 0
# 当前轮待处理与已处理的 RemoveInfo 集合
var _current_remove_infos: Array[RemoveInfo] = []
var _processed_remove_infos: Array[RemoveInfo] = []
# 已调度移动的 tile（集合用字典实现，键为 Vector2i，值为 bool）
var _scheduled_moving_tiles: Dictionary = {}
# 当前轮所有中心位置集合（避免把其他组合的中心也移动）
var _center_tiles_map: Dictionary = {}

## 计算层：从 RemoveInfo 数组中筛选出需要产生特殊宝石的类型
## @param remove_infos: 从 RemoveInfoCalculator 返回的 RemoveInfo 数组
## @return: 返回两个数组的字典 {"special": Array[RemoveInfo], "others": Array[RemoveInfo]}
func calculate_special_gem_separation(remove_infos: Array[RemoveInfo]) -> Dictionary:
	var special_remove_infos: Array[RemoveInfo] = []
	var other_remove_infos: Array[RemoveInfo] = []
	
	for remove_info in remove_infos:
		if _should_create_special_gem(remove_info):
			special_remove_infos.append(remove_info)
		else:
			other_remove_infos.append(remove_info)
	
	return {
		"special": special_remove_infos,
		"others": other_remove_infos
	}

## 执行层：接收需要特殊生成的 RemoveInfo 数组并执行动画与中心转换
## @param special_remove_infos: 需要产生特殊宝石的 RemoveInfo 数组
func execute_special_gem_spawning(special_remove_infos: Array[RemoveInfo]) -> void:
	if not _validate_dependencies():
		return
	
	if special_remove_infos.is_empty():
		special_spawning_completed.emit([])
		return
	
	_current_remove_infos = special_remove_infos.duplicate()
	_processed_remove_infos.clear()
	_pending_animations = 0
	_scheduled_moving_tiles.clear()
	_center_tiles_map.clear()
	for ri in special_remove_infos:
		_center_tiles_map[ri.center_tile] = true
	
	# 处理特殊宝石生成
	_process_special_gems(special_remove_infos)

## 兼容性函数：保持原有接口，内部调用新的分离函数
## @param remove_infos: 从 RemoveInfoCalculator 返回的 RemoveInfo 数组
## @return: 去除了已处理的 RemoveInfo 的数组
func process_remove_infos(remove_infos: Array[RemoveInfo]) -> Array[RemoveInfo]:
	var separation_result = calculate_special_gem_separation(remove_infos)
	var special_remove_infos: Array[RemoveInfo] = separation_result["special"]
	var other_remove_infos: Array[RemoveInfo] = separation_result["others"]
	
	if special_remove_infos.is_empty():
		special_spawning_completed.emit(other_remove_infos)
		return other_remove_infos
	
	execute_special_gem_spawning(special_remove_infos)
	return other_remove_infos

## 检查 RemoveInfo 是否应该生成特殊宝石
func _should_create_special_gem(remove_info: RemoveInfo) -> bool:
	match remove_info.remove_type:
		RemoveInfo.RemoveType.MATCH_4:
			return true
		RemoveInfo.RemoveType.MATCH_5:
			return true
		RemoveInfo.RemoveType.CROSS:
			return true
		RemoveInfo.RemoveType.BIG_CROSS:
			return true
		RemoveInfo.RemoveType.LONG_CHAIN:
			return true
		_:
			return false

## 获取对应的特殊宝石类型
func _get_special_type_for_remove_type(remove_type: RemoveInfo.RemoveType) -> GemStat.SpecialType:
	match remove_type:
		RemoveInfo.RemoveType.MATCH_4:
			return 四消
		RemoveInfo.RemoveType.MATCH_5:
			return 五消
		RemoveInfo.RemoveType.CROSS:
			return 十字
		RemoveInfo.RemoveType.BIG_CROSS:
			return 大十字
		RemoveInfo.RemoveType.LONG_CHAIN:
			return 长连
		_:
			return GemStat.SpecialType.NONE

## 处理特殊宝石生成
func _process_special_gems(special_remove_infos: Array[RemoveInfo]) -> void:
	for remove_info in special_remove_infos:
		_process_single_special_gem(remove_info)

## 处理单个特殊宝石的生成
## 执行单条 RemoveInfo 的特殊生成：
## 1) other_tiles（非中心）执行移动到中心并销毁动画
## 2) 将中心位置的宝石转换为对应的特殊类型
func _process_single_special_gem(remove_info: RemoveInfo) -> void:
	var center_tile = remove_info.center_tile
	var other_tiles = remove_info.other_tiles
	var center_global_pos = area.get_global_from_tile(center_tile)
	
	# 如果有 other_tiles，启动移动与销毁动画
	if not other_tiles.is_empty():
		for tile in other_tiles:
			# 避免把“作为其他组合中心”的位置也当作 other 去移动
			if _center_tiles_map.has(tile):
				continue
			# 去重：同一轮内，一个 tile 只安排一次移动与销毁
			if _scheduled_moving_tiles.has(tile):
				continue
			var gem = area.game_grid.get_gem(tile)
			if gem and is_instance_valid(gem):
				_scheduled_moving_tiles[tile] = true
				_pending_animations += 1
				var callable = _on_move_and_destroy_completed.bind(tile)
				if not gem.move_and_destroy_completed.is_connected(callable):
					gem.move_and_destroy_completed.connect(callable, Object.CONNECT_ONE_SHOT)
				# 启动移动与销毁动画
				gem.move_and_destroy_animation(center_global_pos - Gem.HALF_GEM_SIZE)
	
	# 修改中心位置的宝石为特殊类型
	_convert_center_gem_to_special(center_tile, remove_info)
	
	# 记录已处理的 RemoveInfo
	_processed_remove_infos.append(remove_info)
	
	# 如果没有动画需要等待，直接完成
	if _pending_animations == 0:
		_on_all_animations_completed()

## 将中心位置的宝石转换为特殊类型
## 将中心位置的宝石转换为特殊类型（复制 stat 以避免共享造成的污染）
func _convert_center_gem_to_special(center_tile: Vector2i, remove_info: RemoveInfo) -> void:
	var center_gem = area.game_grid.get_gem(center_tile)
	if not center_gem or not is_instance_valid(center_gem):
		return

	var gem_stat: GemStat = center_gem._gem_stat
	if not gem_stat:
		return

	# 获取对应的特殊类型
	var special_type = _get_special_type_for_remove_type(remove_info.remove_type)

	# 复制一份独立的 GemStat 再修改，避免共享导致的全局视觉污染
	var new_stat: GemStat = gem_stat.duplicate(true) as GemStat
	if new_stat == null:
		new_stat = gem_stat.duplicate() as GemStat
	new_stat.special_type = special_type
	# 使用属性赋值触发 Gem 的 setter，自动刷新动画与特殊材质
	center_gem.gem_stat = new_stat

## 移动与销毁动画完成回调
func _on_move_and_destroy_completed(tile: Vector2i) -> void:
	# 使用 gem_delete 的逻辑层删除
	if gem_delete:
		gem_delete.delete_gem(tile, false)  # 不播放动画，因为已经播放了移动与销毁动画
	
	_pending_animations -= 1
	
	# 所有动画完成后发出信号
	if _pending_animations <= 0:
		_on_all_animations_completed()

## 所有动画完成后的处理
## 所有动画完成后的处理：清理本轮数据并发出完成信号
func _on_all_animations_completed() -> void:
	# 计算剩余的 RemoveInfo（去除已处理的）
	var remaining_remove_infos: Array[RemoveInfo] = []
	for remove_info in _current_remove_infos:
		if not remove_info in _processed_remove_infos:
			remaining_remove_infos.append(remove_info)

	# 清理本轮的调度集合
	_scheduled_moving_tiles.clear()
	_center_tiles_map.clear()
	
	# 发出完成信号
	special_spawning_completed.emit(remaining_remove_infos)

## 验证依赖项
## 依赖检查：gem_delete 与 area.game_grid 必须存在
func _validate_dependencies() -> bool:
	if not gem_delete:
		push_error("SpecialSpawner: gem_delete 未设置")
		return false
	if not area or not area.game_grid:
		push_error("SpecialSpawner: area 或 game_grid 未设置")
		return false
	return true
