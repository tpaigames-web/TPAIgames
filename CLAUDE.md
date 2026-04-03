# 阿福守农场 — Claude Code Guidelines

Mandatory coding guidelines for this Godot 4.6 tower defense game.

## Project Overview
- Engine: Godot 4.6 (GDScript)
- Target: Android mobile, 1080×1920 portrait
- Architecture: Data-driven + Service layer + Signal-driven UI

---

## CRITICAL — 硬性禁令

以下规则为绝对禁令，违反任何一条都可能导致游戏崩溃、数据丢失或用户体验严重受损。

### NEVER: 绕过服务层
```
NEVER call enemy.take_damage() or enemy._try_apply_effect() directly.
WHY: 绕过 CombatService/EffectService 会跳过护甲计算、闪避判定、伤害数字显示、效果免疫检查。
所有可能出现的 bug 都极难追踪，因为伤害管道被分成了两条路径。
```
- **All damage** MUST go through `CombatService.deal_damage()`
- **All effects** MUST go through `EffectService.apply_single_effect()`

### NEVER: 编辑未读过的文件
```
NEVER edit a file you haven't read in this session.
WHY: 凭记忆或幻觉修改文件，改出来的内容和实际代码对不上，
轻则语法错误（如上次 dlg 变量残留导致整个 BattleScene 无法加载），
重则覆盖用户正在编辑的工作。
```

### NEVER: 画蛇添足
```
NEVER add features, refactors, or "improvements" beyond what was asked.
WHY: 一个小修改不需要顺手把旁边也重做一遍。额外的改动引入额外的风险，
而且用户没有预期这些变化，review 时容易漏过。
```
- 不要加没被要求的东西
- 不要为不可能发生的情况做预防，只在真正需要的边界做校验
- 三行重复的内容，好过一个过早的抽象

### NEVER: 润色或隐瞒
```
NEVER embellish results or hide what you didn't do.
WHY: 说"看起来没问题"不等于验证过。用户信任你的汇报来做决策，
不准确的汇报会导致 bug 流入生产环境。
```
- 做过的步骤就说做过，没做过的就说没做过
- 不要暗示做过了实际没做的验证
- 事情确实做好了，也不要加一堆没必要的免责声明

### NEVER: 甩锅思考
```
NEVER write "根据你的调查结果去处理" to a sub-agent.
WHY: 这等于把判断也甩出去了。你自己要先消化信息做出判断，
再给出明确的方向。子任务描述要像给一个刚走进房间的聪明同事写简报：
说清楚要做什么、为什么、已经排除了什么，给足上下文。
```

### DO NOT: 使用旧语法
```
DO NOT use onready, export without @, or any Godot 3 patterns.
WHY: 项目强制 Godot 4.6 语法，旧语法会导致 Parse Error，
整个脚本无法加载（所有功能失效，不只是那一行）。
```

---

## Autoload Singletons (12)

| Autoload | Responsibility | Layer |
|----------|---------------|-------|
| `GameManager` | Battle state, HP, gold, win/loss | State |
| `WaveManager` | Wave spawning from .tres, enemy data index | State |
| `BuildManager` | Tower placement validation, collision | State |
| `CollectionManager` | Tower unlocks, fragments, upgrade paths | State |
| `UserManager` | Player profile, global currency, level/XP | State |
| `SaveManager` | JSON serialization only | I/O |
| `TowerResourceRegistry` | Tower resource paths, rarity lookup | Registry |
| `SettingsManager` | Audio/video/quality settings, persist to JSON | Config |
| `CombatService` | Unified damage entry: dodge → mark → armor → HP → effects | Service |
| `EffectService` | Effect lifecycle: apply, stack, tick, immunity, query | Service |
| `AudioService` | SFX pool (16 concurrent), category cooldown | Service |
| `AdManager` | Rewarded ads integration | External |

### Layer Rules
- **State managers**: Own game data, emit signals on change
- **Services**: Stateless logic, called by game objects, never hold game state
- **I/O**: SaveManager only reads/writes, never holds state
- **NEVER cross-call** between State managers (use signals)

## Mandatory Coding Rules

### 1. All values must use @export — no hardcoded numbers
```gdscript
# WRONG
var max_hp = 100
# CORRECT
@export var max_hp: int = 100
```

### 2. Use Godot 4 syntax only
```gdscript
# WRONG
onready var label = $Label
# CORRECT
@onready var label: Label = $Label
@export var speed: float = 1.0
```

### 3. No hardcoded resource paths — use preload
```gdscript
const SCENE = preload("res://tower/Tower.tscn")
```

### 4. File naming conventions
- Scene/Class files: PascalCase (`TowerBase.gd`, `WaveManager.gd`)
- Variables/functions: snake_case (`max_hp`, `attack_speed`)
- Constants: UPPER_SNAKE_CASE (`MAX_GOLD`, `BASE_DAMAGE`)
- All filenames in English

### 5. CRITICAL: All damage through CombatService
```gdscript
CombatService.deal_damage(
    {"source_tower": self, "armor_penetration": 0,
     "pierce_giant": false, "ignore_dodge": false},
    enemy, dmg, effects
)
```

### 6. CRITICAL: All effects through EffectService
```gdscript
EffectService.apply_single_effect(enemy, effect, pierce_giant)
```

### 7. Data classes must extend Resource with class_name
```gdscript
class_name EnemyData extends Resource
@export var enemy_id: String = ""
@export var max_hp: int = 100
```

### 8. Use ObjectPool for high-frequency objects
```gdscript
var bullet = bullet_pool.acquire()
bullet._pool = bullet_pool
```

### 9. NEVER use Variant inference
```gdscript
# WRONG — Callable.call() returns Variant, := can't infer
var disc := some_callable.call(id)
# CORRECT — explicit type
var disc: float = some_callable.call(id)
```

### 10. Wave data must be external .tres files
- NEVER hardcode wave data in scripts

## Architecture: BattleScene Subsystems

BattleScene.gd is an **orchestrator** that delegates to 6 subsystems:

| Subsystem | File | Responsibility |
|-----------|------|---------------|
| `GlobalUpgradeSystem` | `scenes/battle/GlobalUpgradeSystem.gd` | Wave upgrade pool, selection, icons, synergy |
| `GameEndFlow` | `scenes/battle/GameEndFlow.gd` | Victory, defeat, revive, endless mode |
| `HeroSystem` | `scenes/battle/HeroSystem.gd` | Hero tower tracking, terrain, upgrades |
| `TowerCardPanel` | `scenes/battle/TowerCardPanel.gd` | Bottom tower card build/drag/affordability |
| `ItemPanel` | `scenes/battle/ItemPanel.gd` | Consumable items, drag-drop, mine spawn |
| `TowerUpgradePanel` | `scenes/battle/TowerUpgradePanel.gd` | Per-tower upgrade paths, BTD6 lock rules, sell |

### Subsystem Pattern
- Each extends `Node`, created via `set_script()` + `add_child()` in `_create_subsystems()`
- Dependencies injected via `init()` method
- Cross-subsystem communication via **signals** (not direct calls)
- BattleScene.tscn is **NEVER modified** — all subsystems are code-only Nodes

## Tower Architecture

Tower.gd organized with `#region` markers:
- CONSTANTS, VARIABLES, LIFECYCLE, STATS, COMBAT, TARGETING, GLOBAL_UPGRADES, VISUALS, PLACEMENT

### Hitscan vs Entity Bullets
- `TowerCollectionData.use_hitscan = true`: instant damage + Tween visual flight
- `use_hitscan = false` (default): entity Bullet.gd with ObjectPool

## Data Layer

```
data/
├── towers/          — 15 TowerCollectionData .tres
├── enemies/         — 18 EnemyData .tres
├── items/           — ItemData .tres
├── chests/          — ChestData .tres
├── heroes/          — HeroTerrainData .tres
├── global_upgrades/ — 100+ GlobalUpgradeData .tres
├── waves/           — 40 WaveConfig .tres + 10 tutorial
├── difficulty/      — 5 DifficultyTier .tres
└── bullet_effects/  — BulletEffect class definition
```

## Quality Settings
- Low: 30fps, no particles/shadows/VFX
- Medium: 60fps, particles + shadows + VFX
- High: 60fps + MSAA 2X

## Resolution & UI
- Viewport: 1080×1920 (portrait lock)
- Minimum touch target: 48px
- Sprite sizes: towers 128×128, enemies 128×128, UI icons 64×64, tiles 256×256
- ScrollContainer children: `mouse_filter = MOUSE_FILTER_PASS`

## 会话管理
- 每次会话开始时读取 docs/PROJECT_STATUS.md 了解项目进度
- 每次完成重要任务后更新 PROJECT_STATUS.md
- 可用 Agent: @project-manager @balance-analyst @translation-checker @code-reviewer @art-auditor @debug-loop @devil-advocate

## 功能完成后的 QA 流程
每次完成一个功能后，使用 @debug-loop 运行完整 QA 循环。
快速本地检查: `cd C:\sohai\ai && py qa_check.py`
