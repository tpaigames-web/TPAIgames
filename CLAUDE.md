# 阿福守农场 — Claude Code Guidelines

This file provides mandatory coding guidelines for Claude when working on this Godot 4.6 tower defense game.

## Project Overview
- Engine: Godot 4.6 (GDScript)
- Target: Mobile, 1080×1920 portrait
- Architecture: Data-driven with Autoload singletons + Resource files

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
# WRONG (GDScript 3)
onready var label = $Label
export var speed = 1.0

# CORRECT (Godot 4)
@onready var label: Label = $Label
@export var speed: float = 1.0
```

### 3. No hardcoded resource paths — use preload
```gdscript
# WRONG
var scene = load("res://tower/Scarecrow.tscn")

# CORRECT
const SCARECROW_SCENE = preload("res://tower/Scarecrow.tscn")
```

### 4. File naming conventions
- Scene/Class files: PascalCase (e.g. `TowerBase.gd`, `WaveManager.gd`)
- Variables/functions: snake_case (e.g. `max_hp`, `attack_speed`)
- Constants: UPPER_SNAKE_CASE (e.g. `MAX_GOLD`, `BASE_DAMAGE`)
- All filenames must be in English

### 5. Strict layer separation — never cross-call these managers
| Manager | Responsibility |
|---------|---------------|
| `GameManager` | Battle state, HP, win/loss logic, battle gold |
| `WaveManager` | Wave spawning, enemy data index |
| `BuildManager` | Tower placement validation, collision |
| `CollectionManager` | Tower unlocks, fragments, upgrade paths |
| `UserManager` | Player profile, global currency, level/XP |
| `SaveManager` | JSON serialization only |

### 6. Data classes must extend Resource with class_name
```gdscript
# CORRECT pattern for data resources
class_name TowerData
extends Resource

@export var tower_id: String = ""
@export var damage: float = 10.0
```

### 7. Support future object pooling
- Enemies and bullets must be spawned via factory methods
- Do not instantiate scenes directly in game logic
- Keep spawn/despawn interface clean for future pool integration

## Architecture Patterns in Use
- **Factory pattern**: `TowerFactory.gd`, `EnemyFactory.gd` with `spawn_()` methods
- **Signal-driven UI**: UI listens to manager signals, never polls
- **Resource files**: All game data in `.tres` files under `data/`

## Resolution & UI
- Viewport: 1080×1920 (portrait lock)
- Minimum touch target: 44px
- Sprite sizes: towers 128×128, enemies 128×128, UI icons 64×64, tiles 256×256
