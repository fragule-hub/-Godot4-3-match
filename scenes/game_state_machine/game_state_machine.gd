# 游戏状态机（GameStateMachine）
# - 负责自动发现子状态（GameState）并统一调度：_on_enter/_on_exit/process_physics/_on_input
# - 保持对外接口稳定（initialize/change_state/get_current_state/get_current_state_type/state_changed）
# - 化繁为简：增加默认初始状态导出、统一类型标注与更清晰的函数注释
extends Node
class_name GameStateMachine

signal state_changed(from_state: GameState, to_state: GameState)

@export var default_state: GameState.State = GameState.State.基础状态

var current_state: GameState = null
var states: Dictionary = {}

var game: Arena = null

var is_initialized: bool = false

func _ready() -> void:
	pass

# 由舞台调用的初始化方法：注入 Arena 并注册所有状态
func initialize(game_ref: Arena) -> void:
	if is_initialized:
		return
	
	game = game_ref
	_discover_and_register_states()
	is_initialized = true
	
	# 设置初始状态（可在 Inspector 配置）
	change_state(default_state)

# 自动发现并注册所有 GameState 子节点
func _discover_and_register_states() -> void:
	# 遍历所有子节点，自动发现State类型的状态
	for child in get_children():
		if child is GameState:
			var game_state = child as GameState
			var state_enum: GameState.State = game_state.state
			# 若已注册相同枚举值则跳过
			if states.has(state_enum):
				continue
			# 注册状态到字典并注入 Arena
			states[state_enum] = game_state
			game_state.game = game

# 切换状态：先退出旧状态，再进入新状态并发射信号
func change_state(new_state: GameState.State) -> void:
	if not is_initialized:
		return
	if not states.has(new_state):
		push_error("GameStateMachine: 目标状态未注册 -> " + GameState.state_to_string(new_state))
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

# 判断当前是否处于指定状态
func is_in_state(state: GameState.State) -> bool:
	return current_state != null and current_state.state == state

# 处理输入事件：转发给当前状态
func _input(event: InputEvent) -> void:
	if current_state:
		current_state._on_input(event)

# 物理帧处理：转发给当前状态
func _physics_process(delta: float) -> void:
	if current_state:
		current_state.process_physics(delta)
