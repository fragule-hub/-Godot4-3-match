extends RefCounted
class_name RemoveInfoStatistics

signal stats_updated

## RemoveInfo统计数据管理器
## 提供双向映射功能：通过消除类型查询颜色统计，通过颜色查询消除类型统计

## 颜色统计数据结构
class ColorStats:
	var total_count: int = 0        # 该颜色的总消除次数
	var total_gems: int = 0         # 该颜色的总消除宝石数
	var type_breakdown: Dictionary = {} # RemoveType -> {count: int, gems: int}
	
	func _init():
		type_breakdown = {}

## 消除类型统计数据结构
class TypeStats:
	var total_count: int = 0        # 该类型的总消除次数
	var total_gems: int = 0         # 该类型的总消除宝石数
	var color_breakdown: Dictionary = {} # GemColor -> {count: int, gems: int}
	
	func _init():
		color_breakdown = {}

# 主要统计数据存储
var stats_by_color: Dictionary = {}  # GemColor -> ColorStats
var stats_by_type: Dictionary = {}   # RemoveType -> TypeStats

## 初始化统计数据
func _init():
	clear()

## 清空所有统计数据
func clear() -> void:
	stats_by_color.clear()
	stats_by_type.clear()
	
	# 初始化所有颜色的统计
	for color in GemStat.GemColor.values():
		stats_by_color[color] = ColorStats.new()
	
	# 初始化所有消除类型的统计
	for remove_type in RemoveInfo.RemoveType.values():
		stats_by_type[remove_type] = TypeStats.new()

	# 清空后发射更新信号
	stats_updated.emit()

## 批量添加RemoveInfo数据
## @param remove_infos: RemoveInfo数组
func add_remove_infos(remove_infos: Array[RemoveInfo]) -> void:
	for remove_info in remove_infos:
		if remove_info != null:
			add_remove_info(remove_info)
	# 批量添加完成后发射一次更新信号
	stats_updated.emit()

## 添加单个RemoveInfo数据
## @param remove_info: 要添加的RemoveInfo
func add_remove_info(remove_info: RemoveInfo) -> void:
	if remove_info == null:
		return
	
	var gem_color = remove_info.color
	var remove_type = remove_info.remove_type
	var gem_count = remove_info.gem_count
	
	# 确保统计数据结构存在
	if not stats_by_color.has(gem_color):
		stats_by_color[gem_color] = ColorStats.new()
	if not stats_by_type.has(remove_type):
		stats_by_type[remove_type] = TypeStats.new()
	
	# 更新颜色统计
	var color_stats: ColorStats = stats_by_color[gem_color]
	color_stats.total_count += 1
	color_stats.total_gems += gem_count
	
	if not color_stats.type_breakdown.has(remove_type):
		color_stats.type_breakdown[remove_type] = {"count": 0, "gems": 0}
	color_stats.type_breakdown[remove_type]["count"] += 1
	color_stats.type_breakdown[remove_type]["gems"] += gem_count
	
	# 更新类型统计
	var type_stats: TypeStats = stats_by_type[remove_type]
	type_stats.total_count += 1
	type_stats.total_gems += gem_count
	
	if not type_stats.color_breakdown.has(gem_color):
		type_stats.color_breakdown[gem_color] = {"count": 0, "gems": 0}
	type_stats.color_breakdown[gem_color]["count"] += 1
	type_stats.color_breakdown[gem_color]["gems"] += gem_count

	# 单项添加后发射更新信号
	stats_updated.emit()

## 按颜色查询总消除次数
## @param gem_color: 宝石颜色
## @return: 该颜色的总消除次数
func get_count_by_color(gem_color: GemStat.GemColor) -> int:
	if stats_by_color.has(gem_color):
		return stats_by_color[gem_color].total_count
	return 0

## 按颜色查询总消除宝石数
## @param gem_color: 宝石颜色
## @return: 该颜色的总消除宝石数
func get_gems_by_color(gem_color: GemStat.GemColor) -> int:
	if stats_by_color.has(gem_color):
		return stats_by_color[gem_color].total_gems
	return 0

## 按颜色查询各消除类型的详细统计
## @param gem_color: 宝石颜色
## @return: 消除类型统计字典 {RemoveType: {count: int, gems: int}}
func get_types_for_color(gem_color: GemStat.GemColor) -> Dictionary:
	if stats_by_color.has(gem_color):
		return stats_by_color[gem_color].type_breakdown.duplicate()
	return {}

## 按消除类型查询总消除次数
## @param remove_type: 消除类型
## @return: 该类型的总消除次数
func get_count_by_type(remove_type: RemoveInfo.RemoveType) -> int:
	if stats_by_type.has(remove_type):
		return stats_by_type[remove_type].total_count
	return 0

## 按消除类型查询总消除宝石数
## @param remove_type: 消除类型
## @return: 该类型的总消除宝石数
func get_gems_by_type(remove_type: RemoveInfo.RemoveType) -> int:
	if stats_by_type.has(remove_type):
		return stats_by_type[remove_type].total_gems
	return 0

## 按消除类型查询各颜色的详细统计
## @param remove_type: 消除类型
## @return: 颜色统计字典 {GemColor: {count: int, gems: int}}
func get_colors_for_type(remove_type: RemoveInfo.RemoveType) -> Dictionary:
	if stats_by_type.has(remove_type):
		return stats_by_type[remove_type].color_breakdown.duplicate()
	return {}

## 交叉查询：特定颜色和类型的消除次数
## @param gem_color: 宝石颜色
## @param remove_type: 消除类型
## @return: 该颜色该类型的消除次数
func get_count_by_color_and_type(gem_color: GemStat.GemColor, remove_type: RemoveInfo.RemoveType) -> int:
	if stats_by_color.has(gem_color):
		var color_stats: ColorStats = stats_by_color[gem_color]
		if color_stats.type_breakdown.has(remove_type):
			return color_stats.type_breakdown[remove_type]["count"]
	return 0

## 交叉查询：特定颜色和类型的消除宝石数
## @param gem_color: 宝石颜色
## @param remove_type: 消除类型
## @return: 该颜色该类型的消除宝石数
func get_gems_by_color_and_type(gem_color: GemStat.GemColor, remove_type: RemoveInfo.RemoveType) -> int:
	if stats_by_color.has(gem_color):
		var color_stats: ColorStats = stats_by_color[gem_color]
		if color_stats.type_breakdown.has(remove_type):
			return color_stats.type_breakdown[remove_type]["gems"]
	return 0

## 获取所有统计数据的摘要
## @return: 包含所有统计信息的字典
func get_summary() -> Dictionary:
	var summary = {
		"total_removes": 0,
		"total_gems": 0,
		"by_color": {},
		"by_type": {}
	}
	
	# 统计总数
	for color in stats_by_color.keys():
		var color_stats: ColorStats = stats_by_color[color]
		summary["total_removes"] += color_stats.total_count
		summary["total_gems"] += color_stats.total_gems
		
		if color_stats.total_count > 0:
			summary["by_color"][color] = {
				"count": color_stats.total_count,
				"gems": color_stats.total_gems,
				"types": color_stats.type_breakdown.duplicate()
			}
	
	# 按类型统计
	for remove_type in stats_by_type.keys():
		var type_stats: TypeStats = stats_by_type[remove_type]
		if type_stats.total_count > 0:
			summary["by_type"][remove_type] = {
				"count": type_stats.total_count,
				"gems": type_stats.total_gems,
				"colors": type_stats.color_breakdown.duplicate()
			}
	
	return summary

## 获取最活跃的颜色（消除次数最多）
## @return: 消除次数最多的颜色
func get_most_active_color() -> GemStat.GemColor:
	var max_count = 0
	var most_active_color = GemStat.GemColor.OTHER
	
	for color in stats_by_color.keys():
		var count = stats_by_color[color].total_count
		if count > max_count:
			max_count = count
			most_active_color = color
	
	return most_active_color

## 获取最活跃的消除类型（消除次数最多）
## @return: 消除次数最多的类型
func get_most_active_type() -> RemoveInfo.RemoveType:
	var max_count = 0
	var most_active_type = RemoveInfo.RemoveType.MATCH_3
	
	for remove_type in stats_by_type.keys():
		var count = stats_by_type[remove_type].total_count
		if count > max_count:
			max_count = count
			most_active_type = remove_type
	
	return most_active_type

## 获取统计信息的可读字符串表示
## @return: 统计信息的字符串表示
func get_statistics_string() -> String:
	var result = "RemoveInfo Statistics:\n"
	var summary = get_summary()
	
	result += "Total Removes: %d, Total Gems: %d\n" % [summary["total_removes"], summary["total_gems"]]
	
	result += "\nBy Color:\n"
	for color in summary["by_color"].keys():
		var color_data = summary["by_color"][color]
		result += "  %s: %d removes, %d gems\n" % [GemStat.GemColor.keys()[color], color_data["count"], color_data["gems"]]
	
	result += "\nBy Type:\n"
	for remove_type in summary["by_type"].keys():
		var type_data = summary["by_type"][remove_type]
		result += "  %s: %d removes, %d gems\n" % [RemoveInfo.RemoveType.keys()[remove_type], type_data["count"], type_data["gems"]]
	
	return result
