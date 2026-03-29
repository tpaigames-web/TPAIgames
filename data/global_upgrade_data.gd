## 全局升级（波次强化）数据资源
## 每局游戏在特定波次出现 3 选 1 升级面板时使用此资源描述一张升级卡
class_name GlobalUpgradeData
extends Resource

## 升级类型
enum UpgradeType {
	TOWER_STAT,      ## 指定炮台属性加成
	GLOBAL_STAT,     ## 全场炮台属性加成
	SYNERGY,         ## 羁绊：需放置指定炮台才激活
	COST_REDUCTION,  ## 放置费用折扣
}

## 属性类型
enum StatType {
	DAMAGE,     ## 伤害
	SPEED,      ## 攻速
	RANGE,      ## 射程
	COST,       ## 费用（折扣）
	ARMOR_PEN,  ## 穿甲加成
	DOT_BONUS,  ## DoT伤害加成（出血/毒素/燃烧）
	CRIT,       ## 暴击率加成
	MARK,       ## 标记增伤加成
	CONTROL,    ## 控制效果加成（减速/冻结）
	SPECIAL,    ## 特殊效果（由能力脚本解读）
}

@export var upgrade_id:   String = ""      ## 唯一标识符
@export var display_name: String = ""      ## 显示名称
@export var description:  String = ""      ## 含数值的完整效果说明
@export var icon_emoji:   String = "⭐"    ## 图标 emoji
## 稀有度：0=白色（普通）1=蓝色（稀有）2=橙色（史诗）3=红色（传说）
@export var rarity:       int    = 0

## 升级类型（UpgradeType 枚举值）
@export var upgrade_type: int = UpgradeType.TOWER_STAT

# ── TOWER_STAT / COST_REDUCTION / GLOBAL_STAT ───────────────────────────────
## 目标炮台 tower_id；"" = 所有炮台（仅对 GLOBAL_STAT / COST_REDUCTION 有效）
@export var target_tower_id: String = ""
## 属性类型（StatType 枚举值）
@export var stat_type:       int    = StatType.DAMAGE
## 叠加比例加成（0.20 = +20%；费用折扣时为减少比例）
@export var stat_bonus:      float  = 0.0

# ── SYNERGY（羁绊）────────────────────────────────────────────────────────────
## 所有炮台均需已放置才激活（支持 2/3/4 个）
@export var required_tower_ids: Array[String] = []
## 获得 buff 的炮台 tower_id 列表；空时仅看 target_tower_id
## 若 target_tower_id 也为空则 buff 全场
@export var target_tower_ids: Array[String] = []
