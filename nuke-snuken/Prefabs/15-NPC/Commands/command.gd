class_name Command
extends Resource

## Interfaz base para el Patrón de Comandos.
## Encapsula una acción o petición como un objeto independiente y desacoplado.

## Ejecuta la orden sobre el actor objetivo.
## Admite ser asíncrono (corrutina con await) para acciones que toman tiempo.
func execute(_actor: Node) -> void:
	pass

## Devuelve el nombre descriptivo del comando para depuración o UI.
func get_command_name() -> String:
	return "Command"
