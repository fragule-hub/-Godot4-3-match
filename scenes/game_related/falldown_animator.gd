extends Node
class_name FallDownAnimator

# 统一执行下落与生成的移动动画，并在全部完成后发射 all_animations_completed
signal all_animations_completed
signal wave_completed

@export var fall_duration: float = 0.3

var _pending_count := 0

# 执行所有移动（下落 + 生成），并等待所有 Gem.move_completed 收敛
func execute_all_moves(moves: Array[MoveInfo]) -> void:
	if moves.is_empty():
		all_animations_completed.emit()
		return
	var moving_gems: Array[Gem] = []
	var fall_moves: Array[MoveInfo] = []
	var spawn_moves: Array[MoveInfo] = []
	for move_info in moves:
		if move_info == null:
			continue
		# 分类：网格内(>=0)为下落；y<0 表示从上方生成
		if move_info.from_tile.y >= 0:
			fall_moves.append(move_info)
		else:
			spawn_moves.append(move_info)
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
	all_animations_completed.emit()

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
	
