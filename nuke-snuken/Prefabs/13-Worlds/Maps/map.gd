extends Node3D
@export var enviroment : Environment
@onready var world_env : WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	if enviroment:
		world_env.environment = enviroment
