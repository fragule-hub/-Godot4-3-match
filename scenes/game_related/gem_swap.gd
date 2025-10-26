extends Node
class_name GemSwap

## 宝石交换管理器
## 
## 负责处理宝石交换的动画和逻辑，支持以下功能：
## - 预交换动画（用于验证交换有效性）
## - 反向交换动画（用于无效交换的回退）
## - 批量交换动画（用于同时交换多对宝石）
## - 统一的信号系统和错误处理

# 交换动画类型枚举
enum SwapAnimType { 
	NONE,        # 无动画状态
	PRE_SWAP,    # 预交换动画（用于验证）
	REVERSE_SWAP, # 反向交换动画（回退）
	BATCH_SWAP   # 批量交换动画
}

# ==================== 信号定义 ====================
## 逻辑交换完成信号（不包含动画）
signal swap_completed(from_tile: Vector2i, to_tile: Vector2i)

## 统一的动画完成信号，通过anim_type参数区分动画类型
signal swap_animation_completed(from_tile: Vector2i, to_tile: Vector2i, anim_type: SwapAnimType)

## 交换失败信号，包含失败原因
signal swap_failed(from_tile: Vector2i, to_tile: Vector2i, reason: String)

## 批量交换逻辑完成信号
signal swap_batch_completed(requests: Array)

## 批量交换动画完成信号
signal swap_batch_animation_completed(requests: Array)

# ==================== 导出属性 ====================
## 单次交换动画的持续时间（秒）
@export var swap_animation_duration := 0.5

## 游戏区域引用，用于访问游戏网格
@export var game_area: GameArea

# ==================== 私有状态变量 ====================
## 当前正在执行的动画类型
var _current_animation_type: SwapAnimType = SwapAnimType.NONE

## 当前等待完成的移动动画数量
var _pending_animation_count: int = 0

## 最后一次交换的源位置（用于信号回调）
var _last_swap_source_tile: Vector2i

## 最后一次交换的目标位置（用于信号回调）
var _last_swap_target_tile: Vector2i

## 当前批量交换请求列表
var _current_batch_swap_requests: Array = []

## ==================== 公共方法 ====================
## 检查是否正在执行交换动画
func is_swapping() -> bool:
	return _current_animation_type != SwapAnimType.NONE


# ==================== 动画接口 ====================

## 播放预交换动画（仅动画，不修改网格）
## 用于验证交换的有效性，如果交换有效则继续，无效则播放反向动画
func play_pre_swap_animation(from_tile: Vector2i, to_tile: Vector2i) -> void:
	var error_msg = _validate_swap_request(from_tile, to_tile)
	if error_msg != "":
		_emit_failed(from_tile, to_tile, error_msg)
		return
	if is_swapping():
		_emit_failed(from_tile, to_tile, "正在执行其他交换动画")
		return

	var gem1 := game_area.game_grid.get_gem(from_tile)
	var gem2 := game_area.game_grid.get_gem(to_tile)
	if gem1 == null and gem2 == null:
		_emit_failed(from_tile, to_tile, "两位置均为空，无法播放预动画")
		return

	_play_animation(gem1, gem2, from_tile, to_tile, swap_animation_duration, SwapAnimType.PRE_SWAP)

## 播放反向交换动画（仅动画，不修改网格）
## 用于无效交换的回退，让宝石回到原始位置
func play_reverse_swap_animation(from_tile: Vector2i, to_tile: Vector2i) -> void:
	var error_msg = _validate_swap_request(from_tile, to_tile)
	if error_msg != "":
		_emit_failed(from_tile, to_tile, error_msg)
		return
	if is_swapping():
		_emit_failed(from_tile, to_tile, "正在执行其他交换动画")
		return

	# 网格未变，宝石仍在原位
	var gem1 := game_area.game_grid.get_gem(from_tile)
	var gem2 := game_area.game_grid.get_gem(to_tile)
	if gem1 == null and gem2 == null:
		_emit_failed(from_tile, to_tile, "两位置均为空，无法播放反向动画")
		return
	
	# 反向动画：让宝石回到原始位置
	# 预动画后，gem1视觉上在to_tile位置，gem2视觉上在from_tile位置
	# 反向动画需要gem1回到from_tile，gem2回到to_tile
	# 在_play_animation中，gem1会移动到第3个参数位置，gem2会移动到第4个参数位置
	# 所以要让gem1移动到from_tile，gem2移动到to_tile，需要交换参数
	_play_animation(gem1, gem2, to_tile, from_tile, swap_animation_duration, SwapAnimType.REVERSE_SWAP, from_tile, to_tile)


# ==================== 核心逻辑接口 ====================

## 仅逻辑层：在网格上交换宝石（不播放动画）
func swap_gems_in_grid(from_tile: Vector2i, to_tile: Vector2i) -> Dictionary:
	return _swap_gems_in_grid(from_tile, to_tile)

## 执行逻辑交换并播放动画（用于有效交换）
func execute_swap_with_animation(from_tile: Vector2i, to_tile: Vector2i) -> void:
	var error_msg = _validate_swap_request(from_tile, to_tile)
	if error_msg != "":
		_emit_failed(from_tile, to_tile, error_msg)
		return
		
	var result := _swap_gems_in_grid(from_tile, to_tile)
	if result.get("gem1") == null and result.get("gem2") == null:
		_emit_failed(from_tile, to_tile, "两位置均为空，交换失败")
		return
		
	swap_completed.emit(from_tile, to_tile)
	# 注意：这里不播放动画，因为逻辑交换后宝石已经在正确位置了

## 批量交换宝石（支持动画）
## @param requests: 交换请求数组，每个元素包含from和to字段
## @param animate: 是否播放动画
func swap_gems_batch(requests: Array, animate: bool = true) -> void:
	var used_tiles := {}
	var operations: Array = []
	
	# 验证所有请求并准备操作
	for request in requests:
		var from_tile: Vector2i = request.get("from")
		var to_tile: Vector2i = request.get("to")
		var error_msg = _validate_swap_request(from_tile, to_tile)
		if error_msg != "" or used_tiles.has(from_tile) or used_tiles.has(to_tile):
			if error_msg != "":
				_emit_failed(from_tile, to_tile, error_msg)
			continue
		var gem1 := game_area.game_grid.get_gem(from_tile)
		var gem2 := game_area.game_grid.get_gem(to_tile)
		if gem1 == null and gem2 == null:
			continue
		operations.append({"from": from_tile, "to": to_tile, "gem1": gem1, "gem2": gem2})
		used_tiles[from_tile] = true
		used_tiles[to_tile] = true

	if operations.is_empty():
		return

	# 执行批量交换
	for operation in operations:
		game_area.game_grid.remove_gem(operation["from"])
		game_area.game_grid.remove_gem(operation["to"])
	for operation in operations:
		if operation["gem1"] != null: game_area.game_grid.add_gem(operation["to"], operation["gem1"])
		if operation["gem2"] != null: game_area.game_grid.add_gem(operation["from"], operation["gem2"])
		swap_completed.emit(operation["from"], operation["to"])
		
	swap_batch_completed.emit(operations)
	
	if animate:
		_play_batch_animations(operations, swap_animation_duration)


# ==================== 内部实现 ====================

## 内部方法：在网格中交换宝石的逻辑实现
func _swap_gems_in_grid(from_tile: Vector2i, to_tile: Vector2i) -> Dictionary:
	var error_msg = _validate_swap_request(from_tile, to_tile)
	if error_msg != "":
		return {"gem1": null, "gem2": null}
	var gem1 := game_area.game_grid.get_gem(from_tile)
	var gem2 := game_area.game_grid.get_gem(to_tile)
	if gem1 == null and gem2 == null:
		return {"gem1": null, "gem2": null}
		
	game_area.game_grid.remove_gem(from_tile)
	game_area.game_grid.remove_gem(to_tile)
	
	if gem1 != null: game_area.game_grid.add_gem(to_tile, gem1)
	if gem2 != null: game_area.game_grid.add_gem(from_tile, gem2)
	
	return {"gem1": gem1, "gem2": gem2}

## 将瓦片坐标转换为全局中心位置
func _tile_to_global_center(tile: Vector2i) -> Vector2:
	return game_area.get_global_from_tile(tile) - Gem.HALF_GEM_SIZE

## 启动宝石移动动画并连接完成信号
func _start_move_and_connect(gem: Gem, target_position: Vector2, duration: float) -> void:
	if not is_instance_valid(gem):
		return
	
	_pending_animation_count += 1
	
	# 先断开可能存在的连接，再重新连接
	if gem.move_completed.is_connected(_on_swap_move_completed):
		gem.move_completed.disconnect(_on_swap_move_completed)
	
	gem.move_completed.connect(_on_swap_move_completed, CONNECT_ONE_SHOT)
	gem.move_to_global_position(target_position, duration)

## 播放交换动画的核心实现
func _play_animation(gem1: Gem, gem2: Gem, from_tile: Vector2i, to_tile: Vector2i, duration: float, animation_type: SwapAnimType, signal_from_tile: Vector2i = Vector2i(-1,-1), signal_to_tile: Vector2i = Vector2i(-1,-1)) -> void:
	if not game_area or is_swapping():
		return
		
	_current_animation_type = animation_type
	_pending_animation_count = 0
	
	if signal_from_tile != Vector2i(-1,-1):
		_last_swap_source_tile = signal_from_tile
		_last_swap_target_tile = signal_to_tile
	else:
		_last_swap_source_tile = from_tile
		_last_swap_target_tile = to_tile
	
	_start_move_and_connect(gem1, _tile_to_global_center(to_tile), duration)
	_start_move_and_connect(gem2, _tile_to_global_center(from_tile), duration)
	
	if _pending_animation_count == 0:
		_current_animation_type = SwapAnimType.NONE
		# 如果没有有效gem，直接发送完成信号
		swap_animation_completed.emit(from_tile, to_tile, animation_type)

## 播放批量交换动画
func _play_batch_animations(operations: Array, duration: float) -> void:
	if not game_area or is_swapping():
		return
		
	_current_animation_type = SwapAnimType.BATCH_SWAP
	_current_batch_swap_requests = operations.duplicate()
	_pending_animation_count = 0
	
	for operation in operations:
		_start_move_and_connect(operation["gem1"], _tile_to_global_center(operation["to"]), duration)
		_start_move_and_connect(operation["gem2"], _tile_to_global_center(operation["from"]), duration)
		
	if _pending_animation_count == 0:
		_current_animation_type = SwapAnimType.NONE
		swap_batch_animation_completed.emit(_current_batch_swap_requests)
		_current_batch_swap_requests.clear()

## 处理单个宝石移动完成的回调
func _on_swap_move_completed() -> void:
	_pending_animation_count -= 1
	
	if _pending_animation_count <= 0:
		var completed_animation_type = _current_animation_type
		var source_tile = _last_swap_source_tile
		var target_tile = _last_swap_target_tile
		var batch_requests = _current_batch_swap_requests.duplicate()

		# 重置状态，允许新动画请求
		_current_animation_type = SwapAnimType.NONE
		_current_batch_swap_requests.clear()
		
		# 根据完成的动画类型发出相应信号
		if completed_animation_type == SwapAnimType.BATCH_SWAP:
			swap_batch_animation_completed.emit(batch_requests)
		else:
			swap_animation_completed.emit(source_tile, target_tile, completed_animation_type)

# ==================== 验证与错误处理 ====================
## 统一的交换请求验证
## @return 错误信息，空字符串表示验证通过
func _validate_swap_request(from_tile: Vector2i, to_tile: Vector2i) -> String:
	if game_area == null or game_area.game_grid == null:
		return "缺少必要的节点引用"
	if from_tile == to_tile:
		return "源位置和目标位置相同"
	if not game_area.game_grid._is_valid_position(from_tile):
		return "源位置无效"
	if not game_area.game_grid._is_valid_position(to_tile):
		return "目标位置无效"
	return ""

func _emit_failed(from_tile: Vector2i, to_tile: Vector2i, reason: String) -> void:
	swap_failed.emit(from_tile, to_tile, reason)
