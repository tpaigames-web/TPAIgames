# 阿福守农场 — Claude Code Guidelines

Mandatory coding guidelines for this Godot 4.6 tower defense game.

## Project Overview
- Engine: Godot 4.6 (GDScript)
- Target: Android mobile, 1080×1920 portrait
- Architecture: Data-driven + Service layer + Signal-driven UI

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
- **Never cross-call** between State managers (use signals)
- **All damage** must go through `CombatService.deal_damage()`
- **All effects** must go through `EffectService.apply_single_effect()`

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

### 5. All damage through CombatService
```gdscript
# WRONG — direct call
enemy.take_damage_from_bullet(dmg, effects)

# CORRECT — through service
CombatService.deal_damage(
    {"source_tower": self, "armor_penetration": 0,
     "pierce_giant": false, "ignore_dodge": false},
    enemy, dmg, effects
)
```

### 6. All effects through EffectService
```gdscript
# WRONG — direct apply
enemy._try_apply_effect(effect)

# CORRECT — through service
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
# Bullets use ObjectPool (acquire/release pattern)
var bullet = bullet_pool.acquire()
bullet._pool = bullet_pool  # enable auto-release
# Bullet calls _return_to_pool() instead of queue_free()
```

### 9. Variant inference prohibition
```gdscript
# WRONG — Callable.call() returns Variant, := can't infer
var disc := some_callable.call(id)

# CORRECT — explicit type
var disc: float = some_callable.call(id)
```

### 10. Wave data must be external .tres files
- All wave compositions in `data/waves/wave_XX.tres` (WaveConfig resource)
- Difficulty tiers in `data/difficulty/tier_X.tres` (DifficultyTier resource)
- Never hardcode wave data in scripts

## Architecture: BattleScene Subsystems

BattleScene.gd (~990 lines) is an **orchestrator** that delegates to 6 subsystems:

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
- BattleScene.tscn is **never modified** — all subsystems are code-only Nodes

## Tower Architecture

Tower.gd (~920 lines) organized with `#region` markers:
- **CONSTANTS** — ABILITY_MAP, BULLET_SCENE
- **VARIABLES** — @export, buff fields, stats, hero fields
- **LIFECYCLE** — _ready, apply_tower_data, _process
- **STATS** — damage/speed/range breakdowns, effective calculations
- **COMBAT** — _fire_at, _fire_hitscan, ability system, spawn_bullet_at
- **TARGETING** — get_enemies_in_range, get_nearby_towers
- **GLOBAL_UPGRADES** — apply_global_buffs, _upgrade_matches_tower
- **VISUALS** — buff icons, range flash, _draw
- **PLACEMENT** — _update_can_place, _on_tower_input

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
- `SettingsManager.set_quality(0/1/2)` — Low/Medium/High presets
- Low: 30fps, no particles, no shadows, no hit VFX
- Medium: 60fps, particles + shadows + VFX
- High: 60fps + MSAA 2X

## Resolution & UI
- Viewport: 1080×1920 (portrait lock)
- Minimum touch target: 48px
- Sprite sizes: towers 128×128, enemies 128×128, UI icons 64×64, tiles 256×256
- ScrollContainer children: `mouse_filter = MOUSE_FILTER_PASS` (prevent drag swallow)
