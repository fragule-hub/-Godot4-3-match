extends Node
class_name RemoveInfoCalculator

## 消除信息计算器
## 负责将匹配的宝石位置转换为详细的消除信息，包括消除类型识别和优先级处理

## 将匹配的宝石位置转换为RemoveInfo数组
## 算法优先级：十字消除 > 线性消除 > 零散消除
## @param all_matches: 匹配的宝石字典，键为Vector2i位置，值为Gem对象
## @return: RemoveInfo数组，包含所有消除操作的详细信息
func calculate(all_matches: Dictionary) -> Array[RemoveInfo]:
	var remove_infos: Array[RemoveInfo] = []
	if all_matches.is_empty():
		return remove_infos
	
	# 按颜色分组收集宝石位置
	# color -> { tiles: Array[Vector2i], position_map: Dictionary(Vector2i -> true) }
	var color_groups: Dictionary = {}
	for position in all_matches.keys():
		var gem = all_matches[position]
		if gem == null or gem._gem_stat == null:
			continue
		var gem_color = gem._gem_stat.color
		if not color_groups.has(gem_color):
			color_groups[gem_color] = {"tiles": [], "position_map": {}}
		color_groups[gem_color].tiles.append(position)
		color_groups[gem_color].position_map[position] = true
	
	# 记录已处理的位置，避免重复计算
	var processed_tiles: Dictionary = {}
	
	# 按颜色逐一识别消除模式
	for gem_color in color_groups.keys():
		var color_group: Dictionary = color_groups[gem_color]
		var color_tiles: Array[Vector2i] = []
		color_tiles.assign(color_group["tiles"])
		
		# 收集水平和垂直方向的连线（长度>=3）
		var row_positions: Dictionary = {}  # y坐标 -> x坐标数组
		var col_positions: Dictionary = {}  # x坐标 -> y坐标数组
		
		for tile in color_tiles:
			# 收集同行的x坐标
			var row_x_coords: Array = row_positions.get(tile.y, [])
			if not row_positions.has(tile.y):
				row_positions[tile.y] = row_x_coords
			row_x_coords.append(tile.x)
			row_positions[tile.y] = row_x_coords
			
			# 收集同列的y坐标
			var col_y_coords: Array = col_positions.get(tile.x, [])
			if not col_positions.has(tile.x):
				col_positions[tile.x] = col_y_coords
			col_y_coords.append(tile.y)
			col_positions[tile.x] = col_y_coords
			
		var horizontal_segments: Array = _build_horizontal_segments(row_positions)
		var vertical_segments: Array = _build_vertical_segments(col_positions)
		
		# 第一步：识别十字消除（水平和垂直线段的交点）
		for horizontal_seg in horizontal_segments:
			var row_y: int = int(horizontal_seg["y"])
			var row_x_coords: Array = horizontal_seg["xs"]
			var horizontal_tiles: Array[Vector2i] = []
			horizontal_tiles.assign(horizontal_seg["tiles"])
			var horizontal_length: int = horizontal_tiles.size()
			
			for vertical_seg in vertical_segments:
				var col_x: int = int(vertical_seg["x"])
				var col_y_coords: Array = vertical_seg["ys"]
				var vertical_tiles: Array[Vector2i] = []
				vertical_tiles.assign(vertical_seg["tiles"])
				var vertical_length: int = vertical_tiles.size()
				
				# 检查是否存在交点（col_x, row_y）
				if row_x_coords.has(col_x) and col_y_coords.has(row_y):
					var cross_center := Vector2i(col_x, row_y)
					
					# 合并水平和垂直线段的所有位置
					var cross_tiles: Array[Vector2i] = []
					for tile in horizontal_tiles:
						if not cross_tiles.has(tile):
							cross_tiles.append(tile)
					for tile in vertical_tiles:
						if not cross_tiles.has(tile):
							cross_tiles.append(tile)
					
					# 检查是否有未处理的位置
					var has_unprocessed := false
					for tile in cross_tiles:
						if not processed_tiles.has(tile):
							has_unprocessed = true
							break
					if not has_unprocessed:
						continue
					
					# 创建十字消除信息
					var other_positions: Array[Vector2i] = []
					for tile in cross_tiles:
						if tile != cross_center:
							other_positions.append(tile)
					
					# 标记所有位置为已处理
					processed_tiles[cross_center] = true
					for tile in other_positions:
						processed_tiles[tile] = true
					
					# 确定十字类型（普通十字或大十字）
					var cross_type := RemoveInfo.RemoveType.CROSS
					if horizontal_length >= 4 or vertical_length >= 4:
						cross_type = RemoveInfo.RemoveType.BIG_CROSS
					
					var total_count := 1 + other_positions.size()
					var cross_info := RemoveInfo.new(gem_color, cross_type, total_count, RemoveInfo.CauseType.CASCADE, cross_center, other_positions)
					remove_infos.append(cross_info)
		
		# 第二步：处理剩余未处理的位置，生成线段消除
		var remaining_row_positions: Dictionary = {}
		for tile in color_tiles:
			if processed_tiles.has(tile):
				continue
			var row_x_coords: Array = remaining_row_positions.get(tile.y, [])
			if not remaining_row_positions.has(tile.y):
				remaining_row_positions[tile.y] = row_x_coords
			row_x_coords.append(tile.x)
			remaining_row_positions[tile.y] = row_x_coords
			
		var remaining_horizontal_segments: Array = _build_horizontal_segments(remaining_row_positions)
		for horizontal_segment in remaining_horizontal_segments:
			var segment_tiles: Array[Vector2i] = []
			segment_tiles.assign(horizontal_segment["tiles"])
			_emit_segment(remove_infos, segment_tiles, gem_color, processed_tiles, true)
			
		var remaining_col_positions: Dictionary = {}
		for tile in color_tiles:
			if processed_tiles.has(tile):
				continue
			var col_y_coords: Array = remaining_col_positions.get(tile.x, [])
			if not remaining_col_positions.has(tile.x):
				remaining_col_positions[tile.x] = col_y_coords
			col_y_coords.append(tile.y)
			remaining_col_positions[tile.x] = col_y_coords
			
		var remaining_vertical_segments: Array = _build_vertical_segments(remaining_col_positions)
		for vertical_segment in remaining_vertical_segments:
			var segment_tiles: Array[Vector2i] = []
			segment_tiles.assign(vertical_segment["tiles"])
			_emit_segment(remove_infos, segment_tiles, gem_color, processed_tiles, false)
	
	# 第三步：处理剩余的零散位置（单独的宝石）
	for position in all_matches.keys():
		if not processed_tiles.has(position):
			var gem = all_matches[position]
			var gem_color = gem._gem_stat.color if (gem and gem._gem_stat) else GemStat.GemColor.OTHER
			var destroy_info := RemoveInfo.new(gem_color, RemoveInfo.RemoveType.DESTROY, 1, RemoveInfo.CauseType.CASCADE, position, [])
			remove_infos.append(destroy_info)
			processed_tiles[position] = true
	
	return remove_infos

## 收集经过指定中心点的水平或垂直线段
## @param center: 中心点位置
## @param tile_membership: 位置成员字典
## @param is_horizontal: 是否为水平方向
## @return: 排序后的线段位置数组
func _collect_line_through(center: Vector2i, tile_membership: Dictionary, is_horizontal: bool) -> Array[Vector2i]:
	var line_tiles: Array[Vector2i] = [center]
	
	if is_horizontal:
		# 向左扩展
		var left_x := center.x - 1
		while tile_membership.has(Vector2i(left_x, center.y)):
			line_tiles.append(Vector2i(left_x, center.y))
			left_x -= 1
		# 向右扩展
		var right_x := center.x + 1
		while tile_membership.has(Vector2i(right_x, center.y)):
			line_tiles.append(Vector2i(right_x, center.y))
			right_x += 1
		# 按x坐标升序排列
		line_tiles = _sort_by_x(line_tiles)
	else:
		# 向上扩展
		var up_y := center.y - 1
		while tile_membership.has(Vector2i(center.x, up_y)):
			line_tiles.append(Vector2i(center.x, up_y))
			up_y -= 1
		# 向下扩展
		var down_y := center.y + 1
		while tile_membership.has(Vector2i(center.x, down_y)):
			line_tiles.append(Vector2i(center.x, down_y))
			down_y += 1
		# 按y坐标升序排列
		line_tiles = _sort_by_y(line_tiles)
	
	return line_tiles

## 生成线段消除信息并标记位置为已处理
## @param remove_infos: 消除信息数组
## @param segment_tiles: 线段包含的位置
## @param gem_color: 宝石颜色
## @param processed_tiles: 已处理位置字典
## @param is_horizontal: 是否为水平线段
func _emit_segment(remove_infos: Array[RemoveInfo], segment_tiles: Array[Vector2i], gem_color: GemStat.GemColor, processed_tiles: Dictionary, is_horizontal: bool) -> void:
	# 排序确定中心位置
	segment_tiles = _sort_by_x(segment_tiles) if is_horizontal else _sort_by_y(segment_tiles)
	var segment_length := segment_tiles.size()
	var center_index := int(floor(float(segment_length - 1) / 2.0))
	var segment_center: Vector2i = segment_tiles[center_index]
	
	# 收集除中心外的其他位置
	var other_positions: Array[Vector2i] = []
	for i in range(segment_length):
		var tile: Vector2i = segment_tiles[i]
		if tile != segment_center:
			other_positions.append(tile)
	
	# 根据长度确定消除类型
	var segment_type := RemoveInfo.RemoveType.MATCH_3
	if segment_length >= 6:
		segment_type = RemoveInfo.RemoveType.LONG_CHAIN
	elif segment_length == 5:
		segment_type = RemoveInfo.RemoveType.MATCH_5
	elif segment_length == 4:
		segment_type = RemoveInfo.RemoveType.MATCH_4
	
	# 标记所有位置为已处理
	processed_tiles[segment_center] = true
	for tile in other_positions:
		processed_tiles[tile] = true
	
	# 创建并添加消除信息
	var total_count := 1 + other_positions.size()
	var segment_info := RemoveInfo.new(gem_color, segment_type, total_count, RemoveInfo.CauseType.CASCADE, segment_center, other_positions)
	remove_infos.append(segment_info)

## 按x坐标升序排序位置数组
## @param positions: 位置数组
## @return: 排序后的新数组
func _sort_by_x(positions: Array[Vector2i]) -> Array[Vector2i]:
	var sorted_positions := positions.duplicate()
	sorted_positions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	return sorted_positions

## 按y坐标升序排序位置数组
## @param positions: 位置数组
## @return: 排序后的新数组
func _sort_by_y(positions: Array[Vector2i]) -> Array[Vector2i]:
	var sorted_positions := positions.duplicate()
	sorted_positions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	return sorted_positions

## 构建水平线段（每行识别连续的x坐标段，长度>=3）
## @param row_positions: 按行分组的位置字典 {y: [x1, x2, ...]}
## @return: 水平线段数组，每个线段为Vector2i数组
func _build_horizontal_segments(row_positions: Dictionary) -> Array:
	var horizontal_segments: Array = []
	
	for row_y in row_positions.keys():
		var x_coordinates: Array = row_positions[row_y]
		x_coordinates.sort()
		
		var current_segment: Array = []
		var previous_x: int = 0
		var has_previous := false
		for x_coord in x_coordinates:
			var current_x: int = int(x_coord)
			if not has_previous:
				current_segment.append(current_x)
				previous_x = current_x
				has_previous = true
			elif current_x == previous_x + 1:
				# 连续的x坐标，添加到当前线段
				current_segment.append(current_x)
				previous_x = current_x
			else:
				# 不连续，检查当前线段是否足够长
				if current_segment.size() >= 3:
					var segment_tiles: Array[Vector2i] = []
					for x_pos in current_segment:
						segment_tiles.append(Vector2i(x_pos, int(row_y)))
					horizontal_segments.append({"y": int(row_y), "xs": current_segment.duplicate(), "tiles": segment_tiles})
				# 开始新线段
				current_segment = [current_x]
				previous_x = current_x
		
		# 处理最后一个线段
		if current_segment.size() >= 3:
			var final_segment_tiles: Array[Vector2i] = []
			for x_pos in current_segment:
				final_segment_tiles.append(Vector2i(x_pos, int(row_y)))
			horizontal_segments.append({"y": int(row_y), "xs": current_segment.duplicate(), "tiles": final_segment_tiles})
	
	return horizontal_segments

## 构建垂直线段（每列识别连续的y坐标段，长度>=3）
## @param col_positions: 按列分组的位置字典 {x: [y1, y2, ...]}
## @return: 垂直线段数组，每个线段为Vector2i数组
func _build_vertical_segments(col_positions: Dictionary) -> Array:
	var vertical_segments: Array = []
	
	for col_x in col_positions.keys():
		var y_coordinates: Array = col_positions[col_x]
		y_coordinates.sort()
		
		var current_segment: Array = []
		var previous_y: int = 0
		var has_previous := false
		
		for y_coord in y_coordinates:
			var current_y: int = int(y_coord)
			if not has_previous:
				current_segment.append(current_y)
				previous_y = current_y
				has_previous = true
			elif current_y == previous_y + 1:
				# 连续的y坐标，添加到当前线段
				current_segment.append(current_y)
				previous_y = current_y
			else:
				# 不连续，检查当前线段是否足够长
				if current_segment.size() >= 3:
					var segment_tiles: Array[Vector2i] = []
					for y_pos in current_segment:
						segment_tiles.append(Vector2i(int(col_x), y_pos))
					vertical_segments.append({"x": int(col_x), "ys": current_segment.duplicate(), "tiles": segment_tiles})
				# 开始新线段
				current_segment = [current_y]
				previous_y = current_y
		
		# 处理最后一个线段
		if current_segment.size() >= 3:
			var final_segment_tiles: Array[Vector2i] = []
			for y_pos in current_segment:
				final_segment_tiles.append(Vector2i(int(col_x), y_pos))
			vertical_segments.append({"x": int(col_x), "ys": current_segment.duplicate(), "tiles": final_segment_tiles})
	
	return vertical_segments


## 标记交换操作：将指定位置设为中心并更新消除原因为交换
## 如果指定位置在消除信息中，将其设为中心位置并标记为交换触发
## @param swap_tile: 交换操作的位置
## @param remove_infos: 消除信息数组
## @return: 更新后的消除信息数组
func mark_swap_for_tile(swap_tile: Vector2i, remove_infos: Array[RemoveInfo]) -> Array[RemoveInfo]:
	if remove_infos == null:
		return []
	
	for remove_info in remove_infos:
		if remove_info == null:
			continue
		
		# 如果交换位置已经是中心，只需标记为交换触发
		if remove_info.center_tile == swap_tile:
			remove_info.cause_type = RemoveInfo.CauseType.SWAP
			continue
		
		# 检查交换位置是否在其他位置中
		var target_index: int = -1
		for i in range(remove_info.other_tiles.size()):
			if remove_info.other_tiles[i] == swap_tile:
				target_index = i
				break
		
		# 如果找到，将交换位置设为新中心
		if target_index != -1:
			remove_info.cause_type = RemoveInfo.CauseType.SWAP
			var original_center: Vector2i = remove_info.center_tile
			remove_info.center_tile = swap_tile
			
			# 从其他位置中移除新中心
			remove_info.other_tiles.remove_at(target_index)
			
			# 将原中心添加到其他位置（避免重复）
			var center_already_exists := false
			for tile in remove_info.other_tiles:
				if tile == original_center:
					center_already_exists = true
					break
			
			if not center_already_exists and original_center != remove_info.center_tile:
				remove_info.other_tiles.append(original_center)
	
	# 返回更新后的消除信息数组
	return remove_infos
