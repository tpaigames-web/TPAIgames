class_name BulletEffect extends Resource

## 子弹效果资源（单一类，通过 effect_type 区分6种效果）
## 在编辑器中创建 .tres 文件并配置各字段即可使用

enum Type {
	SLOW,    ## 减速：降低移动速度
	BURN,    ## 燃烧：持续火焰伤害（DoT）
	POISON,  ## 中毒：持续毒素伤害（DoT，间隔更长）
	BLEED,   ## 流血：持续出血伤害（DoT，可叠加层数）
	STUN,    ## 定身：完全停止移动
	MARK,    ## 标记：使目标受到更多伤害
}

## 效果类型
@export var effect_type: Type = Type.SLOW

## 持续时间（秒）
@export var duration: float = 3.0

## 效果强度（含义因类型而异）：
##   SLOW → 减速比例 0~1（0.3 = 减速30%，剩余70%速度）
##   MARK → 额外伤害加成比例（0.25 = 受到额外25%伤害）
##   其余类型此字段无意义，强度由 damage_per_tick 决定
@export var potency: float = 0.3

## 每次 tick 的伤害量（BURN / POISON / BLEED 有效，其他填 0）
@export var damage_per_tick: float = 5.0

## DoT tick 间隔（秒）；建议：BURN=1.0, POISON=1.5, BLEED=0.5
@export var tick_interval: float = 1.0

## 是否对巨型单位（is_giant=true）生效
## 控制类效果（SLOW / STUN）默认对巨型无效，需显式开启
@export var affects_giant: bool = false
