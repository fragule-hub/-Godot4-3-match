@abstract
extends Node
class_name GameState

enum State {基础状态, 交换状态, 消除状态, 下落状态, 生成状态}

static func state_to_string(_state: State) -> String:
	match _state:
		State.基础状态: return "基础"
		State.交换状态: return "交换"
		State.消除状态: return "消除"
		State.下落状态: return "下落"
		State.生成状态: return "生成"
		_: return "_"

@export var state: State

var game: Arena


# 状态进入时回调
@abstract
func _on_enter() -> void

# 状态退出时回调
@abstract
func _on_exit() -> void

@abstract
func process_physics(_delta: float) -> void

@abstract
func _on_input(_event: InputEvent) -> void
