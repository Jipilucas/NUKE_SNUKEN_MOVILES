extends Resource
class_name ObjectPool

@export var scene: PackedScene
@export var cant_inicial: int = 10

var object_pool: Array[Node3D] = []
var _inicializado: bool = false

## Prepara la cantidad inicial de objetos asignándoles un nodo padre
func inicializar(padre_contenedor: Node) -> void:
	if _inicializado or not scene:
		if not scene:
			print("No hay escena para el pool")
		return
	_inicializado = true
	print("cargando pool")
	for i in cant_inicial:
		var nuevo_obj = scene.instantiate() as Node3D
		if nuevo_obj:
			padre_contenedor.add_child(nuevo_obj)
			add_to_pool(nuevo_obj)

## Extrae un objeto disponible del pool (o crea uno nuevo si está vacío)
func pull_from_pool(padre_fallback: Node = null) -> Node3D:
	var obj: Node3D = null
	
	# Buscar el último elemento válido
	while not object_pool.is_empty():
		var candidato = object_pool.pop_back()
		if is_instance_valid(candidato):
			obj = candidato
			break
			
	# Si no había disponibles o eran inválidos, instanciar uno nuevo
	if obj == null:
		if not scene:
			push_error("ObjectPool: No hay PackedScene asignada.")
			return null
		obj = scene.instantiate() as Node3D
		if padre_fallback and obj.get_parent() == null:
			padre_fallback.add_child(obj)
	
	# Reactivar objeto
	obj.show()
	obj.set_process(true)
	obj.set_physics_process(true)
	
	if obj is RigidBody3D:
		obj.freeze = false
		obj.linear_velocity = Vector3.ZERO
		obj.angular_velocity = Vector3.ZERO
		
	return obj

## Devuelve el objeto al pool y desactiva su procesamiento y colisiones
func add_to_pool(object: Node3D) -> void:
	if not is_instance_valid(object):
		return
		
	object.set_process(false)
	object.set_physics_process(false)
	
	if object is RigidBody3D:
		object.freeze = true
		object.linear_velocity = Vector3.ZERO
		object.angular_velocity = Vector3.ZERO
	
	object.hide()
	object_pool.append(object)
