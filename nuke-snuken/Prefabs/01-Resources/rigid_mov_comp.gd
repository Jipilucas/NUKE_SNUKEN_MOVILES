extends Resource
class_name RigidMovementComponent3D

@export var speed : float = 6.0
@export var acceleration : float = 30.0
@export var deceleration : float = 30.0
@export var jump_velocity : float = 5.0

func calculate_velocity(current_velocity: Vector3, is_on_floor: bool, basis: Basis, delta: float) -> Vector3:
	var vel = current_velocity
	
	# Salto: en RigidBody3D la gravedad la maneja el motor de fisicas en el eje Y.
	# Solo sobreescribimos la componente vertical cuando salta en el suelo.
	if Input.is_action_just_pressed("jump") and is_on_floor:
		vel.y = jump_velocity
		
	# Direccion segun la orientacion del personaje
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Movimiento y desaceleracion horizontal
	if direction:
		vel.x = move_toward(vel.x, direction.x * speed, acceleration * delta)
		vel.z = move_toward(vel.z, direction.z * speed, acceleration * delta)
	else:
		vel.x = move_toward(vel.x, 0.0, deceleration * delta)
		vel.z = move_toward(vel.z, 0.0, deceleration * delta)
		
	return vel
