class_name LopLegs
extends SkeletonModifier3D
## puppets.js `lop`: a lopsided beast, one side's legs drawn short after the walk clip has posed them. A modifier
## runs after the AnimationTree, as the page scales the bones after mixer.update. (The sidehill gouger, enemies.gd.)

var bones: PackedInt32Array = []
var k := 0.66

var runs := 0

func _process_modification_with_delta(_delta: float) -> void: _lop()
func _process_modification() -> void: _lop()

func _lop() -> void:
	runs += 1
	var sk := get_skeleton()
	if sk == null: return
	for b in bones: sk.set_bone_pose_scale(b, sk.get_bone_rest(b).basis.get_scale() * k)
