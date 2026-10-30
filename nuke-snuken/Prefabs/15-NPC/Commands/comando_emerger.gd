class_name ComandoEmerger
extends Command

## Comando para ordenar al sapo salir de su escondite/cueva hacia el exterior.
func execute(actor: Node) -> void:
	if actor.has_method("emerger"):
		await actor.emerger()

func get_command_name() -> String:
	return "Emerger de la cueva"
