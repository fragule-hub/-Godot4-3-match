# 主场景控制器：负责初始化、状态机接入、输入接入与统一动画回调
extends Node2D
class_name Arena

@onready var state_machine: GameStateMachine = $GameStateMachine

@export var gems: Array[GemStat]

@onready var area: GameArea = $GameArea
@onready var grid_hover: GridHover = $GridHover
@onready var gem_spawner: GemSpawner = $GemSpawner
@onready var game_calculator: GameCalculator = $GameCalculator
@onready var gem_swap: GemSwap = $GemSwap
@onready var gem_delete: GemDelete = $GemDelete
@onready var falldown_calculator: FallDownCalculator = $FallDownCalculator
@onready var falldown_animator: FallDownAnimator = $FallDownAnimator
@onready var remove_info_calculator: RemoveInfoCalculator = $RemoveInfoCalculator
@onready var special_spawner: SpecialSpawner = $SpecialSpawner
@onready var special_delete: SpecialDelete = $SpecialDelete
@onready var special_delete_animator: SpecialDeleteAnimator = $SpecialDeleteAnimator

@onready var remove_statistics: RemoveStatistics = $Visuals/RemoveStatistics


# 本局游戏的移除信息统计
var remove_info_statistics: RemoveInfoStatistics

# 当前交换操作的位置数组（用于标记移除信息）[from_tile, to_tile]
var current_swap_tiles: Array[Vector2i] = []

# 匹配状态计算出的数据，供消除状态使用
var current_matches: Dictionary = {}
var current_remove_infos: Array[RemoveInfo] = []

# 新的状态机流程数据
var special_gems_dict: Dictionary = {}      # 字典1：特殊宝石字典
var normal_gems_dict: Dictionary = {}       # 字典2：非特殊宝石字典
var special_remove_infos: Array[RemoveInfo] = []  # 数组1：需要特殊生成的RemoveInfo
var other_remove_infos: Array[RemoveInfo] = []    # 数组2：普通删除的RemoveInfo

# 当前轮可供特殊消除驱动的特殊宝石信息（position + special_type）
var special_gem_infos: Array[Dictionary] = []

# 本轮刚生成的特殊宝石中心位置（用于在随后的特殊消除阶段排除）
var recently_spawned_special_tiles: Array[Vector2i] = []

var swap_queue: Array = []
var pending_move_infos: Array[MoveInfo] = []

func _ready() -> void:
	_initialize_game()
	_initialize_state_machine()
	_connect_inputs()

# 生成无三连的初始网格并放置到 GameGrid
func _initialize_game() -> void:
	# 创建本局游戏的移除信息统计实例
	remove_info_statistics = RemoveInfoStatistics.new()
	
	# 将统计数据传递给UI组件
	if remove_statistics:
		remove_statistics.set_remove_info_statistics(remove_info_statistics)
	
	gem_spawner.spawn_gems_batch( game_calculator.generate_safe_initial_spawn_batch( gems ) )

# 初始化状态机并连接状态变更日志
func _initialize_state_machine() -> void:
	if state_machine:
		state_machine.initialize(self)
		state_machine.state_changed.connect(_on_state_changed)
	else:
		push_error("警告：未找到状态机节点")

# 连接输入与动画事件
func _connect_inputs() -> void:
	if grid_hover:
		grid_hover.tile_swap_requested.connect(_on_tile_swap_requested)
	# 连接统一的动画完成信号
	if gem_swap:
		gem_swap.swap_animation_completed.connect(_on_swap_animation_completed)

func _on_state_changed(from_state: GameState, to_state: GameState) -> void:
	print( GameState.state_to_string(from_state.state) + " -> " + GameState.state_to_string(to_state.state) )

# =================== 交换队列与请求接入 ===================

# 接收 GridHover 的交换请求；若预判会形成匹配则播放预交换动画
func _on_tile_swap_requested(from_tile: Vector2i, to_tile: Vector2i) -> void:
	print("接收到交换请求")
	if not area or not gem_swap or not game_calculator:
		return
	if not area.game_grid._is_valid_position(from_tile) or not area.game_grid._is_valid_position(to_tile):
		return

	# 直接播放预交换动画（不改网格），供状态机后续处理
	if game_calculator._would_create_match_after_swap(from_tile, to_tile):
		gem_swap.play_pre_swap_animation(from_tile, to_tile)

# 统一的动画完成处理：预动画结束后入队并触发状态切换
func _on_swap_animation_completed(from_tile: Vector2i, to_tile: Vector2i, anim_type: GemSwap.SwapAnimType) -> void:
	match anim_type:
		GemSwap.SwapAnimType.PRE_SWAP:
			# 预动画完成，将请求入队并尝试切换状态
			swap_queue.append({"from": from_tile, "to": to_tile})
			if state_machine and state_machine.get_current_state_type() == GameState.State.基础状态:
				state_machine.change_state(GameState.State.交换状态)
		GemSwap.SwapAnimType.REVERSE_SWAP:
			# 反动画完成，由状态机处理后续逻辑
			pass

func has_swap_requests() -> bool:
	return swap_queue.size() > 0

func dequeue_swap_request() -> Dictionary:
	if swap_queue.is_empty():
		return {}
	var req: Dictionary = swap_queue[0]
	swap_queue.remove_at(0)
	return req
