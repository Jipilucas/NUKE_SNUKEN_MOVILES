extends CharacterBody3D
class_name Player_MP

@export_category("Components")
@export var movement_component : CharacterMovementComponent3D
@export var aim_component : MouseAimComponent3D
#@export var snake_component : SnakeBodyComponent3D
@export var snake_component : MPSnakeBodyComponent3D


@export_category("Attachments")
@export var weapon : Weapon  # O arrastrar el nodo Weapon1 desde el inspector


@export_category("Propierties")
@export var modo_Singleplayer : bool = false
@export var id_jugador: int = 0
@export var cantidad_cuerpos: int = 0:
	set(val):
		cantidad_cuerpos = val
		if is_node_ready():
			_sincronizar_segmentos_locales()
@export var push_force: float = 1.0  # Fuerza con la que empuja objetos
@export var movimiento_local: bool = false # false = Global (tipo Twin-Stick), true = Propio eje


@onready var camera: Camera3D = $Seguimiento/Camera3D


func _enter_tree():
	# Setea la autoridad del peer basándose en el ID asignado al nodo
	set_multiplayer_authority(name.to_int())
	# ServerSynchronizer siempre debe tener autoridad 1 (el Servidor) para replicar estado de juego
	if has_node("ServerSynchronizer"):
		$ServerSynchronizer.set_multiplayer_authority(1)

func _ready() -> void:
	if has_node("ServerSynchronizer"):
		$ServerSynchronizer.set_multiplayer_authority(1)
	print("Personaje creado: ", self.name)
	#Conecta la señal del Gestor de Datos para saber si murio un pj.
	GestorDeDatosPjs.jugador_murio.connect(_on_jugador_murio)
	_sincronizar_segmentos_locales()

#region Camera Set
	if is_multiplayer_authority():
		if camera:
			camera.current = true
	elif not multiplayer.is_server():
		# Si este personaje es remoto y somos un cliente, solicitamos al dueño su historial de trayectoria para desplegar su cuerpo al instante
		if multiplayer.has_multiplayer_peer():
			solicitar_historial_snake.rpc_id.call_deferred(get_multiplayer_authority())
#endregion



func _physics_process(delta: float) -> void:
	# 1. Movimiento, Input y Acciones: SOLO para la autoridad local
	if is_multiplayer_authority() or modo_Singleplayer:
		#region Movement
		if movement_component:
			movement_component.process_movement(self, movimiento_local, delta)
		move_and_slide()
		#endregion
		#region Empujar
		empujar()
		#endregion
		#region Apuntado
		if aim_component and not (movement_component is HeadingMovementComponent3D):
			aim_component.actualizar_rotacion(self, delta)
		#endregion
		#region Disparo
		if weapon:
			if Input.is_action_pressed("shoot_1"):
				weapon.shoot()
		#endregion
	
	# 2. Actualización del Cuerpo Snake: SE EJECUTA EN TODAS LAS MÁQUINAS
	# (Cada cliente simula los eslabones siguiendo la cabeza, tanto local como sincronizada)
	#region CuerpoSnake
	if snake_component and snake_component is MPSnakeBodyComponent3D:
		snake_component.actualizar(self, delta)
	#endregion


## Asegura que la cantidad de eslabones físicos instanciados coincida con cantidad_cuerpos (sincronizada en red)
func _sincronizar_segmentos_locales() -> void:
	if not snake_component or not (snake_component is MPSnakeBodyComponent3D):
		return
	var actuales: int = snake_component.obtener_cantidad_cuerpos()
	while actuales < cantidad_cuerpos:
		snake_component.agregar_cuerpo(self)
		actuales += 1
	while actuales > cantidad_cuerpos:
		snake_component.quitar_cuerpo()
		actuales -= 1

## Agrega un nuevo segmento de cuerpo (autoritativo en servidor, replicado por ServerSynchronizer)
func agregar_cuerpo(cant:int=1) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	cantidad_cuerpos += cant

## Quita el último segmento de cuerpo antes de la cola
func quitar_cuerpo(cant:int = 1) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if cantidad_cuerpos > 0:
		cantidad_cuerpos -= cant
	if cantidad_cuerpos < 0:
		cantidad_cuerpos = 0

func empujar():
	# Empuje de objetos físicos (RigidBody3D)
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is RigidBody3D:
			# Empujar en la dirección opuesta a la normal del choque
			#collider.apply_central_impulse(-collision.get_normal() * push_force)
			collider.apply_force(-collision.get_normal() * push_force)

#region Sincronización de Historial Snake (Despliegue al entrar)
## El cliente recién conectado le pide al dueño de este personaje su historial de trayectoria
@rpc("any_peer", "reliable")
func solicitar_historial_snake() -> void:
	if not is_multiplayer_authority():
		return
	var remitente: int = multiplayer.get_remote_sender_id()
	if snake_component and snake_component is MPSnakeBodyComponent3D:
		var historial: PackedVector3Array = snake_component.obtener_historial_empaquetado()
		recibir_historial_snake.rpc_id(remitente, historial)

## El cliente recibe el historial y lo vuelca a su componente local para desapilar los eslabones
@rpc("authority", "reliable")
func recibir_historial_snake(historial: PackedVector3Array) -> void:
	if snake_component and snake_component is MPSnakeBodyComponent3D:
		snake_component.establecer_historial_empaquetado(historial)
#endregion

#El jugador se fija si la señal que recibe le corresponde a él, por su ID.
func _on_jugador_murio(id: int) -> void:
	if int(name) != id:
		return
	_morir()

func _morir() -> void:
	print(self.name, " ha muerto!")
	queue_free()
