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

var swap_queue: Array = []
var pending_move_infos: Array[MoveInfo] = []

func _ready() -> void:
	_initialize_game()
	_initialize_state_machine()
	_connect_inputs()

func _initialize_game() -> void:
	gem_spawner.spawn_gems_batch( game_calculator.generate_safe_initial_spawn_batch( gems ) )

func _initialize_state_machine() -> void:
	if state_machine:
		state_machine.initialize(self)
		state_machine.state_changed.connect(_on_state_changed)
	else:
		push_error("警告：未找到状态机节点")

func _connect_inputs() -> void:
	if grid_hover:
		grid_hover.tile_swap_requested.connect(_on_tile_swap_requested)
	# 连接统一的动画完成信号
	if gem_swap:
		gem_swap.swap_animation_completed.connect(_on_swap_animation_completed)

func _on_state_changed(from_state: GameState, to_state: GameState) -> void:
	print( GameState.state_to_string(from_state.state) + " -> " + GameState.state_to_string(to_state.state) )

# =================== 交换队列与请求接入 ===================

func _on_tile_swap_requested(from_tile: Vector2i, to_tile: Vector2i) -> void:
	print("接收到交换请求")
	if not area or not gem_swap or not game_calculator:
		return
	if not area.game_grid._is_valid_position(from_tile) or not area.game_grid._is_valid_position(to_tile):
		return

	# 直接播放预交换动画
	if game_calculator._would_create_match_after_swap(from_tile, to_tile):
		gem_swap.play_pre_swap_animation(from_tile, to_tile)

# 统一的动画完成处理
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
