# res://Prefabs/14-Factory/Fabrica.gd
@abstract
class_name FabricaAbstracta
extends Node3D

@export var spawn_path : Node3D

## Escena genérica del ItemWorld (la misma para todas las fábricas)
@export var escena_base_item: PackedScene = preload("res://Prefabs/14-Factory/14- Composite_Factory/Item.tscn")

## Método abstracto que cada fábrica concreta implementa para decir QUÉ item produce
@abstract
func obtener_item_data() -> ItemData

## Método plantilla (Template Method) que crea y ensambla el producto
func fabricar() -> ItemWorld:
		# Solo el servidor spawnea en red
	if not multiplayer.is_server():
		return null
		
	if not escena_base_item:
		push_error("Fabrica: No se ha asignado escena_base_item.")
		return null
		
	var item_data: ItemData = obtener_item_data()
	if not item_data:
		push_error("Fabrica: No se devolvió ningún ItemData.")
		return null
		
	# 1. Instanciar el contenedor físico
	var nuevo_item: ItemWorld = escena_base_item.instantiate() as ItemWorld
	
	# 2. Inyectar la receta y la ruta de red
	nuevo_item.data = item_data
	nuevo_item.data_path = item_data.resource_path
	
	return nuevo_item

## Spawnearlo físicamente en el mundo respetando las reglas de Godot
func spawn_en_pos(posicion: Vector3) -> ItemWorld:
	
	# Solo el servidor spawnea en red
	if not multiplayer.is_server():
		return null
		
	var item: ItemWorld = fabricar()
	
	if item:
		var destino = spawn_path if spawn_path else get_parent()
		destino.add_child(item, true) # true fuerza un nombre legible para el spawner
		item.global_position = posicion
		#print("Fabrica: Item spawneado exitosamente en ", posicion)
	else:
		push_error("Fabrica: No se pudo fabricar el item.")
	return item
	
func spawn_en_nodo(nodo: Node3D) -> ItemWorld:
	# Importante: para que MultiplayerSpawner replique el nodo en red, 
	# el item DEBE ser hijo directo de spawn_path, no del nodo marcador.
	return spawn_en_pos(nodo.global_position)
