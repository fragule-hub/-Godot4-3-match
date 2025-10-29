extends Control
class_name RemoveStatistics

# 消除类型按钮
@onready var 三消: Button = %三消
@onready var 四消: Button = %四消
@onready var 五消: Button = %五消
@onready var 十字: Button = %十字
@onready var 大十字: Button = %大十字
@onready var 长连: Button = %长连
@onready var 摧毁: Button = %摧毁

# 颜色按钮
@onready var 红: Button = %红
@onready var 蓝: Button = %蓝
@onready var 黄: Button = %黄
@onready var 绿: Button = %绿
@onready var 白: Button = %白

# 统计数据源
var remove_info_statistics: RemoveInfoStatistics

# 消除类型按钮到枚举的映射
var type_button_map: Dictionary = {}
# 颜色按钮到枚举的映射
var color_button_map: Dictionary = {}
# 所有消除类型按钮
var type_buttons: Array[Button] = []
# 所有颜色按钮
var color_buttons: Array[Button] = []

# 当前选中的消除类型
var current_remove_type: RemoveInfo.RemoveType = RemoveInfo.RemoveType.MATCH_3
# 当前选中的颜色
var current_gem_color: GemStat.GemColor = GemStat.GemColor.RED

# 查询模式：true为按消除类型查询，false为按颜色查询
var query_by_type: bool = true

func _ready():
	_setup_button_mappings()
	_connect_signals()
	# 设置默认查询模式为按消除类型查询
	query_by_type = true
	current_remove_type = RemoveInfo.RemoveType.MATCH_3
	_update_display()

## 设置按钮映射关系
func _setup_button_mappings():
	# 消除类型按钮映射
	type_button_map = {
		三消: RemoveInfo.RemoveType.MATCH_3,
		四消: RemoveInfo.RemoveType.MATCH_4,
		五消: RemoveInfo.RemoveType.MATCH_5,
		十字: RemoveInfo.RemoveType.CROSS,
		大十字: RemoveInfo.RemoveType.BIG_CROSS,
		长连: RemoveInfo.RemoveType.LONG_CHAIN,
		摧毁: RemoveInfo.RemoveType.DESTROY,
	}
	
	# 颜色按钮映射
	color_button_map = {
		红: GemStat.GemColor.RED,
		蓝: GemStat.GemColor.BLUE,
		黄: GemStat.GemColor.YELLOW,
		绿: GemStat.GemColor.GREEN,
		白: GemStat.GemColor.WHITE
	}
	
	# 收集所有按钮
	type_buttons = [三消, 四消, 五消, 十字, 大十字, 长连]
	color_buttons = [红, 蓝, 黄, 绿, 白]

## 连接按钮信号
func _connect_signals():
	# 连接消除类型按钮
	for button in type_button_map.keys():
		button.pressed.connect(_on_type_button_pressed.bind(button))
	
	# 连接颜色按钮
	for button in color_button_map.keys():
		button.pressed.connect(_on_color_button_pressed.bind(button))

## 消除类型按钮点击处理
func _on_type_button_pressed(button: Button):
	print("消除类型按钮点击")
	if button in type_button_map:
		current_remove_type = type_button_map[button]
		query_by_type = true
		_update_display()

## 颜色按钮点击处理
func _on_color_button_pressed(button: Button):
	print("颜色类型按钮点击")
	if button in color_button_map:
		current_gem_color = color_button_map[button]
		query_by_type = false
		_update_display()

## 更新显示
func _update_display():
	print("更新显示")
	if query_by_type:
		_update_display_by_type()
	else:
		_update_display_by_color()

## 按消除类型查询模式更新显示
func _update_display_by_type():
	_update_type_buttons_total()
	_update_color_buttons_by_type()

## 按颜色查询模式更新显示
func _update_display_by_color():
	_update_color_buttons_total()
	_update_type_buttons_by_color()

## 更新消除类型按钮显示（显示总消除次数）
func _update_type_buttons_total():
	if not remove_info_statistics:
		# 如果没有统计数据，显示默认文本
		for button in type_button_map.keys():
			var type_name = _get_type_name(type_button_map[button])
			button.text = "%s: 0" % type_name
		return
	
	# 更新每个消除类型按钮的文本
	for button in type_button_map.keys():
		var remove_type = type_button_map[button]
		var count = remove_info_statistics.get_count_by_type(remove_type)
		var type_name = _get_type_name(remove_type)
		button.text = "%s: %d" % [type_name, count]

## 更新颜色按钮显示（按当前选中的消除类型）
func _update_color_buttons_by_type():
	if not remove_info_statistics:
		# 如果没有统计数据，显示默认文本
		for button in color_button_map.keys():
			var color_name = _get_color_name(color_button_map[button])
			button.text = "%s: 0" % color_name
		return
	
	# 更新每个颜色按钮的文本，显示当前选中消除类型的各颜色消除次数
	for button in color_button_map.keys():
		var gem_color = color_button_map[button]
		# DESTROY 类型显示被摧毁的宝石数量，其它类型显示次数
		var count := 0
		if current_remove_type == RemoveInfo.RemoveType.DESTROY:
			count = remove_info_statistics.get_gems_by_color_and_type(gem_color, current_remove_type)
		else:
			count = remove_info_statistics.get_count_by_color_and_type(gem_color, current_remove_type)
		var color_name = _get_color_name(gem_color)
		button.text = "%s: %d" % [color_name, count]

## 更新颜色按钮显示（显示总消除次数）
func _update_color_buttons_total():
	if not remove_info_statistics:
		# 如果没有统计数据，显示默认文本
		for button in color_button_map.keys():
			var color_name = _get_color_name(color_button_map[button])
			button.text = "%s: 0" % color_name
		return
	
	# 更新每个颜色按钮的文本
	for button in color_button_map.keys():
		var gem_color = color_button_map[button]
		var count = remove_info_statistics.get_count_by_color(gem_color)
		var color_name = _get_color_name(gem_color)
		button.text = "%s: %d" % [color_name, count]

## 更新消除类型按钮显示（按当前选中的颜色）
func _update_type_buttons_by_color():
	if not remove_info_statistics:
		# 如果没有统计数据，显示默认文本
		for button in type_button_map.keys():
			var type_name = _get_type_name(type_button_map[button])
			button.text = "%s: 0" % type_name
		return
	
	# 更新每个消除类型按钮的文本，显示当前选中颜色的各消除类型消除次数
	for button in type_button_map.keys():
		var remove_type = type_button_map[button]
		# DESTROY 类型显示被摧毁的宝石数量，其它类型显示次数
		var count := 0
		if remove_type == RemoveInfo.RemoveType.DESTROY:
			count = remove_info_statistics.get_gems_by_color_and_type(current_gem_color, remove_type)
		else:
			count = remove_info_statistics.get_count_by_color_and_type(current_gem_color, remove_type)
		var type_name = _get_type_name(remove_type)
		button.text = "%s: %d" % [type_name, count]

## 获取消除类型的中文名称
func _get_type_name(remove_type: RemoveInfo.RemoveType) -> String:
	match remove_type:
		RemoveInfo.RemoveType.MATCH_3:
			return "三消"
		RemoveInfo.RemoveType.MATCH_4:
			return "四消"
		RemoveInfo.RemoveType.MATCH_5:
			return "五消"
		RemoveInfo.RemoveType.CROSS:
			return "十字"
		RemoveInfo.RemoveType.BIG_CROSS:
			return "大十字"
		RemoveInfo.RemoveType.LONG_CHAIN:
			return "长连"
		RemoveInfo.RemoveType.DESTROY:
			return "摧毁"
		_:
			return "未知"

## 获取颜色的中文名称
func _get_color_name(gem_color: GemStat.GemColor) -> String:
	match gem_color:
		GemStat.GemColor.RED:
			return "红"
		GemStat.GemColor.BLUE:
			return "蓝"
		GemStat.GemColor.YELLOW:
			return "黄"
		GemStat.GemColor.GREEN:
			return "绿"
		GemStat.GemColor.WHITE:
			return "白"
		_:
			return "未知"

## 设置统计数据源
func set_remove_info_statistics(statistics: RemoveInfoStatistics):
	# 断开旧统计对象的信号连接（如有）
	if remove_info_statistics:
		remove_info_statistics.stats_updated.disconnect(Callable(self, "_on_stats_updated"))
	# 设置新统计对象并连接信号
	remove_info_statistics = statistics
	if remove_info_statistics:
		remove_info_statistics.stats_updated.connect(Callable(self, "_on_stats_updated"))
	_update_display()

## 刷新显示（外部调用）
func refresh_display():
	_update_display()

## 统计更新信号回调
func _on_stats_updated():
	_update_display()
