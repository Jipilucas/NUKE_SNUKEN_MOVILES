class_name ComandoEsconderse
extends Command

## Comando para ordenar al sapo regresar a esconderse en su cueva.
func execute(actor: Node) -> void:
	if actor.has_method("esconderse"):
		await actor.esconderse()

func get_command_name() -> String:
	return "Esconderse en la cueva"
