@abstract
extends Node
class_name GameState

# 抽象状态基类（GameState）
# - 定义状态枚举与统一回调接口：_on_enter/_on_exit/process_physics/_on_input
# - 所有具体状态需继承并实现上述抽象方法

enum State {基础状态, 交换状态, 消除状态, 下落状态, 生成状态, 匹配状态, 特殊消除状态, 特殊生成状态}

static func state_to_string(_state: State) -> String:
	match _state:
		State.基础状态: return "基础"
		State.交换状态: return "交换"
		State.消除状态: return "消除"
		State.下落状态: return "下落"
		State.生成状态: return "生成"
		State.匹配状态: return "匹配"
		State.特殊消除状态: return "特殊消除"
		State.特殊生成状态: return "特殊生成"
		_: return "_"

@export var state: State = State.基础状态

var game: Arena


# 状态进入：进入该状态时触发，一般用于初始化或触发一次性逻辑
@abstract
func _on_enter() -> void

# 状态退出：离开该状态时触发，用于清理或撤销连接
@abstract
func _on_exit() -> void

@abstract
func process_physics(_delta: float) -> void

@abstract
func _on_input(_event: InputEvent) -> void
