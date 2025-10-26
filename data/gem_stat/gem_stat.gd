extends Resource
class_name GemStat

enum GemColor {
	WHITE, #白，钻石，以太
	YELLOW, #黄，黄玉，地
	BLUE, #蓝，蓝宝石，水
	RED, #红，红宝石，火
	GREEN, #绿，翡翠，风
	RAINBOW, #彩虹，融合元素
	OTHER, #其他
}


var color_to_animation_map: Dictionary = {
	GemColor.WHITE: "diamond",      # 白色 - 钻石
	GemColor.YELLOW: "topaz",       # 黄色 - 黄玉
	GemColor.BLUE: "zaphire",       # 蓝色 - 蓝宝石
	GemColor.RED: "ruby",           # 红色 - 红宝石
	GemColor.GREEN: "rupia",        # 绿色 - 翡翠
	GemColor.RAINBOW: "rainbow",      # 彩虹 - 融合元素
	GemColor.OTHER: "_",      # 其他 - 无
}

# 获取当前宝石颜色对应的动画名称
func get_animation_name() -> String:
	return color_to_animation_map.get(color, "_")

# 检查是否有对应的动画
func has_animation_for_color(gem_color: GemColor) -> bool:
	return color_to_animation_map.has(gem_color)


enum SpecialType {
	NONE, #无
	SMALL_EXPLOSION, #小型爆炸宝石，2x2
	EXPLOSION, #爆炸宝石，3x3
	LIGHTING, #闪电宝石，横+竖
	OTHER, #其他
}


@export var color: GemColor #宝石颜色/类别
@export var powerful: bool #强化宝石，暂定
@export var special_type: SpecialType #特殊宝石类型


# 用于动态修改
func set_gem_color(new_color: GemColor) -> void:
	color = new_color

func set_gem_powerful(new_powerful: bool) -> void:
	powerful = new_powerful

func set_gem_special_tyoe(new_special_type: SpecialType) -> void:
	special_type = new_special_type
