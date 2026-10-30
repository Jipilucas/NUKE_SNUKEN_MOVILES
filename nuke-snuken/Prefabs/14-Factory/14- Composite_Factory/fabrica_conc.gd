# res://Prefabs/14-Factory/FabricaDeBananas.gd
class_name Fabrica
extends FabricaAbstracta

## Puedes asignarle el recurso BananaData.tres desde el Inspector
@export var item_data: ItemData

func obtener_item_data() -> ItemData:
	return item_data
