# 状态：消除。使用匹配状态计算的数据批量删除宝石，完成后进入特殊生成状态
extends GameState

func _on_enter() -> void:
	if not game:
		return
	
	# 1) 检查是否有数组2（other_remove_infos）需要处理
	if game.other_remove_infos.is_empty():
		# 如果没有普通删除信息，直接进入特殊生成状态
		game.state_machine.change_state(GameState.State.特殊生成状态)
		return
	
	# 2) 处理数组2中的每个removeinfo，删除与特殊宝石字典重合的瓦片（除了中心瓦片）
	var filtered_remove_infos: Array[RemoveInfo] = []
	for remove_info in game.other_remove_infos:
		var filtered_remove_info = _filter_overlapping_tiles(remove_info, game.special_gems_dict)
		if filtered_remove_info != null:
			filtered_remove_infos.append(filtered_remove_info)
	
	# 3) 收集所有需要删除的瓦片位置
	var tiles_to_delete: Array[Vector2i] = []
	for remove_info in filtered_remove_infos:
		var is_center_special = game.special_gems_dict.has(remove_info.center_tile)
		# 始终避免在普通删除阶段删除特殊中心，让特殊消除阶段接管
		if not is_center_special:
			tiles_to_delete.append(remove_info.center_tile)
		# 添加其他瓦片
		for tile in remove_info.other_tiles:
			if not tiles_to_delete.has(tile):
				tiles_to_delete.append(tile)
	
	# 4) 清空数组2
	game.other_remove_infos.clear()
	
	# 5) 如果有瓦片需要删除，执行批量删除
	if tiles_to_delete.size() > 0 and game.gem_delete:
		game.gem_delete.batch_delete_completed.connect(_on_batch_delete_completed, Object.CONNECT_ONE_SHOT)
		game.gem_delete.delete_gems_batch(tiles_to_delete, true)
	else:
		# 如果没有瓦片需要删除，直接进入特殊生成状态
		game.state_machine.change_state(GameState.State.特殊生成状态)

# 过滤与特殊宝石字典重合的瓦片（除了中心瓦片）
func _filter_overlapping_tiles(remove_info: RemoveInfo, special_gems_dict: Dictionary) -> RemoveInfo:
	if not remove_info:
		return null
	
	var filtered_other_tiles: Array[Vector2i] = []
	
	# 遍历other_tiles，排除与特殊宝石字典重合的位置（除非是中心瓦片）
	for tile in remove_info.other_tiles:
		# 如果该位置不在特殊宝石字典中，或者该位置是中心瓦片，则保留
		if not special_gems_dict.has(tile) or tile == remove_info.center_tile:
			filtered_other_tiles.append(tile)
	
	# 创建新的RemoveInfo，保持原有属性但使用过滤后的other_tiles
	var filtered_remove_info = RemoveInfo.new(
		remove_info.color,
		remove_info.remove_type,
		remove_info.gem_count,
		remove_info.cause_type,
		remove_info.center_tile,
		filtered_other_tiles
	)
	# 优化：不再直接丢弃整个条目，交由上层在收集阶段判断是否跳过中心删除
	return filtered_remove_info

func _on_exit() -> void:
	# 清理保存的匹配数据
	if game:
		game.current_matches.clear()
		game.current_remove_infos.clear()

func process_physics(_delta: float) -> void:
	pass

func _on_input(_event: InputEvent) -> void:
	pass

# 删除完成后进入特殊生成状态
func _on_batch_delete_completed(_tiles: Array) -> void:
	if game and game.state_machine:
		game.state_machine.change_state(GameState.State.特殊生成状态)
