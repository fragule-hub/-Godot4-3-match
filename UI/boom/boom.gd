extends ColorRect
class_name Boom

@export var default_size_px: float = 128.0
@export var default_duration_sec: float = 2.0

var _end_timer: SceneTreeTimer

func _ready() -> void:
	# 不再自动播放，等待外部调用 play() 方法
	print("Boom _ready: ", self)

## 播放爆炸效果并在结束时自动销毁
## @param size_px: 节点矩形尺寸（正方形，像素）
## @param duration_sec: 播放时长（秒），按该时长驱动一次循环
func play(size_px: float, duration_sec: float = 2.0) -> void:
	print("Boom play: ", self, " size=", size_px, " duration=", duration_sec)
	# 设置节点尺寸（确保足够显示完整效果）
	size_px = max(32.0, size_px)
	custom_minimum_size = Vector2(size_px, size_px)
	size = Vector2(size_px, size_px)

	# 设置着色器参数：局部UV缩放（与节点尺寸线性映射），一次循环时长
	var mat := material as ShaderMaterial
	if mat:
		# 将 128px 映射到 shader size=5.0 的基准
		var base_shader_size := 5.0
		var shader_size := base_shader_size * (size_px / 128.0)
		mat.set_shader_parameter("size", shader_size)
		mat.set_shader_parameter("disp", Vector2(0.0, 0.0))

		# 设置循环速度，使一次循环时长约为 duration_sec（repeat = mod(iTime * speed, 2.0)）
		duration_sec = max(0.2, duration_sec)
		var speed := 2.0 / duration_sec
		mat.set_shader_parameter("boom_repeat", speed)
		mat.set_shader_parameter("smoke_repeat", speed)

	# 计时结束自动销毁
	if _end_timer:
		# 确保旧计时器被正确断开连接
		if _end_timer.timeout.is_connected(_on_effect_finished):
			_end_timer.timeout.disconnect(_on_effect_finished)
		_end_timer = null
	
	_end_timer = get_tree().create_timer(duration_sec)
	_end_timer.timeout.connect(_on_effect_finished, Object.CONNECT_ONE_SHOT)

func _on_effect_finished() -> void:
	print("Boom _on_effect_finished: ", self, " - calling queue_free()")
	queue_free()
