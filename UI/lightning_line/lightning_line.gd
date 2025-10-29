extends Node2D
class_name LightningLine

## 闪电线的长度
@export var lightning_length: float = 200.0 : set = set_lightning_length
## 闪电线的宽度（垂直于长度方向的尺寸）
@export var lightning_width: float = 16.0 : set = set_lightning_width
## 是否纵向绘制（角度90度）
@export var vertical: bool = false : set = set_vertical
## 自动销毁的时长（秒），为0则不自动销毁
@export var auto_destroy_after_sec: float = 0.0
## 闪电淡出时长（秒）
@export var fade_duration_sec: float = 0.25
## 淡出时同步降低的参数（<0 表示不处理）
@export var fade_glow_thickness_to: float = 0.0
@export var fade_line_thickness_to: float = -1.0
@export var fade_glow_alpha_to: float = -1.0

var _is_destroying: bool = false

## 节点引用
@onready var lightning_rect: ColorRect = $Lightning
@onready var spark_particles: GPUParticles2D = $SparkParticles
@onready var spark_particles_end: GPUParticles2D = $SparkParticlesEnd

func _ready():
	# 初始化时设置长度和宽度
	set_lightning_length(lightning_length)
	set_lightning_width(lightning_width)
	set_vertical(vertical)
	# 注意：不在_ready中自动销毁，而是等待play函数调用时设置销毁时机
	# 这样避免与play函数中的schedule_destroy_smooth冲突

## 统一更新闪电尺寸（长度和宽度）
func _update_lightning_size():
	# Node2D不需要设置size属性，直接更新子组件
	if is_node_ready():
		_update_lightning_components()

## 重置shader参数到初始状态
func _reset_shader_parameters():
	if lightning_rect and lightning_rect.material is ShaderMaterial:
		var mat: ShaderMaterial = lightning_rect.material
		# 重置关键参数到默认值
		mat.set_shader_parameter("alpha", 1.0)
		mat.set_shader_parameter("thickness", 0.01)
		mat.set_shader_parameter("glow_thickness", 0.08)
		mat.set_shader_parameter("glow_color", Color(1, 0.84313726, 0, 0.5019608))
	# 重置节点透明度
	modulate.a = 1.0

## 设置闪电长度
func set_lightning_length(new_length: float):
	if new_length <= 0:
		push_warning("Lightning length must be positive")
		return
	
	lightning_length = new_length
	_update_lightning_size()

## 设置闪电宽度
func set_lightning_width(new_width: float):
	if new_width <= 0:
		push_warning("Lightning width must be positive")
		return
	
	lightning_width = new_width
	_update_lightning_size()

## 设置纵向/横向
func set_vertical(v: bool):
	vertical = v
	# 通过旋转实现纵向效果：纵向时旋转90度，横向时不旋转
	rotation = PI * 0.5 if vertical else 0.0
	if is_node_ready():
		_update_lightning_components()

## 更新闪电子组件（粒子系统等）
func _update_lightning_components():
	_update_lightning_rect()
	_update_particles()

## 更新闪电矩形
func _update_lightning_rect():
	if lightning_rect:
		lightning_rect.offset_left = 0.0
		lightning_rect.offset_top = -lightning_width / 2.0
		lightning_rect.offset_right = lightning_length
		lightning_rect.offset_bottom = lightning_width / 2.0

## 更新粒子系统
func _update_particles():
	# 更新末端火花粒子
	if spark_particles_end:
		spark_particles_end.position = Vector2(lightning_length, 0)
		spark_particles_end.rotation = 0.0
	
	# 更新火花粒子的可见区域
	if spark_particles:
		spark_particles.visibility_rect = Rect2(0, -lightning_width / 2.0, lightning_length, lightning_width)

## 获取当前闪电长度
func get_lightning_length() -> float:
	return lightning_length

## 获取当前闪电宽度
func get_lightning_width() -> float:
	return lightning_width

## 同时设置长度和宽度
func set_lightning_size(new_length: float, new_width: float):
	if new_length <= 0 or new_width <= 0:
		push_warning("Lightning length and width must be positive")
		return
	
	lightning_length = new_length
	lightning_width = new_width
	_update_lightning_size()

## 播放并在指定时间后销毁
func play(new_length: float, duration_sec: float, vertical_mode: bool = false, new_width: float = -1.0):
	# 重置销毁状态和shader参数，确保每次播放都从正确的状态开始
	_is_destroying = false
	_reset_shader_parameters()
	
	set_vertical(vertical_mode)
	if new_width > 0.0:
		set_lightning_size(new_length, new_width)
	else:
		set_lightning_length(new_length)
	_emit_particles()
	if duration_sec > 0.0:
		schedule_destroy_smooth(duration_sec)

func _emit_particles():
	if spark_particles:
		spark_particles.emitting = true
	if spark_particles_end:
		spark_particles_end.emitting = true

func queue_free_after(sec: float):
	if sec <= 0.0:
		return
	var t: SceneTreeTimer = get_tree().create_timer(sec)
	t.timeout.connect(_on_timeout)

func _on_timeout():
	queue_free()

## 计划在指定时间后执行平滑销毁
func schedule_destroy_smooth(after_sec: float, fade_sec: float = -1.0):
	if after_sec <= 0.0:
		destroy_smooth(fade_sec)
		return
	var t := get_tree().create_timer(after_sec)
	t.timeout.connect(func(): destroy_smooth(fade_sec))

## 立即开始平滑销毁：先淡出，再停止粒子，等待消散后销毁
func destroy_smooth(fade_sec: float = -1.0):
	if _is_destroying:
		return
	_is_destroying = true
	if fade_sec <= 0.0:
		fade_sec = fade_duration_sec

	var start_alpha := 1.0
	var mat: ShaderMaterial = null
	if lightning_rect and lightning_rect.material is ShaderMaterial:
		mat = lightning_rect.material
		if typeof(mat.get_shader_parameter("alpha")) == TYPE_FLOAT:
			start_alpha = float(mat.get_shader_parameter("alpha"))

	var tw: Tween = create_tween()
	if mat:
		tw.tween_method(_set_material_alpha, start_alpha, 0.0, fade_sec)
		# 同步降低 glow_thickness
		if fade_glow_thickness_to >= 0.0:
			var start_glow_thickness: float = float(mat.get_shader_parameter("glow_thickness"))
			tw.tween_method(_set_shader_param_float.bind("glow_thickness"), start_glow_thickness, fade_glow_thickness_to, fade_sec)
		# 同步降低线条厚度
		if fade_line_thickness_to >= 0.0:
			var start_line_thickness: float = float(mat.get_shader_parameter("thickness"))
			tw.tween_method(_set_shader_param_float.bind("thickness"), start_line_thickness, fade_line_thickness_to, fade_sec)
		# 同步降低辉光透明度
		if fade_glow_alpha_to >= 0.0:
			var start_glow_alpha: float = Color(mat.get_shader_parameter("glow_color")).a
			tw.tween_method(_set_shader_glow_alpha, start_glow_alpha, fade_glow_alpha_to, fade_sec)
	else:
		# 无材质时退化为节点不透明度淡出
		var start_mod_a := modulate.a
		tw.tween_property(self, "modulate:a", 0.0, fade_sec).from(start_mod_a)
	
	tw.finished.connect(_on_fade_finished)

func _set_material_alpha(a: float):
	if lightning_rect and lightning_rect.material is ShaderMaterial:
		var m: ShaderMaterial = lightning_rect.material
		m.set_shader_parameter("alpha", a)

func _set_shader_param_float(value: float, param: String):
	if lightning_rect and lightning_rect.material is ShaderMaterial:
		var m: ShaderMaterial = lightning_rect.material
		m.set_shader_parameter(param, value)

func _set_shader_glow_alpha(a: float):
	if lightning_rect and lightning_rect.material is ShaderMaterial:
		var m: ShaderMaterial = lightning_rect.material
		var c: Color = Color(m.get_shader_parameter("glow_color"))
		c.a = a
		m.set_shader_parameter("glow_color", c)

func _on_fade_finished():
	_stop_emission()
	# 计算等待时间，确保当前粒子全部自然消失
	var wait_sec := 0.0
	if spark_particles:
		var spd: float = max(spark_particles.speed_scale, 0.001)
		wait_sec = max(wait_sec, spark_particles.lifetime / spd)
	if spark_particles_end:
		var spd2: float = max(spark_particles_end.speed_scale, 0.001)
		wait_sec = max(wait_sec, spark_particles_end.lifetime / spd2)
	if wait_sec <= 0.0:
		queue_free()
		return
	var t: SceneTreeTimer = get_tree().create_timer(wait_sec + 0.05)
	t.timeout.connect(func(): queue_free())

func _stop_emission():
	if spark_particles:
		spark_particles.emitting = false
	if spark_particles_end:
		spark_particles_end.emitting = false
