class_name ComandoEsperar
extends Command

## Comando para ordenar una espera/pausa de duración configurable.
@export var duracion: float = 1.0

func _init(p_duracion: float = 1.0) -> void:
	duracion = p_duracion

func execute(actor: Node) -> void:
	if actor.has_method("esperar"):
		await actor.esperar(duracion)
	elif actor.is_inside_tree():
		await actor.get_tree().create_timer(duracion).timeout

func get_command_name() -> String:
	return "Esperar (%.1fs)" % duracion
