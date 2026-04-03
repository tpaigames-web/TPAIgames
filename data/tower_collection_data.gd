class_name TowerCollectionData extends Resource

## 炮台的局外收藏数据（稀有度、属性、升级方向、碎片费用等）
## 修改炮台数据时，编辑对应的 .tres 文件即可。

@export var tower_id: String = ""
@export var display_name: String = ""
@export var tower_emoji: String = "?"       # 无图片时的 emoji 占位符

## 炮台专属场景（继承 Tower.tscn，含独立碰撞多边形）；null = 使用通用 Tower.tscn
@export var tower_scene: PackedScene

@export var icon_texture: Texture2D         # 兼容旧引用，保留不删

# ─── 图片分层（局外 / 局内双层）──────────────────────────────────────
## 局外展示图（宝箱开启 / 兵工厂 / 军火库），高清卡牌风格
@export var collection_texture: Texture2D
## 局内底部静态图层（炮台底座，不旋转）
@export var base_texture: Texture2D
## 局内攻击旋转图层（炮管/武器，朝向目标实时旋转）
@export var attack_texture: Texture2D
## 局内攻击旋转图层 — 射击状态（开火瞬间切换，无则复用 attack_texture）
@export var shoot_texture: Texture2D
## 非旋转塔 — 敌人进入范围时的准备状态纹理（无则保持 base_texture）
@export var ready_texture: Texture2D
## 动画帧资源（循环播放，优先于静态贴图；用于风车等需要动画的炮台）
@export var anim_frames: SpriteFrames
## 攻击时循环播放 attack_texture ↔ shoot_texture（用于播种机等需要攻击动画+旋转的塔）
@export var attack_anim_cycle: bool = false

## 稀有度：0=白 1=绿 2=蓝 3=紫 4=橙（与宝箱稀有度体系一致）
@export_enum("白", "绿", "蓝", "紫", "橙") var rarity: int = 0

# ─── 基础战斗属性（兵工厂 UI 展示用）─────────────────────────

## 基础伤害（每次攻击，0 = 纯功能型无伤害）
@export var base_damage: float = 10.0
## 攻击速度（次/秒，0 = 不主动攻击）
@export var attack_speed: float = 1.0
## 攻击射程（像素，0 = 直接放置于路面）
@export var attack_range: float = 200.0
## 放置费用（金币）
@export var placement_cost: int = 150

## 攻击目标类型：0=地面 1=空中 2=全部
@export_enum("地面", "空中", "全部") var attack_type: int = 0

## 放置碰撞圆半径（像素）；collision_polygon 为空时使用此值作圆形碰撞
@export var collision_radius: float = 50.0

## 手绘放置碰撞多边形（在 Inspector 中编辑顶点坐标，原点=炮台中心）
## 有顶点时优先使用多边形碰撞，为空则退回 collision_radius 圆形
@export var collision_polygon: PackedVector2Array = PackedVector2Array()

## 是否只能放在路面上（true = 草地/空地禁止放置；用于捕兽夹、带刺铁网等路面陷阱）
@export var place_on_path_only: bool = false

## 英雄炮台：每局限放 1 个，拥有独立等级系统（1–10）
@export var is_hero: bool = false

## 效果简述
@export_multiline var effect_description: String = ""

# ─── 子弹系统 ────────────────────────────────────────────────────────

## 子弹飞行速度（像素/秒）；0 = 瞬间命中（不生成子弹实体，直接结算伤害和效果）
@export var bullet_speed: float = 400.0

## Hitscan 模式：攻击立即判定伤害，视觉用 Tween 飞行动画（适合快速射击炮台）
@export var use_hitscan: bool = false

## 子弹携带的效果资源列表（BulletEffect .tres）
@export var bullet_effects: Array[BulletEffect] = []

## 子弹显示用的 emoji（无图片时展示）
@export var bullet_emoji: String = "⚫"

## 子弹场景（每个塔可指定自己的 .tscn；null = 使用默认 Bullet.tscn）
@export var bullet_scene: PackedScene

# ─── 升级方向（4个方向，每个5层）────────────────────────────

## 4个升级方向（TowerUpgradePath sub-resource）
@export var upgrade_paths: Array[TowerUpgradePath] = []

# ─── 解锁与碎片系统（原有字段保留）──────────────────────────

## 解锁所需玩家等级
@export var level_required: int = 1
## 解锁所需碎片数量
@export var unlock_fragments: int = 30
## 解锁所需金币
@export var unlock_gold: int = 500
## 各级升级所需碎片（下标0=升到2级，共5级升级）
@export var upgrade_fragments: Array[int] = [20, 40, 80, 160, 320]
## 各级升级所需金币
@export var upgrade_gold: Array[int] = [200, 400, 800, 1600, 3200]
## 最高等级（含初始1级）
@export var max_level: int = 6
## 在军火库中各刷新周期的购买价格（6h / 每日 / 每周）
@export var fragment_shop_price: Array[int] = [100, 200, 500]
