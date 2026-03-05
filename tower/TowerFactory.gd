extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func spawn_tower(tower_data):

	var tower = tower_data.tower_scene.instantiate()
	tower.tower_data = tower_data
	add_child(tower)
