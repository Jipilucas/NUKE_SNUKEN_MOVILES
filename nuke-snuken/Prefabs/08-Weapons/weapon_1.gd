extends Node3D
class_name Weapon
@export_category("Bullets")
#@export var bullet_scene : PackedScene
@export var bullets_pool : ObjectPool
@onready var bullet_container : Node3D = $BulletContainer
@onready var muzzle: Marker3D = $PuntoDisparo
@export_category("Parameters")
@export var bullet_speed_multiplier : float = 1
@export var bullet_damage_multiplier : float = 1
@export var cooldown : float = 0.25 # Segundos entre disparos


var puede_disparar : bool = true
var tiempo_recarga : float = 0.0


func _ready() -> void:
	if bullets_pool :
		#bullets_pool.scene = bullet_scene
		bullets_pool.inicializar(bullet_container)
		bullet_container.top_level = true
		print("bullet pool iniciado")
	pass
	

func _process(delta: float) -> void:
	if not puede_disparar:
		tiempo_recarga -= delta
		if tiempo_recarga <= 0:
			puede_disparar = true




func shoot() -> void:
	if not puede_disparar or not bullets_pool.scene:
		return
		
	puede_disparar = false
	tiempo_recarga = cooldown
	
	# 1. Obtener la bala (del pool si existe, o instanciándola)
	var b: Node3D
	if bullets_pool:
		b = bullets_pool.pull_from_pool(bullet_container)
	else:
		b = bullets_pool.scene.instantiate()
		get_tree().root.add_child(b)
	
	# 2. Calcular origen y vector de velocidad
	var origen: Vector3 = muzzle.global_position if muzzle else global_position
	var direccion: Vector3 = global_transform.basis.z.normalized()
	
	# 3. Inicializar la bala pasándole la referencia al pool
	if b is Bullet:
		b.danio = int(b.danio * bullet_damage_multiplier)
		var velocidad = direccion * (b.bullet_velocity * bullet_speed_multiplier)
		b.activar(origen, velocidad, bullets_pool)
	else:
		# Fallback por si b no hereda de Bullet
		b.global_position = origen
