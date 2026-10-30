extends MovementInputProvider
class_name HybridInputProvider

## Proveedor híbrido que evalúa múltiples fuentes de entrada de forma concurrente:
## 1. Stick Virtual (Touch Mobile)
## 2. Teclado (WASD)
## 3. Mouse (Click en el mapa)

@export var wasd_provider: WASDInputProvider = null
@export var mouse_provider: MouseClickInputProvider = null
@export var stick_provider: TouchStickInputProvider = null

func _init() -> void:
	pass

func get_target_direction(body: CharacterBody3D) -> Vector3:
	if not wasd_provider:
		wasd_provider = WASDInputProvider.new()
	if not mouse_provider:
		mouse_provider = MouseClickInputProvider.new()
	if not stick_provider:
		stick_provider = TouchStickInputProvider.new()
	
	# 1. Prioridad: Stick Virtual si el usuario está tocando la pantalla
	if stick_provider and stick_provider.is_active(body):
		var dir := stick_provider.get_target_direction(body)
		if dir.length_squared() > 0.001:
			return dir

	# 2. Prioridad: Teclas WASD
	if wasd_provider and wasd_provider.is_active(body):
		var dir := wasd_provider.get_target_direction(body)
		if dir.length_squared() > 0.001:
			return dir

	# 3. Prioridad: Click de Mouse en el mapa
	if mouse_provider and mouse_provider.is_active(body):
		var dir := mouse_provider.get_target_direction(body)
		if dir.length_squared() > 0.001:
			return dir

	return Vector3.ZERO

func is_active(body: CharacterBody3D) -> bool:
	if stick_provider and stick_provider.is_active(body):
		return true
	if wasd_provider and wasd_provider.is_active(body):
		return true
	if mouse_provider and mouse_provider.is_active(body):
		return true
	return false
