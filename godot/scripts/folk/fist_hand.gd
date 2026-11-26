class_name FistHand
extends SkeletonModifier3D
## A closed fist round a handle (the player: the tools weren't in his hand): the Meshy rigs have no finger bones, so the
## open hand can't curl. While on, after the clip has posed him, the hand bone is drawn in a little toward the wrist
## (its straight fingers shortened) and a made fist (Avatar.fist) wraps the haft over them; off, the hand is itself.

var bone := -1
var on := false
var k := 0.45
var _was := false

func _process_modification_with_delta(_delta: float) -> void: _fist()
func _process_modification() -> void: _fist()

func _fist() -> void:
	var sk := get_skeleton()
	if sk == null or bone < 0: return
	if on: sk.set_bone_pose_scale(bone, sk.get_bone_rest(bone).basis.get_scale() * k); _was = true
	elif _was: sk.set_bone_pose_scale(bone, sk.get_bone_rest(bone).basis.get_scale()); _was = false
