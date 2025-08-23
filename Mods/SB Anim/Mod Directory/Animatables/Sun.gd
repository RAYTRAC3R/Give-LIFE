extends Node3D

enum BonePreset {
	HAIR_NO_GRAVITY,
	HAIR,
	SLOW_HAIR_NO_GRAVITY,
	SLOW_HAIR,
	ANIMATRONIC_MOVEMENT_LIGHT,
	ANIMATRONIC_MOVEMENT_MEDIUM,
	ANIMATRONIC_MOVEMENT_HEAVY,
}

# Define bones and presets here
@export var bone_config := {
	"hair": BonePreset.HAIR_NO_GRAVITY,
	"pigtail 0 a": BonePreset.HAIR_NO_GRAVITY,
	"pigtail 1 a": BonePreset.HAIR_NO_GRAVITY,
	"pigtail 2 a": BonePreset.HAIR,
	"pigtail 0 b": BonePreset.HAIR_NO_GRAVITY,
	"pigtail 1 b": BonePreset.HAIR_NO_GRAVITY,
	"pigtail 2 b": BonePreset.HAIR,
	"pigtail 0 c": BonePreset.HAIR_NO_GRAVITY,
	"pigtail 1 c": BonePreset.HAIR_NO_GRAVITY,
	"pigtail 2 c" : BonePreset.HAIR,
	"feather 0 a r": BonePreset.SLOW_HAIR,
	"feather 1 a r": BonePreset.SLOW_HAIR,
	"feather 0 b r": BonePreset.SLOW_HAIR,
	"feather 1 b r": BonePreset.SLOW_HAIR,
	"feather 0 c r": BonePreset.SLOW_HAIR,
	"feather 1 c r": BonePreset.SLOW_HAIR,
	"feather 0 d r": BonePreset.SLOW_HAIR,
	"feather 1 d r": BonePreset.SLOW_HAIR,
	"feather 0 e r": BonePreset.SLOW_HAIR,
	"feather 1 e r": BonePreset.SLOW_HAIR,
	"feather 0 f r": BonePreset.SLOW_HAIR,
	"feather 1 f r": BonePreset.SLOW_HAIR,
	"feather 0 a l": BonePreset.SLOW_HAIR,
	"feather 1 a l": BonePreset.SLOW_HAIR,
	"feather 0 b l": BonePreset.SLOW_HAIR,
	"feather 1 b l": BonePreset.SLOW_HAIR,
	"feather 0 c l": BonePreset.SLOW_HAIR,
	"feather 1 c l": BonePreset.SLOW_HAIR,
	"feather 0 d l": BonePreset.SLOW_HAIR,
	"feather 1 d l": BonePreset.SLOW_HAIR,
	"feather 0 e l": BonePreset.SLOW_HAIR,
	"feather 1 e l": BonePreset.SLOW_HAIR,
	"feather 0 f l": BonePreset.SLOW_HAIR,
	"feather 1 f l": BonePreset.SLOW_HAIR,
	"tail 0 up": BonePreset.SLOW_HAIR,
	"tail 1 up": BonePreset.SLOW_HAIR,
	"tail 2 up": BonePreset.SLOW_HAIR,
	"tail 0 down": BonePreset.SLOW_HAIR,
	"tail 1 down": BonePreset.SLOW_HAIR,
	"tail 2 down": BonePreset.SLOW_HAIR,
	"tail 0 r": BonePreset.SLOW_HAIR,
	"tail 1 r": BonePreset.SLOW_HAIR,
	"tail 2 r": BonePreset.SLOW_HAIR,
	"tail 0 l": BonePreset.SLOW_HAIR,
	"tail 1 l": BonePreset.SLOW_HAIR,
	"tail 2 l": BonePreset.SLOW_HAIR,
	"jaw": BonePreset.ANIMATRONIC_MOVEMENT_LIGHT,
	"eyebrow_r": BonePreset.ANIMATRONIC_MOVEMENT_LIGHT,
	"eyebrow_l": BonePreset.ANIMATRONIC_MOVEMENT_LIGHT,
	"head rotate": BonePreset.ANIMATRONIC_MOVEMENT_MEDIUM,
	"arm r": BonePreset.ANIMATRONIC_MOVEMENT_HEAVY,
	"arm l": BonePreset.ANIMATRONIC_MOVEMENT_HEAVY,
	"forearm r": BonePreset.ANIMATRONIC_MOVEMENT_LIGHT,
	"arm mech bend l": BonePreset.ANIMATRONIC_MOVEMENT_LIGHT,
	"hand 0 r": BonePreset.ANIMATRONIC_MOVEMENT_LIGHT,
	"hand 0 l": BonePreset.ANIMATRONIC_MOVEMENT_LIGHT,
	"apron r": BonePreset.SLOW_HAIR,
	"apron": BonePreset.SLOW_HAIR,
	"apron l": BonePreset.SLOW_HAIR,
	"spine": BonePreset.ANIMATRONIC_MOVEMENT_HEAVY,
}
var currentPhysicsToggle = true
var skeleton: Skeleton3D = null

func _ready():
	add_to_group("SettingsReceivers")
	skeleton = find_skeleton(self)
	if skeleton == null:
		push_error("No Skeleton3D found in children!")
		return

	for bone_name in bone_config.keys():
		var preset = bone_config[bone_name]
		apply_physics_bone_to(bone_name, preset)

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node

	for child in node.get_children():
		if child is Node:
			var result = find_skeleton(child)
			if result != null:
				return result
	return null

func apply_physics_bone_to(bone_name: String, preset: BonePreset) -> void:
	var bone_index = skeleton.find_bone(bone_name)
	if bone_index == -1:
		push_warning("Bone not found: %s" % bone_name)
		return

	var bone_physics = DMWBWiggleRotationModifier3D.new()
	bone_physics.bone_name = bone_name
	set_preset_parameters(bone_physics, preset)

	skeleton.add_child(bone_physics)
	bone_physics.owner = get_parent()

func set_preset_parameters(pb: DMWBWiggleRotationModifier3D, preset: BonePreset) -> void:
	pb.properties = DMWBWiggleRotationProperties3D.new()
	match preset:
		BonePreset.HAIR:
			pb.properties.angular_damp = 8.0
			pb.properties.spring_freq = 3.0
			pb.properties.gravity = Vector3(0,-9.81,0)
		BonePreset.SLOW_HAIR:
			pb.properties.angular_damp = 3
			pb.properties.spring_freq = 2.0
			pb.properties.gravity = Vector3(0,-9.81,0)
		BonePreset.HAIR_NO_GRAVITY:
			pb.properties.angular_damp = 8.0
			pb.properties.spring_freq = 3.0
		BonePreset.SLOW_HAIR_NO_GRAVITY:
			pb.properties.angular_damp = 1.5
			pb.properties.spring_freq = 2.0			
		BonePreset.ANIMATRONIC_MOVEMENT_LIGHT:
			pb.properties.angular_damp = 1.0
			pb.properties.swing_span = 0.01
			pb.properties.spring_freq = 1
		BonePreset.ANIMATRONIC_MOVEMENT_MEDIUM:
			pb.properties.swing_span = 0.25
			pb.properties.spring_freq = 2
		BonePreset.ANIMATRONIC_MOVEMENT_HEAVY:
			pb.properties.swing_span = 0.5
			pb.properties.spring_freq = 3


# Set of node names to hide when toggling
var sun_names = ["Rays"]
var moon_names = ["Hat"]

var sun_texture = load("res://Mods/SB Anim/Custom Assets/Materials/Sun.tres")
var moon_texture = load("res://Mods/SB Anim/Custom Assets/Materials/Moon.tres")

# Internal toggle state
var moon_toggle := false

func _input(event):
	if event.is_action_pressed("Test Visibility"): # Make sure 'Test Visibility' is mapped to 'H'
		moon_toggle = !moon_toggle
		_toggle_visibility_recursive(self)

func _toggle_visibility_recursive(node: Node):
	for child in node.get_children():
		if child is Node3D:
			if moon_toggle:
				child.visible = not sun_names.has(child.name)
			else:
				child.visible = not moon_names.has(child.name)
		if child is MeshInstance3D:
			if moon_toggle:
				child.set_surface_override_material(0, moon_texture)
			else:
				child.set_surface_override_material(0, sun_texture)
		# Recursively process all children
		_toggle_visibility_recursive(child)
		
func on_settings_applied(settings: Dictionary):
	if currentPhysicsToggle != settings["physics_bones"]:
		set_physics_bones_enabled(settings["physics_bones"])
	

func set_physics_bones_enabled(enable: bool):
	currentPhysicsToggle = enable
	for child in skeleton.get_children(true):
		if child is DMWBWiggleRotationModifier3D or child is DMWBWigglePositionModifier3D:
			child.active = enable
