extends GameState

# 记录本轮将要生成的特殊宝石中心位置，用于后续阶段排除
var _last_special_spawn_centers: Array[Vector2i] = []

func _on_enter() -> void:
	if not game:
		return
	
	# 1) 检查是否有数组1（special_remove_infos）需要处理
	if game.special_remove_infos.is_empty():
		# 如果没有特殊生成信息，直接进入特殊消除状态
		game.state_machine.change_state(GameState.State.特殊消除状态)
		return
	
	# 2) 对数组1中的每个RemoveInfo，筛去与特殊宝石字典重合的瓦片位置（除了中心瓦片）
	var filtered_special_remove_infos: Array[RemoveInfo] = []
	for remove_info in game.special_remove_infos:
		var filtered_remove_info = _filter_overlapping_tiles_for_special(remove_info, game.special_gems_dict)
		if filtered_remove_info != null:
			filtered_special_remove_infos.append(filtered_remove_info)
	
	# 3) 如果有过滤后的特殊生成信息，执行特殊宝石生成
	if filtered_special_remove_infos.size() > 0 and game.special_spawner:
		# 连接特殊生成完成信号
		game.special_spawner.special_spawning_completed.connect(_on_special_spawning_completed, Object.CONNECT_ONE_SHOT)
		# 记录本轮的生成中心位置，供后续特殊消除阶段排除
		_last_special_spawn_centers.clear()
		for ri in filtered_special_remove_infos:
			_last_special_spawn_centers.append(ri.center_tile)
		# 执行特殊宝石生成
		game.special_spawner.execute_special_gem_spawning(filtered_special_remove_infos)
	else:
		# 如果没有需要生成的特殊宝石，直接进入特殊消除状态
		# 清空特殊生成信息，避免后续状态误用这些信息触发特殊消除
		game.special_remove_infos.clear()
		game.state_machine.change_state(GameState.State.特殊消除状态)

# 过滤与特殊宝石字典重合的瓦片位置（除了中心瓦片）
func _filter_overlapping_tiles_for_special(remove_info: RemoveInfo, special_gems_dict: Dictionary) -> RemoveInfo:
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

	return filtered_remove_info

# 特殊宝石生成完成回调
func _on_special_spawning_completed(_remaining_remove_infos: Array[RemoveInfo]) -> void:
	if game and game.state_machine:
		# 特殊生成完成：清空特殊生成信息，避免在特殊消除中被误触发
		game.special_remove_infos.clear()
		# 记录刚生成的特殊宝石中心位置，供特殊消除阶段排除
		game.recently_spawned_special_tiles = _last_special_spawn_centers.duplicate()
		# 进入特殊消除状态
		game.state_machine.change_state(GameState.State.特殊消除状态)

# 扫描当前网格，收集所有特殊宝石信息（position + special_type）
func _collect_current_special_gem_infos() -> Array[Dictionary]:
	# 已不再在特殊生成完成后扫描全局特殊宝石；保留占位以兼容可能的外部调用
	return []

func _on_exit() -> void:
	pass

func process_physics(_delta: float) -> void:
	pass

func _on_input(_event: InputEvent) -> void:
	pass
