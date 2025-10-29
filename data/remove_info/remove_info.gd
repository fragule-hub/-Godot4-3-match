extends RefCounted
class_name RemoveInfo

## 宝石消除信息类
## 用于记录一次消除操作的详细信息，包括消除类型、位置、原因等

## 消除类型枚举
enum RemoveType {
	DESTROY,    ## 通过特殊能力进行的独立消除
	MATCH_3,    ## 在横竖方向上，三个连成线
	MATCH_4,    ## 在横竖方向上，四个连成线
	CROSS,      ## 在横竖方向上均存在3消的情况，形成十字或L型/T型
	MATCH_5,    ## 在横竖方向上，五个连成线
	BIG_CROSS,  ## 在横竖方向上均存在3消的基础上，某一方向存在至少4消的情况
	LONG_CHAIN, ## 在横竖方向上，六个或更多个连成线
}

## 消除原因枚举
enum CauseType {
	SWAP,     ## 由玩家交换操作导致的消除
	CASCADE   ## 由宝石下落连锁反应导致的消除
}

## 宝石颜色
var color: GemStat.GemColor
## 消除类型
var remove_type: RemoveType
## 单次消除的宝石数量
var gem_count: int
## 消除原因
var cause_type: CauseType
## 消除的中心位置（如果为交换导致的消除，则为最后交换的位置）
var center_tile: Vector2i
## 消除的其他位置（用于动画播放）
var other_tiles: Array[Vector2i]

## 构造函数
## @param gem_color: 宝石颜色
## @param type: 消除类型
## @param count: 消除的宝石数量
## @param cause: 消除原因
## @param center: 中心位置
## @param others: 其他位置数组
func _init(gem_color: GemStat.GemColor, type: RemoveType, count: int, cause: CauseType, center: Vector2i, others: Array[Vector2i]):
	color = gem_color
	remove_type = type
	gem_count = count
	cause_type = cause
	center_tile = center
	other_tiles = others

## 获取消除类型的描述文本
func get_type_description() -> String:
	match remove_type:
		RemoveType.DESTROY:
			return "摧毁"
		RemoveType.MATCH_3:
			return "三消"
		RemoveType.MATCH_4:
			return "四消"
		RemoveType.CROSS:
			return "十字"
		RemoveType.MATCH_5:
			return "五消"
		RemoveType.BIG_CROSS:
			return "大十字"
		RemoveType.LONG_CHAIN:
			return "长连"
		_:
			return "未知"

## 获取所有涉及的位置（包括中心位置）
func get_all_tiles() -> Array[Vector2i]:
	var all_tiles: Array[Vector2i] = [center_tile]
	all_tiles.append_array(other_tiles)
	return all_tiles

## 检查指定位置是否在此次消除中
func contains_tile(tile: Vector2i) -> bool:
	if center_tile == tile:
		return true
	return tile in other_tiles
