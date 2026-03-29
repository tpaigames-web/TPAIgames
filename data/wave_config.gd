class_name WaveConfig
extends Resource

@export var wave_number: int = 1
@export var wave_name: String = ""
@export var is_boss_wave: bool = false
## 每组格式：{ "type": "enemy_id", "count": int }
@export var groups: Array[Dictionary] = []
