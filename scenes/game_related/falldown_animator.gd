extends Node
class_name FallDownAnimator

# 信号：所有动画完成
signal all_animations_completed
signal wave_completed

# 下落动画持续时间
@export var fall_duration: float = 0.3

# 当前是否正在执行动画
var _is_animating: bool = false
var _pending_count: int = 0

func _ready() -> void:
	pass

# 仅执行所有移动动画（不修改网格）
func execute_all_moves(move_infos: Array[MoveInfo]) -> void:
	"""
	执行所有移动动画，包括下落和新生成的宝石
	"""
	if _is_animating:
		push_warning("FallDownAnimator: 已经在执行动画，忽略重复调用")
		return
	
	if move_infos.is_empty():
		all_animations_completed.emit()
		return
	
	_is_animating = true
	await _execute_wave(move_infos)
	_is_animating = false
	all_animations_completed.emit()

# 执行波次动画（每个子数组是一轮，不修改网格）
func execute_waves(waves: Array[Array]) -> void:
	if _is_animating:
		push_warning("FallDownAnimator: 已经在执行动画，忽略重复调用")
		return
	_is_animating = true
	for wave in waves:
		if wave.is_empty():
			continue
		await _execute_wave(wave)
	_is_animating = false
	all_animations_completed.emit()

# 执行单轮动画，区分原有与上方新生成
func _execute_wave(move_infos: Array[MoveInfo]) -> void:
	var moving_gems: Array[Gem] = []
	var fall_moves: Array[MoveInfo] = []
	var spawn_moves: Array[MoveInfo] = []
	for move_info in move_infos:
		if move_info.from_tile.y < 0:
			spawn_moves.append(move_info)
		else:
			fall_moves.append(move_info)
	# 原有宝石下落：开启弹跳（use_bounce=true），不旋转
	for move_info in fall_moves:
		var gem = move_info.gem
		if gem and is_instance_valid(gem):
			gem.move_to_global_position(move_info.to_global_position, fall_duration, false, true)
			moving_gems.append(gem)
	# 上方新生成宝石：先轻微缩放，再执行下落到目标；开启弹跳
	for move_info in spawn_moves:
		var gem = move_info.gem
		if gem and is_instance_valid(gem):
			gem.scale = Vector2(0.9, 0.9)
			var t := create_tween()
			t.tween_property(gem, "scale", Vector2.ONE, 0.1)
			gem.move_to_global_position(move_info.to_global_position, fall_duration, false, true)
			moving_gems.append(gem)
	# 等待所有gem移动完成（信号聚合）
	await _wait_all_completed(moving_gems)

func _wait_all_completed(moving_gems: Array[Gem]) -> void:
	_pending_count = 0
	for gem in moving_gems:
		if gem and is_instance_valid(gem):
			_pending_count += 1
			gem.move_completed.connect(_on_one_move_completed, Object.CONNECT_ONE_SHOT)
	if _pending_count == 0:
		return
	await wave_completed

func _on_one_move_completed() -> void:
	_pending_count -= 1
	if _pending_count <= 0:
		wave_completed.emit()

# 检查是否正在执行动画
func is_animating() -> bool:
	"""检查是否正在执行动画"""
	return _is_animating

# 停止所有动画（紧急情况使用）
func stop_all_animations() -> void:
	"""停止所有正在进行的动画"""
	_is_animating = false
	
