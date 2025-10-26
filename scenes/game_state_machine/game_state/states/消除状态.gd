extends GameState


func _on_enter() -> void:
	if not game:
		return
	# 1) 计算当前所有匹配
	var matches: Dictionary = game.game_calculator.check_all_matches()
	if matches.is_empty():
		# 无匹配则回到基础状态
		game.state_machine.change_state(GameState.State.基础状态)
		return
	# 2) 批量删除匹配宝石（含动画），完成后进入生成状态
	var tiles: Array[Vector2i] = []
	for pos in matches.keys():
		if pos is Vector2i:
			tiles.append(pos)
	if game.gem_delete:
		game.gem_delete.batch_delete_completed.connect(_on_batch_delete_completed, Object.CONNECT_ONE_SHOT)
		game.gem_delete.delete_gems_batch(tiles, true)

func _on_exit() -> void:
	pass

func process_physics(_delta: float) -> void:
	pass

func _on_input(_event: InputEvent) -> void:
	pass

func _on_batch_delete_completed(_tiles: Array) -> void:
	if game and game.state_machine:
		game.state_machine.change_state(GameState.State.生成状态)
