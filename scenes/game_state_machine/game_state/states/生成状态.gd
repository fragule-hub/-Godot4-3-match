extends GameState


func _on_enter() -> void:
	if not game:
		return
	# 1) 计算当前网格中的所有下落（不修改真实网格）
	var fall_moves: Array[MoveInfo] = []
	if game.falldown_calculator:
		fall_moves = game.falldown_calculator.calculate_fall_down()
	# 2) 先应用下落到真实网格（仅数据层，不播放动画）
	if game.falldown_calculator and not fall_moves.is_empty():
		game.falldown_calculator.apply_fall_moves_to_real_grid(fall_moves)
	# 3) 顶部补全：生成空位的宝石与其移动信息（带列偏移）
	var spawn_moves: Array[MoveInfo] = []
	if game.gem_spawner:
		spawn_moves = game.gem_spawner.spawn_gems_for_empty_positions_with_offsets(game.gems)
	# 4) 合并两类 MoveInfo 并存入主场景（Arena）
	game.pending_move_infos.clear()
	game.pending_move_infos.append_array(fall_moves)
	game.pending_move_infos.append_array(spawn_moves)
	# 5) 转入下落状态播放统一动画
	game.state_machine.change_state(GameState.State.下落状态)

func _on_exit() -> void:
	pass

func process_physics(_delta: float) -> void:
	pass

func _on_input(_event: InputEvent) -> void:
	pass
