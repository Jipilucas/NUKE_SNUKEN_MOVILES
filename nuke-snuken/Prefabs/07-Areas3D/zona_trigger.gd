extends Area3D

func _ready() -> void:
	# Conectamos las señales por código (o desde la pestaña Nodo del editor)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	
func _on_body_entered(body: Node3D) -> void:
	print("Entró en trigger: ", body.name)
	
	#TEST
	if body is Player:
		body.agregar_cuerpo()
	if body is Player_Physical:
		body.agregar_cuerpo()
		
func _on_body_exited(body: Node3D) -> void:
	print("Salió del trigger: ", body.name)
