extends RigidBody3D

@export_category("Components")
@export var movement_component : RigidMovementComponent3D
# Componente de apuntado con el mouse

@export_category("Nodes")
@export var ground_raycast : RayCast3D

@export_category("Properties")
@export var display_name : String = "RigidCharac"


func _ready() -> void:
	print("Personaje RigidBody creado: ", display_name)
	# Bloquear rotaciones en X y Z para mantener el personaje de pie
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	can_sleep = false
	
	if ground_raycast == null and has_node("GroundRayCast3D"):
		ground_raycast = $GroundRayCast3D


func _physics_process(delta: float) -> void:
	if movement_component:
		linear_velocity = movement_component.calculate_velocity(
			linear_velocity,
			is_on_floor(),
			transform.basis,
			delta
		)


func is_on_floor() -> bool:
	if ground_raycast:
		return ground_raycast.is_colliding()
	return false
