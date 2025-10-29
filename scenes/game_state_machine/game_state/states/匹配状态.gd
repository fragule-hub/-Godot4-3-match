# 状态：匹配
# - 计算全局匹配，拆分特殊/普通字典并缓存到 Arena
# - 计算移除信息，拆分为 special/others，更新统计与展示
# - 完成后进入消除状态
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
	
	# 2) 通过specialdelete筛选特殊宝石和非特殊宝石
	var special_gems_dict: Dictionary = {}
	var normal_gems_dict: Dictionary = {}
	
	if game.special_delete:
		# 筛选特殊宝石（使用公共接口）
		var special_delete_infos = game.special_delete.process_special_gems(matches)
		for delete_info in special_delete_infos:
			var center_position = delete_info["center_tile"]
			if matches.has(center_position):
				special_gems_dict[center_position] = matches[center_position]
		
		# 筛选非特殊宝石
		for position in matches.keys():
			if not special_gems_dict.has(position):
				normal_gems_dict[position] = matches[position]
	else:
		# 如果没有special_delete，所有宝石都视为非特殊宝石
		normal_gems_dict = matches.duplicate()
	
	# 3) 保存字典1（特殊宝石）和字典2（非特殊宝石）到Arena
	game.special_gems_dict = special_gems_dict
	game.normal_gems_dict = normal_gems_dict
	
	# 4) 清空allmatches（原current_matches）
	game.current_matches.clear()
	
	# 5) 对特殊宝石播放旋转动画
	_start_special_gems_rotation_animation(special_gems_dict)
	
	# 6) 通过移除信息计算器计算移除信息
	var remove_infos: Array[RemoveInfo] = []
	if game.remove_info_calculator:
		# 使用全量匹配字典计算移除信息（包含特殊宝石参与段长判定）
		# 这样即使匹配中含有特殊宝石，也能正确识别四消/五消/十字等需要生成特殊的类型
		remove_infos = game.remove_info_calculator.calculate(matches)
		
		# 7) 如果有当前交换位置数组，为每个位置标记交换操作
		if game.current_swap_tiles.size() > 0:
			for swap_tile in game.current_swap_tiles:
				remove_infos = game.remove_info_calculator.mark_swap_for_tile(swap_tile, remove_infos)
			# 清空交换位置数组
			game.current_swap_tiles.clear()
		
		# 8) 通过specialspawner筛选special和other数组
		if game.special_spawner:
			var separation_result = game.special_spawner.calculate_special_gem_separation(remove_infos)
			game.special_remove_infos = separation_result["special"]  # 数组1
			game.other_remove_infos = separation_result["others"]     # 数组2
		else:
			# 如果没有special_spawner，所有移除信息都视为other
			game.special_remove_infos = []
			game.other_remove_infos = remove_infos
		
		# 9) 将移除信息添加到统计数据中
		if game.remove_info_statistics:
			# 使用批量接口更新统计，触发统计更新信号驱动UI刷新
			game.remove_info_statistics.add_remove_infos(remove_infos)
	
	# 11) 计算完成，进入消除状态
	game.state_machine.change_state(GameState.State.消除状态)

## 为特殊宝石播放旋转动画（仅视觉层，可选）
func _start_special_gems_rotation_animation(special_gems: Dictionary) -> void:
	for position in special_gems.keys():
		var gem = special_gems[position]
		if gem and is_instance_valid(gem):
			gem.start_effect_animation()

func _on_exit() -> void:
	pass

func process_physics(_delta: float) -> void:
	pass

func _on_input(_event: InputEvent) -> void:
	pass
