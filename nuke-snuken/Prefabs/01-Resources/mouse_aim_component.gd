
extends Resource
class_name MouseAimComponent3D

@export var rotacion_suave : bool = true
@export var velocidad_rotacion : float = 18.0
@export var frente_en_z_positivo : bool = true  # true si el frente del modelo mira a +Z

func actualizar_rotacion(nodo: Node3D, delta: float) -> void:
	var camara := nodo.get_viewport().get_camera_3d()
	if not camara:
		return
		
	var mouse_pos := nodo.get_viewport().get_mouse_position()
	var rayo_origen := camara.project_ray_origin(mouse_pos)
	var rayo_dir := camara.project_ray_normal(mouse_pos)
	
	var plano := Plane(Vector3.UP, nodo.global_position)
	var impacto = plano.intersects_ray(rayo_origen, rayo_dir)
	
	if impacto:
		var target : Vector3 = impacto
		target.y = nodo.global_position.y
		
		if nodo.global_position.distance_squared_to(target) > 0.05:
			if rotacion_suave:
				var target_trans := nodo.global_transform.looking_at(target, Vector3.UP, frente_en_z_positivo)
				nodo.global_basis = nodo.global_basis.slerp(target_trans.basis, velocidad_rotacion * delta)
			else:
				nodo.look_at(target, Vector3.UP, frente_en_z_positivo)
