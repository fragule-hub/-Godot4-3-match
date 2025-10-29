extends GameState

# ==================== 核心数据结构 ====================
# 当前处理的特殊宝石信息队列（位置 + 特殊类型）
var current_special_gem_infos: Array[Dictionary] = []

# 当前轮待统计的销毁型 RemoveInfo（按颜色聚合）
var pending_destroy_remove_infos: Array[RemoveInfo] = []

# ==================== 动画时序配置 ====================
# 爆炸动画间隔时间（分批播放）
const EXPLOSION_INTERVAL_SEC := 0.2
# 闪电类别延迟时间（爆炸与闪电之间的间隔）
const LIGHTNING_CATEGORY_DELAY_SEC := 0.1

# ==================== 状态跟踪变量 ====================
# 本轮已逻辑删除的瓦片注册表（避免重复删除与重复统计）
var _deleted_tiles_registry: Dictionary = {}

# 当前轮动画类型标记
var _has_explosions: bool = false
var _has_lightning: bool = false
var _lightning_active: bool = false

# ==================== 状态生命周期 ====================
func _on_enter() -> void:
	if not game:
		return
	
	# 重置状态跟踪变量
	_reset_round_state()
	
	# 清理上一轮的被振飞宝石记录
	_clear_previous_shaken_gems()
	
	# 收集种子特殊宝石位置
	var seed_tiles: Array[Vector2i] = _collect_seed_tiles()
	
	# 提取特殊宝石信息
	var seed_infos: Array[Dictionary] = _extract_special_gem_infos(seed_tiles)
	if seed_infos.is_empty():
		# 没有特殊宝石需要处理，直接进入生成状态
		_cleanup_and_enter_generation_state()
		return

	# 开始处理特殊宝石消除
	_process_special_gems(seed_infos)

func _on_exit() -> void:
	# 清理当前状态的数据
	current_special_gem_infos.clear()
	pending_destroy_remove_infos.clear()
	
	# 条件性恢复被振飞的宝石（仅在有爆炸时）
	if _has_explosions and game and game.special_delete_animator:
		game.special_delete_animator.restore_shaken_gems_to_original_positions()
	
	# 重置状态跟踪变量
	_reset_round_state()

func process_physics(_delta: float) -> void:
	pass

func _on_input(_event: InputEvent) -> void:
	pass

# ==================== 私有辅助函数 ====================
## 重置当前轮的状态跟踪变量
func _reset_round_state() -> void:
	_has_explosions = false
	_has_lightning = false
	_lightning_active = false

## 清理上一轮的被振飞宝石记录
func _clear_previous_shaken_gems() -> void:
	if game and game.special_delete_animator:
		game.special_delete_animator.clear_shaken_gems_record()

## 收集种子特殊宝石位置
func _collect_seed_tiles() -> Array[Vector2i]:
	var seed_tiles: Array[Vector2i] = []
	
	# 从特殊宝石字典中收集位置
	for position in game.special_gems_dict.keys():
		seed_tiles.append(position)
	
	# 排除本轮刚生成的特殊宝石中心位置（避免刚生成即被错误销毁）
	if game.recently_spawned_special_tiles.size() > 0:
		var filtered_tiles: Array[Vector2i] = []
		for tile in seed_tiles:
			if not game.recently_spawned_special_tiles.has(tile):
				filtered_tiles.append(tile)
		seed_tiles = filtered_tiles
	
	return seed_tiles

# ==================== 特殊宝石信息处理 ====================
## 从瓦片数组中提取特殊宝石信息
func _extract_special_gem_infos(tiles: Array[Vector2i]) -> Array[Dictionary]:
	var infos: Array[Dictionary] = []
	for tile in tiles:
		var gem = game.area.game_grid.get_gem(tile)
		if gem and gem._gem_stat and gem._gem_stat.special_type != GemStat.SpecialType.NONE:
			infos.append({
				"position": tile,
				"special_type": gem._gem_stat.special_type
			})
	return infos

## 处理特殊宝石消除逻辑
func _process_special_gems(gem_infos: Array[Dictionary]) -> void:
	print("SpecialDeleteState: _process_special_gems called with ", gem_infos.size(), " gems: ", gem_infos)
	
	if gem_infos.is_empty():
		print("SpecialDeleteState: no special gems, entering generation state")
		_cleanup_and_enter_generation_state()
		return

	if not game.special_delete:
		print("SpecialDeleteState: no special_delete component, entering generation state")
		_cleanup_and_enter_generation_state()
		return

	# 执行特殊删除策略，获取删除信息
	var delete_infos = game.special_delete.process_special_gem_infos(gem_infos)

	# 收集本轮中心位置（用于统计时排除）
	var excluded_centers: Array[Vector2i] = _extract_center_positions(gem_infos)

	# 分类动画信息：爆炸与闪电
	var explosion_infos: Array[Dictionary] = []
	var lightning_infos: Array[Dictionary] = []
	_categorize_animations(delete_infos, explosion_infos, lightning_infos)

	# 更新状态跟踪
	_has_explosions = not explosion_infos.is_empty()
	_has_lightning = not lightning_infos.is_empty()

	# 重置删除注册表
	_deleted_tiles_registry.clear()
	
	# 清空当前特殊宝石信息列表，避免重复处理
	current_special_gem_infos.clear()
	print("SpecialDeleteState: cleared current_special_gem_infos to avoid reprocessing")

	# 调度动画播放
	_schedule_animations(explosion_infos, lightning_infos, excluded_centers, delete_infos)

## 提取中心位置数组
func _extract_center_positions(gem_infos: Array[Dictionary]) -> Array[Vector2i]:
	var centers: Array[Vector2i] = []
	for info in gem_infos:
		var pos: Vector2i = info["position"]
		if not centers.has(pos):
			centers.append(pos)
	return centers

## 分类动画信息
func _categorize_animations(delete_infos: Array[Dictionary], explosion_infos: Array[Dictionary], lightning_infos: Array[Dictionary]) -> void:
	for info in delete_infos:
		if not info.has("special_type"):
			continue
		
		var special_type: GemStat.SpecialType = info["special_type"]
		match special_type:
			GemStat.SpecialType.SMALL_EXPLOSION, GemStat.SpecialType.EXPLOSION:
				explosion_infos.append(info)
			GemStat.SpecialType.LIGHTING:
				lightning_infos.append(info)

## 调度动画播放
func _schedule_animations(explosion_infos: Array[Dictionary], lightning_infos: Array[Dictionary], excluded_centers: Array[Vector2i], delete_infos: Array[Dictionary]) -> void:
	# 调度爆炸动画
	_schedule_explosions(explosion_infos, excluded_centers)

	# 计算延迟时间 - 修复：确保等待所有爆炸动画真正完成
	var explosion_delay := 0.0
	if explosion_infos.size() > 0:
		# 最后一个爆炸动画开始时间 + 单个爆炸动画持续时间
		var last_explosion_start_time := float(explosion_infos.size() - 1) * EXPLOSION_INTERVAL_SEC
		var single_explosion_duration := 0.75  # 从arena.tscn中获取的boom_duration_sec
		explosion_delay = last_explosion_start_time + single_explosion_duration
		print("SpecialDeleteState: explosion delay calculated: ", explosion_delay, " (", explosion_infos.size(), " explosions)")
	
	var category_delay := 0.0
	
	# 只在爆炸和闪电都存在时才应用类别延迟
	if _has_explosions and _has_lightning:
		category_delay = LIGHTNING_CATEGORY_DELAY_SEC
	
	var total_delay := explosion_delay + category_delay
	
	# 调度后续流程
	if _has_lightning:
		_lightning_active = true
		_schedule_lightning_and_continue(lightning_infos, excluded_centers, delete_infos, total_delay)
	elif _has_explosions:
		_schedule_continue_after_explosions(delete_infos, total_delay)
	else:
		# 既没有爆炸也没有闪电，直接进入生成状态
		_cleanup_and_enter_generation_state()

# ==================== 动画调度函数 ====================
## 调度爆炸动画
func _schedule_explosions(explosion_infos: Array[Dictionary], excluded_centers: Array[Vector2i]) -> void:
	for i in range(explosion_infos.size()):
		var info: Dictionary = explosion_infos[i]
		var delay := float(i) * EXPLOSION_INTERVAL_SEC
		
		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(func() -> void:
			_play_explosion_animation(info)
			_delete_explosion_tiles(info, excluded_centers)
		, Object.CONNECT_ONE_SHOT)

## 调度闪电动画和后续流程
func _schedule_lightning_and_continue(lightning_infos: Array[Dictionary], excluded_centers: Array[Vector2i], delete_infos: Array[Dictionary], delay: float) -> void:
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void:
		_play_lightning_and_delete(lightning_infos, excluded_centers)
		_wait_for_lightning_then_continue(delete_infos)
	, Object.CONNECT_ONE_SHOT)

## 调度爆炸完成后的继续流程
func _schedule_continue_after_explosions(delete_infos: Array[Dictionary], delay: float) -> void:
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void:
		_continue_special_elimination(delete_infos)
	, Object.CONNECT_ONE_SHOT)

# ==================== 动画播放函数 ====================
## 播放爆炸动画
func _play_explosion_animation(info: Dictionary) -> void:
	if not game or not game.special_delete_animator:
		return
	
	var special_type: GemStat.SpecialType = info.get("special_type", GemStat.SpecialType.NONE)
	match special_type:
		GemStat.SpecialType.SMALL_EXPLOSION:
			game.special_delete_animator.create_small_explosion(info)
		GemStat.SpecialType.EXPLOSION:
			game.special_delete_animator.create_explosion(info)

## 删除爆炸影响的瓦片
func _delete_explosion_tiles(info: Dictionary, excluded_centers: Array[Vector2i]) -> void:
	var tiles_to_delete: Array[Vector2i] = []
	
	# 收集需要删除的瓦片
	var center_tile: Vector2i = info["center_tile"]
	var other_tiles: Array[Vector2i] = info["other_tiles"]
	tiles_to_delete.append(center_tile)
	tiles_to_delete.append_array(other_tiles)

	# 在删除前提取特殊宝石信息用于连锁
	var explosion_special_gems: Array[Dictionary] = _extract_special_gem_infos(tiles_to_delete)
	print("SpecialDeleteState: found ", explosion_special_gems.size(), " special gems in explosion tiles: ", tiles_to_delete)
	
	# 将新发现的特殊宝石添加到当前列表中（避免重复）
	for gem_info in explosion_special_gems:
		var position: Vector2i = gem_info["position"]
		var already_exists = false
		
		for existing_info in current_special_gem_infos:
			if existing_info["position"] == position:
				already_exists = true
				break
		
		if not already_exists:
			current_special_gem_infos.append(gem_info)
			print("SpecialDeleteState: added special gem for next round: ", gem_info)

	# 执行删除（去重 + 存在校验）
	var actually_deleted: Array[Vector2i] = []
	if game and game.gem_delete and game.area and game.area.game_grid:
		for tile in tiles_to_delete:
			if _deleted_tiles_registry.has(tile):
				continue
			
			var gem := game.area.game_grid.get_gem(tile)
			if gem:
				_deleted_tiles_registry[tile] = true
				game.gem_delete.delete_gem(tile, true)
				actually_deleted.append(tile)

	# 更新统计信息
	_update_destroy_statistics(actually_deleted, excluded_centers)

## 播放闪电动画并删除瓦片
func _play_lightning_and_delete(lightning_infos: Array[Dictionary], excluded_centers: Array[Vector2i]) -> void:
	if lightning_infos.is_empty():
		return

	var union_tiles: Array[Vector2i] = []
	var tile_set := {}

	# 播放闪电动画并收集影响的瓦片
	for info in lightning_infos:
		if game and game.special_delete_animator:
			game.special_delete_animator.create_lightning_cross(info)
		
		# 收集瓦片位置
		var center: Vector2i = info["center_tile"]
		var others: Array[Vector2i] = info["other_tiles"]
		
		_add_tile_to_set(center, tile_set, union_tiles)
		for tile in others:
			_add_tile_to_set(tile, tile_set, union_tiles)

	# 关键修复：在删除宝石前先提取特殊宝石信息用于下一轮连锁
	var next_round_special_gems: Array[Dictionary] = []
	if union_tiles.size() > 0:
		# 从即将被删除的瓦片中提取特殊宝石信息
		next_round_special_gems = _extract_special_gem_infos(union_tiles)
		
		# 存储到实例变量中，供后续使用
		current_special_gem_infos = next_round_special_gems

	# 批量删除瓦片
	if union_tiles.size() > 0 and game and game.gem_delete:
		# 标记为已删除
		for tile in union_tiles:
			_deleted_tiles_registry[tile] = true
		
		game.gem_delete.delete_gems_batch(union_tiles, true)

	# 更新统计信息
	_update_destroy_statistics(union_tiles, excluded_centers)

## 添加瓦片到集合（去重 + 存在校验）
func _add_tile_to_set(tile: Vector2i, tile_set: Dictionary, union_tiles: Array[Vector2i]) -> void:
	if _deleted_tiles_registry.has(tile) or tile_set.has(tile):
		return
	
	if game.area and game.area.game_grid and game.area.game_grid.get_gem(tile):
		tile_set[tile] = true
		union_tiles.append(tile)

# ==================== 统计更新函数 ====================
## 更新销毁统计信息
func _update_destroy_statistics(tiles: Array[Vector2i], excluded_centers: Array[Vector2i]) -> void:
	if not game or not game.remove_info_statistics or tiles.is_empty():
		return
	
	# 按颜色分组
	var color_groups: Dictionary = {}
	for tile in tiles:
		var gem = game.area.game_grid.get_gem(tile)
		if not gem or not gem._gem_stat:
			continue
		
		var gem_color: GemStat.GemColor = gem._gem_stat.color
		if not color_groups.has(gem_color):
			color_groups[gem_color] = []
		color_groups[gem_color].append(tile)

	# 为每种颜色创建 RemoveInfo
	for color in color_groups.keys():
		var color_tiles: Array[Vector2i] = []
		color_tiles.append_array(color_groups[color])
		
		# 排除特殊中心位置
		var filtered_tiles: Array[Vector2i] = []
		for tile in color_tiles:
			if not excluded_centers.has(tile):
				filtered_tiles.append(tile)
		
		if filtered_tiles.size() == 0:
			continue
		
		# 创建 RemoveInfo
		var center: Vector2i = filtered_tiles[0]
		var others: Array[Vector2i] = []
		for i in range(1, filtered_tiles.size()):
			others.append(filtered_tiles[i])
		
		var remove_info := RemoveInfo.new(
			color, 
			RemoveInfo.RemoveType.DESTROY, 
			filtered_tiles.size(), 
			RemoveInfo.CauseType.CASCADE, 
			center, 
			others
		)
		game.remove_info_statistics.add_remove_info(remove_info)

# ==================== 流程控制函数 ====================
## 等待闪电动画完成后继续
func _wait_for_lightning_then_continue(delete_infos: Array[Dictionary]) -> void:
	if not game or not game.special_delete_animator:
		_continue_special_elimination(delete_infos)
		return
	
	# 修复：计算闪电动画的真实完成时间
	# 闪电动画总时间 = 播放时间 + 淡出时间 + 粒子消散时间
	var lightning_play_duration: float = game.special_delete_animator.lightning_duration_sec
	var fade_duration: float = 0.25  # LightningLine的fade_duration_sec默认值
	var particle_lifetime: float = 0.5  # 从lightning_line.tscn中获取的粒子生命周期
	var total_lightning_duration: float = lightning_play_duration + fade_duration + particle_lifetime + 0.05  # 额外0.05秒缓冲
	print("SpecialDeleteState: lightning delay calculated: ", total_lightning_duration, " (play: ", lightning_play_duration, " + fade: ", fade_duration, " + particles: ", particle_lifetime, ")")
	
	# 创建定时器等待闪电动画完成
	var timer := get_tree().create_timer(total_lightning_duration)
	timer.timeout.connect(func() -> void:
		_lightning_active = false
		_continue_special_elimination(delete_infos)
	, Object.CONNECT_ONE_SHOT)

## 继续特殊消除流程
func _continue_special_elimination(delete_infos: Array[Dictionary]) -> void:
	# 检查是否已经有预提取的特殊宝石信息（来自闪电删除）
	if current_special_gem_infos.size() > 0:
		# 直接使用已提取的特殊宝石信息
		_check_continue_elimination()
		return
	
	# 如果没有预提取的信息，则从受影响的瓦片中收集（用于爆炸等其他情况）
	var affected_tiles: Array[Vector2i] = []
	var tile_set := {}
	
	for info in delete_infos:
		var center: Vector2i = info["center_tile"]
		var others: Array[Vector2i] = info["other_tiles"]
		
		if not tile_set.has(center):
			tile_set[center] = true
			affected_tiles.append(center)
		
		for tile in others:
			if not tile_set.has(tile):
				tile_set[tile] = true
				affected_tiles.append(tile)

	# 提取下一轮特殊宝石信息
	current_special_gem_infos = _extract_special_gem_infos(affected_tiles)
	_check_continue_elimination()

## 检查是否继续特殊消除
func _check_continue_elimination() -> void:
	# 过滤掉已经被删除的特殊宝石信息
	var valid_special_gem_infos: Array[Dictionary] = []
	
	for gem_info in current_special_gem_infos:
		var position: Vector2i = gem_info["position"]
		
		# 检查位置是否已被删除
		if _deleted_tiles_registry.has(position):
			print("SpecialDeleteState: skipping deleted position: ", position)
			continue
		
		# 检查位置是否仍有有效的特殊宝石
		if game and game.area and game.area.game_grid:
			var gem := game.area.game_grid.get_gem(position)
			if gem and gem.special_type != GemStat.SpecialType.NONE:
				valid_special_gem_infos.append(gem_info)
				print("SpecialDeleteState: keeping valid special gem: ", gem_info)
			else:
				print("SpecialDeleteState: skipping invalid/missing special gem at: ", position)
	
	# 更新当前特殊宝石信息列表
	current_special_gem_infos = valid_special_gem_infos
	
	if current_special_gem_infos.size() > 0:
		# 继续处理特殊宝石
		_process_special_gems(current_special_gem_infos)
	else:
		print("SpecialDeleteState: no valid special gems remaining, entering generation state")
		# 进入生成状态
		_cleanup_and_enter_generation_state()

## 清理数据并进入生成状态
func _cleanup_and_enter_generation_state() -> void:
	# 如果爆炸动画仍在播放，等待完成
	if game and game.special_delete_animator and game.special_delete_animator.has_active_explosion_animations():
		# 连接信号等待所有爆炸动画完成
		if not game.special_delete_animator.all_explosion_animations_finished.is_connected(_on_all_explosions_finished):
			game.special_delete_animator.all_explosion_animations_finished.connect(_on_all_explosions_finished, Object.CONNECT_ONE_SHOT)
		return
	
	# 如果闪电动画仍在播放，等待完成
	if _lightning_active:
		if game and game.special_delete_animator:
			# 修复：使用相同的闪电动画真实完成时间计算
			var lightning_play_duration: float = game.special_delete_animator.lightning_duration_sec
			var fade_duration: float = 0.25  # LightningLine的fade_duration_sec默认值
			var particle_lifetime: float = 0.5  # 从lightning_line.tscn中获取的粒子生命周期
			var total_lightning_duration: float = lightning_play_duration + fade_duration + particle_lifetime + 0.05  # 额外0.05秒缓冲
			var timer := get_tree().create_timer(total_lightning_duration)
			timer.timeout.connect(func() -> void:
				_lightning_active = false
				_cleanup_and_enter_generation_state()  # 递归调用
			, Object.CONNECT_ONE_SHOT)
			return
	
	# 清理所有相关数据
	if game:
		game.special_remove_infos.clear()
		game.special_gems_dict.clear()
		game.normal_gems_dict.clear()
		current_special_gem_infos.clear()
		game.recently_spawned_special_tiles.clear()

		# 进入生成状态
		game.state_machine.change_state(GameState.State.生成状态)

## 所有爆炸动画完成的回调函数
func _on_all_explosions_finished() -> void:
	# 递归调用，继续检查其他条件
	_cleanup_and_enter_generation_state()
# ==================== 回调函数 ====================
## 特殊瓦片删除完成回调
func _on_special_tiles_deleted(_tiles: Array) -> void:
	# 统计并更新UI显示
	if game and game.remove_info_statistics and pending_destroy_remove_infos.size() > 0:
		game.remove_info_statistics.add_remove_infos(pending_destroy_remove_infos)
		pending_destroy_remove_infos.clear()
	_check_continue_elimination()

# ==================== 兼容性函数 ====================
## 直接扫描当前网格收集特殊宝石信息（兜底方案，已废弃）
func _collect_current_special_gem_infos_by_grid() -> Array[Dictionary]:
	# 保留占位以兼容可能的外部调用
	return []

## 校正所有宝石位置（备用功能）
func _correct_gem_positions() -> void:
	if not game or not game.area or not game.area.game_grid:
		return
	
	# 收集位置不正确的宝石
	var misplaced_gems: Array[Dictionary] = []
	var gems_with_positions = game.area.game_grid.get_all_gems_with_positions()
	
	for gem_data in gems_with_positions:
		var gem: Gem = gem_data["gem"]
		var grid_position: Vector2i = gem_data["position"]
		
		if not is_instance_valid(gem):
			continue
		
		# 计算理想位置
		var intended_position: Vector2 = game.area.get_global_from_tile(grid_position) - Gem.HALF_GEM_SIZE
		var position_diff: Vector2 = gem.global_position - intended_position
		
		# 检查位置偏差
		if position_diff.length() > 1.0:
			misplaced_gems.append({
				"gem": gem,
				"target_position": intended_position
			})
	
	# 执行位置校正
	if misplaced_gems.size() > 0:
		_animate_gems_to_correct_positions(misplaced_gems)

## 移动宝石到正确位置
func _animate_gems_to_correct_positions(misplaced_gems: Array[Dictionary]) -> void:
	const CORRECTION_DURATION: float = 0.3
	
	for gem_data in misplaced_gems:
		var gem: Gem = gem_data["gem"]
		var target_position: Vector2 = gem_data["target_position"]
		
		if is_instance_valid(gem):
			gem.move_to_global_position(target_position, CORRECTION_DURATION, false, false)
