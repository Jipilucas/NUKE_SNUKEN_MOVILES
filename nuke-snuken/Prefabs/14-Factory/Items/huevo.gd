extends ItemVisual
class_name Huevo

@onready var huevomodel: MeshInstance3D = get_node_or_null("Circle_013") as MeshInstance3D
@onready var pintas: MeshInstance3D = get_node_or_null("Circle_014") as MeshInstance3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void: 
	_hacer_materiales_unicos()

## Duplica los materiales de las mallas para que sean únicos de esta instancia en memoria.
## Esto evita que animaciones que alteran el material (como la emisión) afecten
## a otros huevos en la escena que comparten el mismo archivo de material (.tres).
func _hacer_materiales_unicos() -> void:
	if huevomodel:
		var mat: Material = huevomodel.get_surface_override_material(0)
		if mat:
			huevomodel.set_surface_override_material(0, mat.duplicate())
		elif huevomodel.material_override:
			huevomodel.material_override = huevomodel.material_override.duplicate()
			
	if pintas:
		var mat: Material = pintas.get_surface_override_material(0)
		if mat:
			pintas.set_surface_override_material(0, mat.duplicate())
		elif pintas.material_override:
			pintas.material_override = pintas.material_override.duplicate()

func despawn_animation_play() -> void:
	if animation_player and animation_player.has_animation("consumir"):
		animation_player.play("consumir")
