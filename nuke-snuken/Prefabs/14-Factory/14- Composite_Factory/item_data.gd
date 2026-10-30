# res://Prefabs/01-Resources/item_data.gd
class_name ItemData
extends Resource

@export_group("Visuales")
@export var nombre: String = "Item"
## Modelo 3D completo en formato escena (.glb, .gltf, .tscn)
@export var modelo_escena: PackedScene
## Malla simple (.obj, BoxMesh, SphereMesh, etc.)
@export var modelo_mesh: Mesh
@export var material_override: Material
@export var escala_visual: Vector3 = Vector3.ONE

@export_group("Efecto")
@export var puntos: int = 10
@export var cura_vida: float = 0.0
@export var agrega_cuerpos : int =1

## Lógica polimórfica: qué le hace este item a quien lo agarra, pasando por la comprobación del servidor (en el script de item_world que es quien llama a este método).
func aplicar_efecto(actor: Node3D) -> void:
	# 1. Dá puntos si el item da al menos un punto.
	if puntos > 0:
		GestorDeDatosPjs.modificar_puntaje(int(actor.name), puntos)
	# 2. Cura al personaje si el item da al menos un punto de vida.
	if cura_vida > 0:
		GestorDeDatosPjs.modificar_vida(int(actor.name), int(cura_vida))
	# 3. Crecer serpiente si tiene el método
	if actor is Player_MP:
		if actor.has_method("agregar_cuerpo"):
			actor.agregar_cuerpo(agrega_cuerpos)
		
	print("Se aplicó efecto de: %s al jugador %s" % [nombre, actor.name])
	
