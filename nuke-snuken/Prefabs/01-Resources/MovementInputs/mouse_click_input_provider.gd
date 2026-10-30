extends MovementInputProvider
class_name MouseClickInputProvider

## Proveedor de entrada basado en click / arrastre con el mouse sobre el terreno 3D.

@export_enum("Click Izquierdo:1", "Click Derecho:2") var mouse_button: int = MOUSE_BUTTON_LEFT
## Si es true, solo apunta mientras se mantenga presionado el botón. Si es false, un solo click establece el rumbo.
@export var requiere_mantener_presionado: bool = true #Si se activa entonces WASD no funciona correctamente.
## Distancia mínima para no producir giros erráticos al hacer click encima del propio personaje.
@export var distancia_muerta: float = 0.5

var _last_target_dir: Vector3 = Vector3.ZERO
var _has_valid_target: bool = false

func get_target_direction(body: CharacterBody3D) -> Vector3:
	var pressed: bool = Input.is_mouse_button_pressed(mouse_button)
	
	if pressed:
		var dir := _obtener_direccion_desde_cursor(body)
		if dir.length_squared() > 0.001:
			_last_target_dir = dir
			_has_valid_target = true
			return _last_target_dir
	
	if not requiere_mantener_presionado and _has_valid_target:
		return _last_target_dir
		
	return Vector3.ZERO

func is_active(_body: CharacterBody3D) -> bool:
	if requiere_mantener_presionado:
		return Input.is_mouse_button_pressed(mouse_button)
	return _has_valid_target or Input.is_mouse_button_pressed(mouse_button)

func _obtener_direccion_desde_cursor(body: CharacterBody3D) -> Vector3:
	var viewport := body.get_viewport()
	if not viewport:
		return Vector3.ZERO
	var camara := viewport.get_camera_3d()
	if not camara:
		return Vector3.ZERO
		
	var mouse_pos := viewport.get_mouse_position()
	var rayo_origen := camara.project_ray_origin(mouse_pos)
	var rayo_dir := camara.project_ray_normal(mouse_pos)
	
	var plano := Plane(Vector3.UP, body.global_position.y)
	var impacto = plano.intersects_ray(rayo_origen, rayo_dir)
	
	if impacto:
		var target_point: Vector3 = impacto
		target_point.y = body.global_position.y
		var diff := target_point - body.global_position
		if diff.length() >= distancia_muerta:
			return diff.normalized()
			
	return Vector3.ZERO
