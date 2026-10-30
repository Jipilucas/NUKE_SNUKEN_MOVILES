extends Resource
class_name SnakeJointManager

## Administrador de cuerpo tipo "Snake" basado en físicas rígidas y Joints nativos (PinJoint3D).
##
## Características principales:
## 1. Conecta dinámicamente eslabones RigidBody3D detrás del CharacterBody3D (Player).
## 2. Los cuerpos intermedios y la cola usan por defecto los prefabs de 'Prefabs/11-Snake/'.
## 3. Inserta nuevos cuerpos entre el último cuerpo y la cola.
## 4. Permite quitar cuerpos dinámicamente reconectando la cola al eslabón previo.
## 5. Control total de parámetros de física y del Joint (bias, damping, impulse clamp) desde el Inspector.

# ==============================================================================
# SEÑALES
# ==============================================================================
signal cuerpo_agregado(cuerpo: RigidBody3D, indice: int)
signal cuerpo_eliminado(indice: int)
signal cola_creada(cola: RigidBody3D)
signal cantidad_cambiada(total: int)

# ==============================================================================
# ESCENAS Y CONFIGURACIÓN EXPORTADA
# ==============================================================================
@export_category("Escenas de Eslabones")
## Escena del cuerpo intermedio (asignada en el editor como PackedScene)
@export var cuerpo_rigido_scene: PackedScene

## Escena de la cola final (asignada en el editor como PackedScene)
@export var cola_rigida_scene: PackedScene


@export_category("Ajustes Físicos de Eslabones")
## Distancia inicial de separación entre eslabones al instanciarlos
@export_range(0.5, 4.0, 0.1) var distancia_separacion: float = 1.5

## Fricción lineal con el aire/suelo para evitar que reboten o vibren eternamente
@export var amortiguacion_lineal: float = 6.0

## Fricción angular para amortiguar giros excesivos sobre sí mismos
@export var amortiguacion_angular: float = 8.0

## Si es true, bloquea el eje vertical Y para que los eslabones no salten
@export var bloquear_eje_y: bool = false

## Si es true, instancia la cola automáticamente al inicializar
@export var crear_cola_al_iniciar: bool = true

@export_category("Ajustes del Joint (PinJoint3D)")
## Fuerza con la que el joint intenta mantener juntos los eslabones (0.1 = elástico, 0.9 = rígido)
@export_range(0.1, 1.0, 0.05) var joint_bias: float = 0.3

## Amortiguación de rebote del propio joint
@export_range(0.1, 10.0, 0.1) var joint_damping: float = 1.0

## Límite de impulso máximo del joint (0 = sin límite)
@export_range(0.0, 50.0, 0.5) var joint_impulse_clamp: float = 0.0

# ==============================================================================
# ESTADO EN TIEMPO DE EJECUCIÓN
# ==============================================================================
var cuerpos: Array[RigidBody3D] = []
var cola: RigidBody3D = null
var joints: Array[Joint3D] = []
var joint_cola: Joint3D = null

var _inicializado: bool = false
var _padre_mundo: Node = null


func _init() -> void:
	resource_local_to_scene = true


# ==============================================================================
# CICLO DE ACTUALIZACIÓN
# ==============================================================================

## Llamado en el _physics_process del CharacterBody3D
func actualizar(player: CharacterBody3D, _delta: float) -> void:
	if not is_instance_valid(player):
		return
	
	if not _inicializado:
		_inicializar(player)


func _inicializar(player: CharacterBody3D) -> void:
	_inicializado = true
	_padre_mundo = player.get_parent()
	if not _padre_mundo:
		_padre_mundo = player.get_tree().current_scene
	
	# Limpieza si el jugador sale del árbol de escena
	if not player.tree_exited.is_connected(limpiar):
		player.tree_exited.connect(limpiar)
	
	# Crear la cola inicial si está configurada
	if crear_cola_al_iniciar and cola_rigida_scene and not cola:
		_crear_cola(_padre_mundo, player)


# ==============================================================================
# AGREGAR Y QUITAR CUERPOS
# ==============================================================================

## Agrega un nuevo cuerpo rígido intercalándolo entre el cuerpo anterior y la cola
func agregar_cuerpo(player: CharacterBody3D) -> RigidBody3D:
	if not is_instance_valid(player):
		return null
	if not _inicializado:
		_inicializar(player)
	
	if not cuerpo_rigido_scene:
		push_warning("SnakeJointManager: No se ha asignado 'cuerpo_rigido_scene'.")
		return null
	
	var mundo := _padre_mundo if _padre_mundo else player.get_parent()
	
	# 1. Instanciar el nuevo RigidBody3D
	var nuevo_cuerpo := cuerpo_rigido_scene.instantiate() as RigidBody3D
	if not nuevo_cuerpo:
		push_warning("SnakeJointManager: 'cuerpo_rigido_scene' debe heredar de RigidBody3D.")
		return null
	
	_configurar_cuerpo_fisico(nuevo_cuerpo)
	
	# Determinar quién es el eslabón anterior (el último cuerpo o el propio jugador)
	var eslabon_anterior: PhysicsBody3D = player if cuerpos.is_empty() else cuerpos.back()
	
	# Posicionamiento inicial detrás del eslabón previo
	var dir_atras := eslabon_anterior.global_transform.basis.z.normalized()
	if dir_atras.length_squared() < 0.001:
		dir_atras = Vector3.BACK
	
	nuevo_cuerpo.global_transform.basis = eslabon_anterior.global_transform.basis
	nuevo_cuerpo.global_position = eslabon_anterior.global_position + dir_atras * distancia_separacion
	
	# Añadir al árbol ANTES de conectar los joints para que get_path() sea válido
	mundo.add_child(nuevo_cuerpo)
	
	# Exclusión mutua de colisiones para evitar fuerzas explosivas
	nuevo_cuerpo.add_collision_exception_with(eslabon_anterior)
	eslabon_anterior.add_collision_exception_with(nuevo_cuerpo)
	
	# 2. Crear el Joint que une el eslabón anterior con el nuevo cuerpo
	var nuevo_joint := PinJoint3D.new()
	nuevo_joint.global_position = (eslabon_anterior.global_position + nuevo_cuerpo.global_position) * 0.5
	_configurar_joint(nuevo_joint)
	mundo.add_child(nuevo_joint)
	
	nuevo_joint.node_a = eslabon_anterior.get_path()
	nuevo_joint.node_b = nuevo_cuerpo.get_path()
	
	cuerpos.append(nuevo_cuerpo)
	joints.append(nuevo_joint)
	
	# 3. Reconectar la cola al nuevo cuerpo (si la cola ya existía)
	if is_instance_valid(cola) and is_instance_valid(joint_cola):
		joint_cola.node_a = nuevo_cuerpo.get_path()
		joint_cola.node_b = cola.get_path()
		joint_cola.global_position = (nuevo_cuerpo.global_position + cola.global_position) * 0.5
		cola.add_collision_exception_with(nuevo_cuerpo)
		nuevo_cuerpo.add_collision_exception_with(cola)
	elif cola_rigida_scene and cola == null:
		_crear_cola(mundo, nuevo_cuerpo)
	
	var indice_nuevo := cuerpos.size() - 1
	cuerpo_agregado.emit(nuevo_cuerpo, indice_nuevo)
	cantidad_cambiada.emit(obtener_cantidad_segmentos())
	
	return nuevo_cuerpo


## Quita el último cuerpo intermedio antes de la cola y reconecta la cadena
func quitar_cuerpo(player: CharacterBody3D) -> bool:
	if cuerpos.is_empty():
		return false
	
	# 1. Extraer el último cuerpo y su joint
	var cuerpo_a_eliminar: RigidBody3D = cuerpos.pop_back()
	var joint_a_eliminar: Joint3D = joints.pop_back()
	
	if is_instance_valid(joint_a_eliminar):
		joint_a_eliminar.queue_free()
	
	if is_instance_valid(cuerpo_a_eliminar):
		cuerpo_a_eliminar.queue_free()
	
	# 2. Determinar el nuevo eslabón previo para la cola
	var nuevo_predecesor: PhysicsBody3D = player if cuerpos.is_empty() else cuerpos.back()
	
	# 3. Reconectar la cola al nuevo predecesor
	if is_instance_valid(cola) and is_instance_valid(joint_cola):
		joint_cola.node_a = nuevo_predecesor.get_path()
		joint_cola.node_b = cola.get_path()
		joint_cola.global_position = (nuevo_predecesor.global_position + cola.global_position) * 0.5
		cola.add_collision_exception_with(nuevo_predecesor)
		nuevo_predecesor.add_collision_exception_with(cola)
	
	cuerpo_eliminado.emit(cuerpos.size())
	cantidad_cambiada.emit(obtener_cantidad_segmentos())
	return true


## Elimina todos los cuerpos intermedios dejando únicamente la cola conectada al jugador
func quitar_todos_los_cuerpos(player: CharacterBody3D) -> void:
	while not cuerpos.is_empty():
		quitar_cuerpo(player)


# ==============================================================================
# GESTIÓN DE LA COLA
# ==============================================================================

## Crea la cola y la conecta al eslabón previo
func _crear_cola(mundo: Node, eslabon_previo: PhysicsBody3D) -> void:
	if not cola_rigida_scene:
		return
	
	cola = cola_rigida_scene.instantiate() as RigidBody3D
	if not cola:
		push_warning("SnakeJointManager: 'cola_rigida_scene' debe heredar de RigidBody3D.")
		return
	
	_configurar_cuerpo_fisico(cola)
	
	var dir_atras := eslabon_previo.global_transform.basis.z.normalized()
	if dir_atras.length_squared() < 0.001:
		dir_atras = Vector3.BACK
	
	cola.global_transform.basis = eslabon_previo.global_transform.basis
	cola.global_position = eslabon_previo.global_position + dir_atras * distancia_separacion
	mundo.add_child(cola)
	
	cola.add_collision_exception_with(eslabon_previo)
	eslabon_previo.add_collision_exception_with(cola)
	
	joint_cola = PinJoint3D.new()
	joint_cola.global_position = (eslabon_previo.global_position + cola.global_position) * 0.5
	_configurar_joint(joint_cola as PinJoint3D)
	mundo.add_child(joint_cola)
	
	joint_cola.node_a = eslabon_previo.get_path()
	joint_cola.node_b = cola.get_path()
	
	cola_creada.emit(cola)
	cantidad_cambiada.emit(obtener_cantidad_segmentos())


# ==============================================================================
# CONFIGURACIÓN INTERNA DE FÍSICA
# ==============================================================================

func _configurar_cuerpo_fisico(cuerpo: RigidBody3D) -> void:
	cuerpo.can_sleep = false
	if cuerpo.linear_damp <= 0.0:
		cuerpo.linear_damp = amortiguacion_lineal
	if cuerpo.angular_damp <= 0.0:
		cuerpo.angular_damp = amortiguacion_angular
	if bloquear_eje_y:
		cuerpo.axis_lock_linear_y = true


func _configurar_joint(joint: PinJoint3D) -> void:
	joint.exclude_nodes_from_collision = true
	joint.set_param(PinJoint3D.PARAM_BIAS, joint_bias)
	joint.set_param(PinJoint3D.PARAM_DAMPING, joint_damping)
	joint.set_param(PinJoint3D.PARAM_IMPULSE_CLAMP, joint_impulse_clamp)


# ==============================================================================
# CONSULTAS Y LIMPIEZA
# ==============================================================================

## Retorna la cantidad total de eslabones actuales (cuerpos + cola)
func obtener_cantidad_segmentos() -> int:
	var total := cuerpos.size()
	if is_instance_valid(cola):
		total += 1
	return total


## Devuelve una copia de la lista de cuerpos intermedios
func obtener_cuerpos() -> Array[RigidBody3D]:
	return cuerpos.duplicate()


## Devuelve el nodo de la cola física
func obtener_cola() -> RigidBody3D:
	return cola


## Limpia y destruye todos los cuerpos, joints y cola del mundo físico
func limpiar() -> void:
	for j in joints:
		if is_instance_valid(j):
			j.queue_free()
	joints.clear()
	
	for c in cuerpos:
		if is_instance_valid(c):
			c.queue_free()
	cuerpos.clear()
	
	if is_instance_valid(joint_cola):
		joint_cola.queue_free()
		joint_cola = null
	
	if is_instance_valid(cola):
		cola.queue_free()
		cola = null
	
	_inicializado = false
