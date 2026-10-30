extends Resource
class_name CharacterMovementComponent3D

@export var walk_speed : float = 5.0
@export var run_speed : float = 10.0
@export var jump_velocity : float = 4.5

# En vez de recibir 5 parámetros, recibe el cuerpo directamente
func process_movement(body: CharacterBody3D, local_movement: bool, delta: float) -> void:
	# 1. En el aire: aplicar gravedad y conservar la inercia (velocidad y dirección) del salto
	if not body.is_on_floor():
		body.velocity += body.get_gravity() * delta



	# 2. En el suelo: determinar velocidad y salto
	var actual_speed := walk_speed
	if Input.is_action_pressed("run"):
		actual_speed = run_speed

	if Input.is_action_just_pressed("jump"):
		body.velocity.y = jump_velocity

	# 3. Dirección y Orientación en el suelo
	var basis := body.transform.basis if local_movement else Basis.IDENTITY
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# 4. Modificar la velocidad del body solo mientras esté en el suelo
	if direction:
		body.velocity.x = direction.x * actual_speed
		body.velocity.z = direction.z * actual_speed
	else:
		body.velocity.x = move_toward(body.velocity.x, 0.0, actual_speed)
		body.velocity.z = move_toward(body.velocity.z, 0.0, actual_speed)
