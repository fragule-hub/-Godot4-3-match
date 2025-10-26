extends GameState


func _on_enter() -> void:
	if not game:
		return
	# 若无待移动项，直接回到交换状态
	if game.pending_move_infos.is_empty():
		game.state_machine.change_state(GameState.State.交换状态)
		return
	# 播放所有下落与生成动画（仅动画），完成后进入交换状态
	if game.falldown_animator:
		game.falldown_animator.all_animations_completed.connect(_on_all_falls_completed, Object.CONNECT_ONE_SHOT)
		game.falldown_animator.execute_all_moves(game.pending_move_infos)

func _on_exit() -> void:
	pass

func process_physics(_delta: float) -> void:
	pass

func _on_input(_event: InputEvent) -> void:
	pass

func _on_all_falls_completed() -> void:
	# 清理缓存并回到交换状态，继续处理队列
	if game:
		game.pending_move_infos.clear()
		game.state_machine.change_state(GameState.State.交换状态)
