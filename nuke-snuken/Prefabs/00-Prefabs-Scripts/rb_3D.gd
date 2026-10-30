extends RigidBody3D


var vector : Vector3 = Vector3.ZERO

func _physics_process(delta: float) -> void:
	move_and_collide(vector)
	
