extends Node

@export_category("NPC Prefabs")
@export var item1_scene : PackedScene
@export var item2_scene : PackedScene
@export var item3_scene : PackedScene
@export var item4_scene : PackedScene
@export var item5_scene : PackedScene

@export_category("Config")
@export var spawn_point : Node3D
@export var cant : int = 30
@export var intervalo : float = 0.3


func _ready() -> void:
	pass
	
func esperar(time:int):
	await self.get_tree().create_timer(time).timeout

func _crear_comun() -> void :
	print("_crear_comun")
	if item1_scene != null:
		var item1 : Node3D = item1_scene.instantiate()
		item1.global_position = spawn_point.global_position
	pass
	
func _crear_cold() -> void :
	print("_crear_cold")
	if item2_scene != null:
		var item2 : Node3D = item2_scene.instantiate()
		item2.global_position = spawn_point.global_position
	pass
	
func _crear_fire() -> void :
	print("_crear_fire")
	if item3_scene != null:
		var item3 : Node3D = item3_scene.instantiate()
		item3.global_position = spawn_point.global_position
	pass
	
func _crear_lighting() -> void :
	print("_crear_lighting")
	if item4_scene != null:
		var npc_lighting : Node3D = item4_scene.instantiate()
		npc_lighting.global_position = spawn_point.global_position
	
func _crear_poison() -> void :
	print("_crear_poison")
	if item5_scene != null:
		var npc_poison : Node3D = item5_scene.instantiate()
		npc_poison.global_position = spawn_point.global_position
	
func _crear_random() -> void :
	print("random:")
	var random : int = randi_range(1,5)
	match random:
		1:
			_crear_comun()
		2:
			_crear_cold()
		3:
			_crear_fire()
		4:
			_crear_lighting()
		5:
			_crear_poison()
	pass
