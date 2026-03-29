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
## 动画帧资源（优先于 sprite_texture，循环播放）
@export var sprite_frames:    SpriteFrames
## 贴图显示大小（像素），0 = 使用默认值 80
@export var sprite_display_size: float = 0.0
## 贴图朝向偏移（度）：PathFollow2D 默认朝右(3点钟)，
## 若贴图朝下(6点钟) 填 90，朝上(12点钟) 填 -90，朝左(9点钟) 填 180
@export var sprite_rotation_offset: float = 0.0
@export var damage_to_player: int       = 1
@export var gold_reward:      int       = 5
@export var xp_reward:        int       = 5

# ── 类型标志 ──────────────────────────────────────────────────────────
## 飞行单位：只受飞行攻击类型的炮台伤害
@export var is_flying:           bool   = false
## 精英单位：用于老阿福"精英击杀+金币"等技能判定
@export var is_elite:            bool   = false
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
## 狂暴型：HP 降至阈值以下时速度提升（一次性触发）
@export var is_berserk:          bool   = false
## 狂暴触发 HP 比例（0.3 = HP 低于 30% 时触发）
@export var berserk_threshold:   float  = 0.3
## 狂暴速度加成比例（0.4 = +40% 速度）
@export var berserk_speed_bonus: float  = 0.5

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
## 护盾存在时免疫控制效果（犰狳专用）
@export var shield_grants_control_immune: bool = false

# ── 再生（毒蛙）─────────────────────────────────────────────────────
## 每秒回复 HP 量，0 = 无再生
@export var regen_per_second:  float  = 0.0

# ── 反制要点（供敌人指南显示）──────────────────────────────────────
@export var counter_strategy:  String = ""
