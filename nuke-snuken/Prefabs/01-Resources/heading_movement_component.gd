extends CharacterMovementComponent3D
class_name HeadingMovementComponent3D

## Componente de movimiento por orientación ("Norte").
## Mueve al CharacterBody3D en línea recta hacia donde está mirando (-basis.z).
## Delega la obtención de rumbos a un MovementInputProvider y la física de giro a una RotationStrategy.

@export_category("Componentes de Dirección y Rotación")
@export var input_provider: MovementInputProvider
@export var rotation_strategy: RotationStrategy

@export_category("Comportamiento de Avance")
## Si es true, el jugador avanza constantemente en línea recta hacia su Norte (Snake clásico).
## Si es false, solo avanza mientras exista entrada activa.
@export var avance_automatico: bool = true
## Permite saltar con la acción "jump"
@export var habilitar_salto: bool = true
## Permite acelerar con la acción "run" (Shift)
@export var habilitar_correr: bool = true

func _init() -> void:
	if not input_provider:
		input_provider = HybridInputProvider.new()
	if not rotation_strategy:
		rotation_strategy = LimitedAngleRotationStrategy.new()

## Ejecuta la lógica física de movimiento y rotación.
## Mantiene compatibilidad con la firma de CharacterMovementComponent3D.
func process_movement(body: CharacterBody3D, _local_movement: bool = false, delta: float = 0.0) -> void:
	if not is_instance_valid(body):
		return

	# 1. En el aire: aplicar gravedad
	if not body.is_on_floor():
		body.velocity += body.get_gravity() * delta

	# 2. Salto en el suelo
	if habilitar_salto and body.is_on_floor() and Input.is_action_just_pressed("jump"):
		body.velocity.y = jump_velocity

	# 3. Lectura de Input y Actualización de Rotación ("Norte")
	var has_input: bool = false
	if input_provider:
		var target_dir: Vector3 = input_provider.get_target_direction(body)
		has_input = input_provider.is_active(body) and target_dir.length_squared() > 0.001
		if has_input and rotation_strategy:
			body.rotation.y = rotation_strategy.calculate_yaw(body.rotation.y, target_dir, delta)

	# 4. Cálculo de Velocidad en Línea Recta (hacia donde apunta el Norte)
	var forward_dir: Vector3 = -body.global_transform.basis.z
	forward_dir.y = 0.0
	if forward_dir.length_squared() > 0.001:
		forward_dir = forward_dir.normalized()
	else:
		forward_dir = Vector3.FORWARD

	var current_speed: float = walk_speed
	if habilitar_correr and Input.is_action_pressed("run"):
		current_speed = run_speed

	# 5. Aplicar traslación horizontal
	if avance_automatico or has_input:
		body.velocity.x = forward_dir.x * current_speed
		body.velocity.z = forward_dir.z * current_speed
	else:
		body.velocity.x = move_toward(body.velocity.x, 0.0, current_speed)
		body.velocity.z = move_toward(body.velocity.z, 0.0, current_speed)
