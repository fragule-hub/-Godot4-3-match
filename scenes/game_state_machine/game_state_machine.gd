extends Node
class_name GameStateMachine

signal state_changed(from_state: GameState, to_state: GameState)

var current_state: GameState
var states: Dictionary = {}

var game: Arena

var is_initialized: bool = false

func _ready() -> void:
	pass

# 由舞台调用的初始化方法
func initialize(game_ref: Arena) -> void:
	if is_initialized:
		return
	
	game = game_ref
	_discover_and_register_states()
	is_initialized = true
	
	# 设置初始状态为基础状态
	change_state(GameState.State.基础状态)

func _discover_and_register_states() -> void:
	# 遍历所有子节点，自动发现State类型的状态
	for child in get_children():
		if child is GameState:
			var game_state = child as GameState
			var state_enum: GameState.State = game_state.state
			# 若已注册相同枚举值则跳过
			if states.has(state_enum):
				continue
			# 注册状态到字典
			states[state_enum] = game_state
			game_state.game = game

func change_state(new_state: GameState.State) -> void:
	if not is_initialized:
		return
	if not states.has(new_state):
		return
	# 防止重复切换到同一状态
	if current_state and current_state.state == new_state:
		return
	
	var previous_state = current_state
	
	# 退出当前状态
	if current_state:
		current_state._on_exit()
	
	# 先发出状态改变信号，再进入新状态，避免嵌套切换覆盖日志
	var target_state: GameState = states[new_state]
	current_state = target_state
	state_changed.emit(previous_state, current_state)
	current_state._on_enter()


func get_current_state() -> GameState:
	return current_state

func get_current_state_type() -> GameState.State:
	if current_state:
		return current_state.state
	return GameState.State.基础状态

# 处理输入事件
func _input(event: InputEvent) -> void:
	if current_state:
		current_state._on_input(event)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.process_physics(delta)
