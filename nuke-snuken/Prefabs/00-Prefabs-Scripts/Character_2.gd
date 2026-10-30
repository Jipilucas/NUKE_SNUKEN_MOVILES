extends CharacterBody3D
class_name Player_Physical

@export_category("Components")
@export var movement_component : CharacterMovementComponent3D
@export var aim_component : MouseAimComponent3D
#@export var snake_component : SnakeBodyComponent3D
@export var snake_joint : SnakeJointManager


@export_category("Attachments")
@export var weapon : Weapon  # O arrastrar el nodo Weapon1 desde el inspector


@export_category("Propierties")
@export var id_jugador: int = 0
@export var push_force: float = 1.0  # Fuerza con la que empuja objetos
@export var movimiento_local: bool = false # false = Global (tipo Twin-Stick), true = Propio eje


func _ready() -> void:
	print("Personaje creado: ", self.name)


func _physics_process(delta: float) -> void:
#Control de componente de movimiento
#region Movement
	if movement_component:
		movement_component.process_movement(self, movimiento_local, delta)
	move_and_slide()
#endregion
#region Empujar

#Llamada a la funcion de empujar
	empujar()
#endregion
#region Apuntado
	if aim_component:
			aim_component.actualizar_rotacion(self, delta)
#endregion
#region Disparo
	if weapon:
		if Input.is_action_pressed("shoot_1"):
			weapon.shoot()
			pass
#endregion
	
#region CuerpoSnake
	# Actualización del cuerpo tipo Snake
	if snake_joint:
		snake_joint.actualizar(self, delta)
#endregion


## Agrega un nuevo segmento de cuerpo entre la cabeza y la cola
func agregar_cuerpo() -> void:
	if snake_joint:
		snake_joint.agregar_cuerpo(self)

## Quita el último segmento de cuerpo antes de la cola
func quitar_cuerpo() -> void:
	if snake_joint:
		snake_joint.quitar_cuerpo(self)


func empujar():
	# Empuje de objetos físicos (RigidBody3D)
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is RigidBody3D:
			# Empujar en la dirección opuesta a la normal del choque
			#collider.apply_central_impulse(-collision.get_normal() * push_force)
			collider.apply_force(-collision.get_normal() * push_force)
