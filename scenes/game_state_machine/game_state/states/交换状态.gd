# 状态：交换
# - 从队列中取一次交换请求，判断是否会形成匹配
# - 成功：执行逻辑交换进入匹配状态；失败：播放反向动画
extends GameState

var _current_swap_request: Dictionary = {}

func _on_enter() -> void:
	if not game or not game.state_machine or not game.game_calculator or not game.gem_swap:
		push_error("交换状态缺少必要的节点引用")
		game.state_machine.change_state(GameState.State.基础状态)
		return

	if not game.has_swap_requests():
		game.state_machine.change_state(GameState.State.匹配状态)
		return

	_current_swap_request = game.dequeue_swap_request()
	var from_tile: Vector2i = _current_swap_request["from"]
	var to_tile: Vector2i = _current_swap_request["to"]

	# 预动画已播放完毕，此处直接进行逻辑判断（仅数据层判断）
	var will_match: bool = game.game_calculator._would_create_match_after_swap(from_tile, to_tile)

	if will_match:
		# 匹配成功：执行逻辑交换（数据层）并进入匹配状态
		game.gem_swap.swap_gems_in_grid(from_tile, to_tile)
		# 设置当前交换位置数组用于移除信息标记
		game.current_swap_tiles = [from_tile, to_tile]
		game.state_machine.change_state(GameState.State.匹配状态)
	else:
		# 匹配失败：播放反向动画（视觉层）
		print("交换无效，播放反向动画")
		if not game.gem_swap.swap_animation_completed.is_connected(_on_swap_animation_completed):
			game.gem_swap.swap_animation_completed.connect(_on_swap_animation_completed)
		game.gem_swap.play_reverse_swap_animation(from_tile, to_tile)

# 仅处理反向动画完成后的状态流转
func _on_swap_animation_completed(_from_tile: Vector2i, _to_tile: Vector2i, anim_type: GemSwap.SwapAnimType) -> void:
	# 只处理反向动画完成
	if anim_type != GemSwap.SwapAnimType.REVERSE_SWAP:
		return
	if game and game.state_machine:
		game.state_machine.change_state.call_deferred(GameState.State.匹配状态)
		

func _on_exit() -> void:
	_current_swap_request.clear()
	# 清除当前交换位置数组
	if game and game.gem_swap and game.gem_swap.swap_animation_completed.is_connected(_on_swap_animation_completed):
		game.gem_swap.swap_animation_completed.disconnect(_on_swap_animation_completed)

func process_physics(_delta: float) -> void:
	pass

func _on_input(_event: InputEvent) -> void:
	pass
