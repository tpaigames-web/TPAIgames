extends Resource
class_name EnemyData

# ── 基础识别 ──────────────────────────────────────────────────────────
@export var enemy_id:         String    = ""
@export var display_name:     String    = ""
@export var display_emoji:    String    = "❓"

# ── 战斗数值 ──────────────────────────────────────────────────────────
@export var max_hp:           int       = 100
@export var move_speed:       float     = 100.0
@export var armor:            int       = 0
@export var sprite_texture:   Texture2D
@export var damage_to_player: int       = 1
@export var gold_reward:      int       = 5
@export var xp_reward:        int       = 5

# ── 类型标志 ──────────────────────────────────────────────────────────
## 飞行单位：只受飞行攻击类型的炮台伤害
@export var is_flying:           bool   = false
## 巨型单位：控制类效果（减速/定身）默认无效（BulletEffect.affects_giant=true 可例外）
@export var is_giant:            bool   = false
## 快速型：预留给 AttackRange 优先目标逻辑（后续扩展）
@export var is_fast:             bool   = false
## 治疗型：可为附近友军恢复 HP（预留）
@export var is_healer:           bool   = false
## 分裂型：死亡时生成若干小单位（预留）
@export var is_splitter:         bool   = false
## 免疫控制：减速 / 定身效果完全无效
@export var is_control_immune:   bool   = false
## 免疫DOT：燃烧 / 中毒 / 流血效果完全无效
@export var is_dot_immune:       bool   = false
## 狂暴型：HP 降至 30% 以下时速度提升50%（一次性触发）
@export var is_berserk:          bool   = false

# ── 冲锋行为（野猪 / 装甲野猪）────────────────────────────────────────
## 出生后冲锋持续时间（秒），0 = 无冲锋
@export var charge_duration:         float = 0.0
## 冲锋期间速度倍率（移动速度 × 此值）
@export var charge_speed_multiplier: float = 1.0

# ── 攻击免疫（狐狸首领）──────────────────────────────────────────────
## 每次受到攻击时的免疫概率 0.0~1.0
@export var attack_immunity_chance:  float = 0.0

# ── 召唤能力（蚁后 / 乌鸦王 / 森林之王）──────────────────────────────
## 召唤间隔秒数，0 = 不召唤
@export var spawn_interval:    float  = 0.0
## 召唤的敌人类型 id（对应 WaveManager.enemy_data_map 的 key）
@export var spawn_enemy_type:  String = ""
## 每次召唤数量
@export var spawn_count:       int    = 0

# ── 特殊位移（地鼠 / 巨型地鼠 / 大兔子）─────────────────────────────
## 遇到陷阱炮台时可位移跳过
@export var can_bypass_traps:  bool   = false

# ── 护盾（森林之王）──────────────────────────────────────────────────
## 触发护盾的 HP 比例（如 0.25 = HP 降至 25% 时触发），0 = 无护盾
@export var shield_threshold:  float  = 0.0
