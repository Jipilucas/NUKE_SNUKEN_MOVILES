# res://Scripts/Player.gd
extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@onready var camera: Camera3D = $CameraPivot/Camera3D

func _enter_tree() -> void:
	# El servidor asignará el peer_id como el nombre del nodo (ej: "1", "1726354")
	# Asignamos la autoridad del nodo a ese peer_id
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	# Solo activamos la cámara si esta ventana es la dueña de este jugador
	
	if is_multiplayer_authority():
		camera.current = true
	else:
		camera.current = false

func _physics_process(delta: float) -> void:
	# REGLA DE ORO: Si no soy la autoridad de este personaje, no leo inputs locales
	if not is_multiplayer_authority():
		return

	# Gravedad estándar
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Salto
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Input de movimiento (WASD / Flechas)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
