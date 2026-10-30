class_name ComandoAtacar
extends Command

## Comando para ordenar al sapo ejecutar su ataque de área a su alrededor.
func execute(actor: Node) -> void:
	if actor.has_method("atacar_area"):
		await actor.atacar_area()

func get_command_name() -> String:
	return "Atacar en área"
