extends Control
class_name Gem

const HALF_GEM_SIZE := Vector2(18, 18)
const EFFECT_SPEED_SCALE := 2.0
const DEFAULT_ANIMATION := "ranbow"

signal move_completed()
signal destroy_completed()

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# 销毁材质路径
const DESTROY_SHADER_PATH := "res://assets/shader/pixel_explosion_from_(Elid Elid).gdshader"
const NOISE_TEX_PATH := "res://assets/noise/explosion_noise.tres"
const NOISE_NORMAL_TEX_PATH := "res://assets/noise/explosion_noise_normal.tres"
#特殊宝石材质
const FIRE_SHADER_PATH := "res://assets/shader/fire.gdshader"
const LIGHTNING_SHADER_PATH := "res://assets/shader/lightning.gdshader"
#销毁材质
var _destroy_material: ShaderMaterial
var _noise_tex: Texture2D
var _noise_tex_normal: Texture2D
#特殊宝石材质
var _fire_material: ShaderMaterial
var _lightning_material: ShaderMaterial

@export var gem_stat: GemStat : set = _set_gem_stat

var _gem_stat: GemStat
var _current_animation: String = ""

@onready var move_tween: Tween
@onready var destroy_tween: Tween


func _ready() -> void:
	_preload_shaders()
	update_animation()

# 设置gem_stat时自动更新
func _set_gem_stat(new_gem_stat: GemStat) -> void:
	if _gem_stat == new_gem_stat:
		return
	
	_gem_stat = new_gem_stat
	
	if animated_sprite:
		update_animation()
		_refresh_special_visual()


func _preload_shaders() -> void:
	# 噪声纹理
	_noise_tex = load(NOISE_TEX_PATH)
	_noise_tex_normal = load(NOISE_NORMAL_TEX_PATH)
	
	#创建销毁材质
	var destroy_shader: Shader = load(DESTROY_SHADER_PATH)
	_destroy_material = ShaderMaterial.new()
	_destroy_material.shader = destroy_shader
	#配置销毁材质
	if _destroy_material:
		if _noise_tex_normal:
			_destroy_material.set_shader_parameter("noise_tex_normal", _noise_tex_normal)
		if _noise_tex:
			_destroy_material.set_shader_parameter("noise_tex", _noise_tex)
		_destroy_material.set_shader_parameter("progress", 0.0)
		_destroy_material.set_shader_parameter("strength", 1.0)
	
	# 火焰材质
	var fire_shader: Shader = load(FIRE_SHADER_PATH)
	_fire_material = ShaderMaterial.new()
	_fire_material.shader = fire_shader
	#配置火焰材质
	if _fire_material and _noise_tex:
		_fire_material.set_shader_parameter("noise_texture", _noise_tex)
		_fire_material.set_shader_parameter("edge_color", Color(1.0, 0.45, 0.05, 1.0))
		_fire_material.set_shader_parameter("noise_size", 0.8)
		_fire_material.set_shader_parameter("noise_speed", 1.2)
	
	# 闪电材质
	var lightning_shader: Shader = load(LIGHTNING_SHADER_PATH)
	_lightning_material = ShaderMaterial.new()
	_lightning_material.shader = lightning_shader
	_lightning_material.set_shader_parameter("intensity", 1.0)
	_lightning_material.set_shader_parameter("speed", 2.0)
	_lightning_material.set_shader_parameter("lightning_color", Color(0.6, 0.85, 1.0, 1.0))


# 根据特殊类型决定显示材质
func _apply_destroy_material() -> void:
	if animated_sprite and _destroy_material:
		animated_sprite.material = _destroy_material

func _apply_lightning_material() -> void:
	if animated_sprite and _lightning_material:
		animated_sprite.material = _lightning_material

func _apply_fire_material(noise_size: float, noise_speed: float) -> void:
	if not _fire_material:
		_apply_destroy_material()
		return
	_fire_material.set_shader_parameter("noise_size", noise_size)
	_fire_material.set_shader_parameter("noise_speed", noise_speed)
	_apply_fire_color_by_gem_color()
	if animated_sprite:
		animated_sprite.material = _fire_material

func _refresh_special_visual() -> void:
	if not animated_sprite:
		return
	if not _gem_stat:
		_apply_destroy_material()
		return
	match _gem_stat.special_type:
		GemStat.SpecialType.NONE:
			_apply_destroy_material()
		GemStat.SpecialType.LIGHTING:
			_apply_lightning_material()
		GemStat.SpecialType.SMALL_EXPLOSION:
			_apply_fire_material(0.2, 1.0)
		GemStat.SpecialType.EXPLOSION:
			_apply_fire_material(1.5, 2.0)
		GemStat.SpecialType.OTHER:
			_apply_destroy_material()


# 根据宝石基础颜色映射火焰颜色（白黄蓝红绿），其他使用默认
func _apply_fire_color_by_gem_color() -> void:
	if not _fire_material or not _gem_stat:
		return
	var c = _gem_stat.color
	var col: Color = Color(1.0, 0.45, 0.05, 1.0) # 默认橙色
	match c:
		GemStat.GemColor.WHITE:
			col = Color(1.0, 1.0, 1.0, 1.0)
		GemStat.GemColor.YELLOW:
			col = Color(1.0, 0.85, 0.20, 1.0)
		GemStat.GemColor.BLUE:
			col = Color(0.35, 0.65, 1.0, 1.0)
		GemStat.GemColor.RED:
			col = Color(1.0, 0.35, 0.25, 1.0)
		GemStat.GemColor.GREEN:
			col = Color(0.35, 0.95, 0.45, 1.0)
		_:
			# 其他颜色使用默认橙色
			pass
	_fire_material.set_shader_parameter("edge_color", col)


func update_animation() -> void:
	if not _gem_stat or not animated_sprite:
		return
	var animation_name := _gem_stat.get_animation_name()
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(animation_name):
		if _current_animation != animation_name:
			animated_sprite.animation = animation_name
			_current_animation = animation_name
		if not animated_sprite.is_playing():
			animated_sprite.play()
	else:
		print("警告: 动画 '", animation_name, "' 不存在，使用默认动画")
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(DEFAULT_ANIMATION):
			if _current_animation != DEFAULT_ANIMATION:
				animated_sprite.animation = DEFAULT_ANIMATION
				_current_animation = DEFAULT_ANIMATION
			if not animated_sprite.is_playing():
				animated_sprite.play()
	_refresh_special_visual()

# 动态改变宝石颜色
func change_gem_color(new_color: GemStat.GemColor):
	if _gem_stat:
		_gem_stat.set_gem_color(new_color)
		update_animation()


# ==================== 旋转帧动画相关函数 ====================

# 开始旋转动画（设置速度为2）
func start_effect_animation():
	if not animated_sprite:
		return
	# 已在以相同速度播放则不重复设置
	if animated_sprite.speed_scale == EFFECT_SPEED_SCALE and animated_sprite.is_playing():
		return
	animated_sprite.speed_scale = EFFECT_SPEED_SCALE
	animated_sprite.play()

# 结束旋转动画（直到frame归0时停止）
func end_effect_animation():
	if not animated_sprite:
		return
	# 已经停止则直接清理，不重复连接
	if animated_sprite.speed_scale == 0.0:
		_stop_effect_animation()
		return
	if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
		animated_sprite.frame_changed.connect(_on_frame_changed)
	if animated_sprite.frame == 0:
		_stop_effect_animation()

# 监听帧变化的处理函数
func _on_frame_changed():
	if animated_sprite and animated_sprite.frame == 0:
		_stop_effect_animation()

# 停止特效动画的处理函数
func _stop_effect_animation():
	if animated_sprite:
		# 停止动画
		animated_sprite.pause()
		# 确保frame归0
		animated_sprite.frame = 0
		# 速度为0
		animated_sprite.speed_scale = 0.0
		# 断开信号连接，避免重复连接
		if animated_sprite.frame_changed.is_connected(_on_frame_changed):
			animated_sprite.frame_changed.disconnect(_on_frame_changed)


# ==================== 移动动画相关函数 ====================

func move_to_global_position(target_global_position: Vector2, duration: float = 0.5, rotate: bool = true, use_bounce: bool = false):
	"""
	使用Tween动画移动gem到指定的全局位置
	参数:
		target_global_position: 目标全局位置
		duration: 移动持续时间（默认0.5秒）
	"""
	# 如果已有Tween在运行，先停止它
	if move_tween:
		if move_tween.finished.is_connected(_on_move_animation_finished):
			move_tween.finished.disconnect(_on_move_animation_finished)
		move_tween.kill()
		move_tween = null
	
	# 创建新的Tween
	move_tween = create_tween()
	
	# 设置Tween属性（根据 use_bounce 控制是否弹跳）
	if use_bounce:
		move_tween.set_ease(Tween.EASE_OUT)
		move_tween.set_trans(Tween.TRANS_BOUNCE)
	else:
		move_tween.set_ease(Tween.EASE_OUT)
		move_tween.set_trans(Tween.TRANS_CUBIC)
	
	# 移动开始时自动开始旋转动画
	if rotate:
		start_effect_animation()
	
	# 执行位置动画
	move_tween.tween_property(self, "global_position", target_global_position, duration)
	
	# 连接完成信号
	move_tween.finished.connect(_on_move_animation_finished)

# 移动动画完成时的回调函数
func _on_move_animation_finished():
	"""移动动画完成时调用"""
	# 移动结束时自动结束旋转动画
	if not animated_sprite.speed_scale == 0.0:
		end_effect_animation()
	
	# 发送移动完成信号
	move_completed.emit()
	
	# 清理Tween引用
	move_tween = null


# ==================== 销毁动画相关函数 ====================

# 开始销毁动画
func destroy_animation(duration: float = 0.5):
	"""
	开始销毁动画，使用Pixel Explosion着色器
	duration: 动画持续时间，默认0.5秒
	"""
	# 如果已经在销毁中，直接返回
	if is_destroying():
		return
	
	# 销毁时切换回销毁材质，确保progress参数存在
	if animated_sprite and _destroy_material:
		animated_sprite.material = _destroy_material
		_destroy_material.set_shader_parameter("progress", 0.0)
	
	# 创建新的Tween
	destroy_tween = create_tween()
	destroy_tween.set_ease(Tween.EASE_IN_OUT)
	destroy_tween.set_trans(Tween.TRANS_CUBIC)
	
	# 动画progress参数从0.0到1.0
	destroy_tween.tween_method(_update_destroy_progress, 0.0, 1.0, duration)
	
	# 连接完成信号
	destroy_tween.finished.connect(_on_destroy_animation_finished)

# 更新销毁进度
func _update_destroy_progress(progress: float):
	"""更新着色器的progress参数"""
	if _destroy_material:
		_destroy_material.set_shader_parameter("progress", progress)

# 销毁动画完成时的回调函数
func _on_destroy_animation_finished():
	"""销毁动画完成时调用"""
	# 发送销毁完成信号
	destroy_completed.emit()
	
	# 断开信号连接
	if destroy_tween and destroy_tween.finished.is_connected(_on_destroy_animation_finished):
		destroy_tween.finished.disconnect(_on_destroy_animation_finished)
	
	# 清理Tween引用
	destroy_tween = null

# 检查是否正在销毁
func is_destroying() -> bool:
	"""检查gem是否正在播放销毁动画"""
	return destroy_tween != null and destroy_tween.is_valid()
