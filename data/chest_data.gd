class_name ChestData extends Resource

## 宝箱类型数据
## 稀有度体系（从低到高）：白 → 绿 → 蓝 → 紫 → 橙

@export var chest_name: String = ""
@export_enum("木宝箱", "铁宝箱", "金宝箱") var chest_type: int = 0

## 购买卡片上的两行说明文字（可在 .tres 中自由修改）
@export var info_line1: String = "- ? 张卡片"
@export var info_line2: String = "- ? 稀有"

## 直接购买此宝箱的宝石费用（0 = 免费）
@export var gem_purchase_cost: int = 0

## 槽位系统用：解锁等待时间（秒），直接购买开箱不需要
@export var unlock_time_seconds: int = 10800

## 开箱掉落的卡片张数
@export var card_count: int = 3

## 5级稀有度权重（无需合计为100，内部归一化计算）
@export var white_weight:  int = 65  # 白 - 最常见
@export var green_weight:  int = 20  # 绿
@export var blue_weight:   int = 10  # 蓝
@export var purple_weight: int = 4   # 紫
@export var orange_weight: int = 1   # 橙 - 最稀有

## 碎片/金币奖励范围（后续开箱逻辑使用）
@export var fragments_min: int = 5
@export var fragments_max: int = 15
@export var gold_min: int = 50
@export var gold_max: int = 200
