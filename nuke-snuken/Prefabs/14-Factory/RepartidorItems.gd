#===================== INTRO ==================
# Este script se encarga de instanciar items utilizando las fabricas


extends Node3D
class_name RepartidorItems
@export_category("Fabrica1")
@export var Fabrica1 : Fabrica
@export var Fabrica1_Spawns : Array[Node3D]
@export var tiempo_respawn_Fabrica1: float = 5.0

@export_category("Fabrica2")
@export var Fabrica2 : Fabrica
@export var Fabrica2_Spawns : Array[Node3D]
@export var tiempo_respawn_Fabrica2: float = 8.0

@export_category("Fabrica3")
@export var Fabrica3 : Fabrica
@export var Fabrica3_Spawns : Array[Node3D]
@export var tiempo_respawn_Fabrica3: float = 15.0

## Registro de ítems activos en cada punto de spawn (punto -> ItemWorld)
var _items_activos: Dictionary = {}

func _ready() -> void:
	# 1. Limpiamos cualquier modelo de previsualización que se haya colocado
	# en el editor dentro de los marcadores para diseñar el nivel visualmente.
	# Esto corre tanto en Host como en Cliente para dejar la escena limpia.
	limpiar_previsualizaciones_editor()
	
	# 2. NO spawneamos items aquí. En Godot, antes de pulsar Host o Join,
	# multiplayer.is_server() devuelve true por defecto, lo que causaría que el cliente
	# spawnee una copia local huérfana de los items que luego nunca se borraría.

func limpiar_previsualizaciones_editor() -> void:
	var todos_los_spawns: Array[Node3D] = []
	todos_los_spawns.append_array(Fabrica1_Spawns)
	todos_los_spawns.append_array(Fabrica2_Spawns)
	todos_los_spawns.append_array(Fabrica3_Spawns)
	
	for p in todos_los_spawns:
		if p is Node3D:
			for hijo in p.get_children():
				hijo.queue_free()

## Llamado exclusivamente por el Servidor/Host cuando se inicia la partida
func generar_todos_los_items() -> void:
	if not (multiplayer.has_multiplayer_peer() and multiplayer.is_server()):
		return
	llenar_usando(Fabrica1, Fabrica1_Spawns, tiempo_respawn_Fabrica1)
	llenar_usando(Fabrica2, Fabrica2_Spawns, tiempo_respawn_Fabrica2)
	llenar_usando(Fabrica3, Fabrica3_Spawns, tiempo_respawn_Fabrica3)

func llenar_usando(fabrica: Fabrica, spawns: Array[Node3D], tiempo_respawn: float) -> void:
	if not fabrica:
		push_error("RepartidorItems: No hay fabrica asignada.")
		return
	for p in spawns:
		if p is Node3D:
			_spawn_con_respawn(fabrica, p, tiempo_respawn)
		else:
			push_warning("RepartidorItems: Uno de los puntos de spawn es null.")

## Spawnea un item y programa su regeneración automática al ser consumido
func _spawn_con_respawn(fabrica: Fabrica, punto: Node3D, tiempo_cooldown: float) -> void:
	if not is_inside_tree() or not (multiplayer.has_multiplayer_peer() and multiplayer.is_server()):
		return
		
	# Si ya hay un ítem vivo en este punto, no creamos otro
	if punto in _items_activos and is_instance_valid(_items_activos[punto]):
		return
		
	var nuevo_item: ItemWorld = fabrica.spawn_en_pos(punto.global_position)
	if nuevo_item:
		_items_activos[punto] = nuevo_item
		# Al ser consumido con queue_free() en el servidor, emite tree_exited
		nuevo_item.tree_exited.connect(
			func(): _on_item_consumido(fabrica, punto, tiempo_cooldown),
			CONNECT_ONE_SHOT
		)

func _on_item_consumido(fabrica: Fabrica, punto: Node3D, tiempo_cooldown: float) -> void:
	_items_activos.erase(punto)
	
	if not is_inside_tree():
		return
		
	print("RepartidorItems: Item consumido en ", punto.name, ". Respawn en ", tiempo_cooldown, "s...")
	
	# Esperar el tiempo de cooldown configurado
	await get_tree().create_timer(tiempo_cooldown).timeout
	
	# Verificar que el servidor siga activo antes de respawnear
	if is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		print("RepartidorItems: Respawneando item en ", punto.name)
		_spawn_con_respawn(fabrica, punto, tiempo_cooldown)

## Método de consulta para saber si un punto específico tiene un item activo
func punto_esta_ocupado(punto: Node3D) -> bool:
	return punto in _items_activos and is_instance_valid(_items_activos[punto])
		
