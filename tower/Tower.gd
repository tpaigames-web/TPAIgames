extends Area2D

@export var tower_data: Resource
@export var upgrade_options: Array[PackedScene]
@export var special_effect: Script

@onready var attack_range = $AttackRange

var can_place: bool = true
var is_preview: bool = true
var attack_timer: float = 0.0


func _ready():
	monitoring = true
	monitorable = true
	
	if tower_data:
		apply_tower_data()


func apply_tower_data():
	attack_range.set_range(tower_data.attack_range)


func _process(delta):

	if is_preview:
		_update_can_place()
		return

	# 攻击逻辑
	attack_timer += delta
	
	if attack_timer >= tower_data.attack_speed:
		attack_timer = 0.0
		
		var target = attack_range.get_target()
		if target:
			target.take_damage(tower_data.damage)


func _update_can_place():

	var overlapping = get_overlapping_areas()
	can_place = true

	for area in overlapping:
		if area.is_in_group("block") \
		or area.is_in_group("path") \
		or area.is_in_group("tower"):
			can_place = false
			break

	queue_redraw()


func _draw():

	if not is_preview:
		return

	var color = Color(0,1,0,0.4) if can_place else Color(1,0,0,0.4)
	draw_circle(Vector2.ZERO, attack_range.attack_radius, color)
