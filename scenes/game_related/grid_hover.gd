extends Node
class_name GridHover

signal tile_swap_requested(from_tile: Vector2i, to_tile: Vector2i)

# 两态状态机：基础悬停（BASE）与选中（SELECTED）
enum State { BASE, SELECTED }

@export var area: GameArea
@onready var hover_indicator: TextureRect = $IconSelect
@onready var candidate_indicator: TextureRect = $IconMaybeSelect

@export var indicator_offset: Vector2 = Vector2(20, 20)
@export var hover_color: Color = Color(1, 1, 1, 1)
@export var selected_color: Color = Color(1.0, 0.85, 0.20, 1.0)
const DRAG_THRESHOLD: float = 8.0

var state: State = State.BASE

var hover_tile: Vector2i = Vector2i(-1, -1)
var selected_tile: Vector2i = Vector2i(-1, -1)
var candidate_tiles: Array[Vector2i] = []
var candidate_hover_tile: Vector2i = Vector2i(-1, -1)

# 鼠标拖拽相关
var is_mouse_pressed: bool = false
var mouse_pressed_at: Vector2 = Vector2.ZERO
var pressed_tile: Vector2i = Vector2i(-1, -1)

# 动画中的宝石引用
var hover_gem: Gem = null
var selected_gem: Gem = null
var candidate_gem: Gem = null

func _ready() -> void:
	if hover_indicator:
		hover_indicator.visible = false
	if candidate_indicator:
		candidate_indicator.visible = false

func _process(_delta: float) -> void:
	if not area:
		return
	var tile: Vector2i = area.get_hovered_tile()
	match state:
		State.BASE:
			_process_base(tile)
		State.SELECTED:
			_process_selected(tile)

func _input(event: InputEvent) -> void:
	if not area:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_mouse_pressed = true
				mouse_pressed_at = event.global_position
				pressed_tile = area.get_tile_from_global(event.global_position)
			else:
				_on_left_release(event.global_position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_change_state(State.BASE)
	elif event is InputEventMouseMotion and is_mouse_pressed:
		_on_mouse_drag(event.global_position)

# =================== 状态逻辑 ===================
func _process_base(tile: Vector2i) -> void:
	if area.is_tile_in_bounds(tile):
		if tile != hover_tile:
			_set_hover_tile(tile)
	else:
		_clear_hover()

func _process_selected(tile: Vector2i) -> void:
	if not area:
		return
	var in_bounds: bool = area.is_tile_in_bounds(tile)
	if in_bounds and tile in candidate_tiles:
		if tile != candidate_hover_tile:
			candidate_hover_tile = tile
			_update_indicator_position(candidate_indicator, tile)
			if candidate_indicator and not candidate_indicator.visible:
				candidate_indicator.visible = true
			_start_candidate_animation(tile)
		# 当悬停在候选格时，停止非候选悬停动画
		_stop_hover_animation()
	else:
		# 只在四个候选格显示候选指示器
		if candidate_indicator and candidate_indicator.visible:
			candidate_indicator.visible = false
		if candidate_hover_tile != Vector2i(-1, -1):
			_stop_candidate_animation()
			candidate_hover_tile = Vector2i(-1, -1)
		# 非候选格也旋转（参照基础悬停），但不移动/改变选中指示器
		if in_bounds:
			if tile != hover_tile:
				hover_tile = tile
				_start_hover_animation(tile)
		else:
			_stop_hover_animation()

# =================== 输入与交互 ===================
func _on_left_release(global_pos: Vector2) -> void:
	if not is_mouse_pressed:
		return
	var dist: float = global_pos.distance_to(mouse_pressed_at)
	if dist < DRAG_THRESHOLD:
		var clicked: Vector2i = area.get_tile_from_global(global_pos)
		_on_click(clicked)
	_reset_mouse_press()

func _on_mouse_drag(global_pos: Vector2) -> void:
	var dist: float = global_pos.distance_to(mouse_pressed_at)
	if dist < DRAG_THRESHOLD:
		return
	var dir: Vector2i = _drag_direction(mouse_pressed_at, global_pos)
	if dir == Vector2i.ZERO:
		return
	var origin: Vector2i = pressed_tile
	var target: Vector2i = origin + dir
	if area.is_tile_in_bounds(origin) and area.is_tile_in_bounds(target):
		tile_swap_requested.emit(origin, target)
		_change_state(State.BASE)
		_reset_mouse_press()

func _on_click(tile: Vector2i) -> void:
	match state:
		State.BASE:
			if area.is_tile_in_bounds(tile):
				hover_tile = tile
				selected_tile = tile
				_change_state(State.SELECTED)
		State.SELECTED:
			if tile == selected_tile:
				_change_state(State.BASE)
			elif tile in candidate_tiles:
				tile_swap_requested.emit(selected_tile, tile)
				_change_state(State.BASE)
			elif area.is_tile_in_bounds(tile):
				# 切换选中到新的位置：先停止旧选中动画，再切换并启动新选中动画
				_stop_selected_animation()
				selected_tile = tile
				_enter_selected() # 刷新选中上下文

# 计算拖拽方向（四方向）
func _drag_direction(from: Vector2, to: Vector2) -> Vector2i:
	var d: Vector2 = to - from
	var ad: Vector2 = d.abs()
	if ad.x > ad.y:
		if d.x > 0.0:
			return Vector2i(1, 0)
		else:
			return Vector2i(-1, 0)
	elif ad.y > 0.0:
		if d.y > 0.0:
			return Vector2i(0, 1)
		else:
			return Vector2i(0, -1)
	return Vector2i.ZERO

# =================== 状态切换 ===================
func _change_state(s: State) -> void:
	if state == s:
		return
	_exit_state(state)
	state = s
	_enter_state(state)

func _exit_state(s: State) -> void:
	match s:
		State.BASE:
			_stop_hover_animation()
		State.SELECTED:
			_stop_selected_animation()
			_stop_candidate_animation()
			if candidate_indicator:
				candidate_indicator.visible = false
			# 立即隐藏选中指示器，避免一帧延迟显示金色
			if hover_indicator:
				hover_indicator.visible = false
			candidate_tiles.clear()
			candidate_hover_tile = Vector2i(-1, -1)

func _enter_state(s: State) -> void:
	match s:
		State.BASE:
			selected_tile = Vector2i(-1, -1)
			# 进入基础状态时立即刷新指示器，避免一帧延迟
			if area:
				var t: Vector2i = area.get_hovered_tile()
				if area.is_tile_in_bounds(t):
					_set_hover_tile(t)
				else:
					_clear_hover()
		State.SELECTED:
			_enter_selected()

func _enter_selected() -> void:
	# 指示器显示在选中位置
	_update_indicator_position(hover_indicator, selected_tile)
	if hover_indicator:
		hover_indicator.modulate = selected_color
		hover_indicator.visible = true
	# 启动选中 gem 动画
	_start_selected_animation(selected_tile)
	# 计算候选边界
	_rebuild_candidate_tiles()
	# 初始隐藏候选指示器
	if candidate_indicator:
		candidate_indicator.visible = false

# =================== 指示器与动画 ===================
func _set_hover_tile(tile: Vector2i) -> void:
	hover_tile = tile
	_update_indicator_position(hover_indicator, tile)
	if hover_indicator:
		hover_indicator.modulate = hover_color
		if not hover_indicator.visible:
			hover_indicator.visible = true
	_start_hover_animation(tile)

func _clear_hover() -> void:
	hover_tile = Vector2i(-1, -1)
	if hover_indicator and hover_indicator.visible:
		hover_indicator.visible = false
	_stop_hover_animation()

func _update_indicator_position(indicator: TextureRect, tile: Vector2i) -> void:
	if not indicator or not area:
		return
	var center: Vector2 = area.get_global_from_tile(tile)
	var target: Vector2 = center - indicator_offset
	# 位置未变则不重复赋值，避免无意义的布局更新
	if indicator.global_position == target:
		return
	indicator.global_position = target

func _rebuild_candidate_tiles() -> void:
	candidate_tiles.clear()
	if selected_tile == Vector2i(-1, -1):
		return
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for dir in dirs:
		var t: Vector2i = selected_tile + dir
		if area.is_tile_in_bounds(t):
			candidate_tiles.append(t)

# 悬停动画
func _start_hover_animation(tile: Vector2i) -> void:
	if not area or not area.game_grid:
		return
	var gem: Gem = area.game_grid.get_gem(tile)
	if not gem or not is_instance_valid(gem):
		return
	# 同一颗宝石不重复停止/启动动画
	if hover_gem == gem:
		return
	_stop_hover_animation()
	hover_gem = gem
	gem.start_effect_animation()

func _stop_hover_animation() -> void:
	if hover_gem and is_instance_valid(hover_gem):
		# 若即将选中的是同一格，避免结束效果以保持连续旋转
		if hover_tile != selected_tile:
			hover_gem.end_effect_animation()
	hover_gem = null

# 选中动画
func _start_selected_animation(tile: Vector2i) -> void:
	if not area or not area.game_grid:
		return
	var gem: Gem = area.game_grid.get_gem(tile)
	if not gem or not is_instance_valid(gem):
		return
	if selected_gem == gem:
		return
	_stop_selected_animation()
	selected_gem = gem
	gem.start_effect_animation()

func _stop_selected_animation() -> void:
	if selected_gem and is_instance_valid(selected_gem):
		selected_gem.end_effect_animation()
	selected_gem = null

# 候选动画
func _start_candidate_animation(tile: Vector2i) -> void:
	if not area or not area.game_grid:
		return
	var gem: Gem = area.game_grid.get_gem(tile)
	if not gem or not is_instance_valid(gem):
		return
	if candidate_gem == gem:
		return
	_stop_candidate_animation()
	candidate_gem = gem
	gem.start_effect_animation()

func _stop_candidate_animation() -> void:
	if candidate_gem and is_instance_valid(candidate_gem):
		candidate_gem.end_effect_animation()
	candidate_gem = null

# =================== 工具 ===================
func _reset_mouse_press() -> void:
	is_mouse_pressed = false
	mouse_pressed_at = Vector2.ZERO
	pressed_tile = Vector2i(-1, -1)
