class_name StudentFigure
extends Node3D
## A classmate sitting at their desk, working on the same test: head down over the paper, the
## writing hand moving, now and then shifting in the chair, turning a page or glancing at the
## clock. The body is a CC0 Quaternius base character (assets/third_party/quaternius) posed in
## code; clothes are painted on by student_figure.gdshader from a mask built once per body.
## Node origin = the floor under the middle of the chair seat; the student faces -Z.

const Q := "res://assets/third_party/quaternius/"
const BODIES := {"m": "Superhero_Male_FullBody", "f": "Superhero_Female_FullBody"}
const HAIRS := {"m": ["Hair_SimpleParted", "Hair_SimpleParted", "Hair_Buzzed"], "f": ["Hair_Long", "Hair_Long", "Hair_Buns"]}
const SHADER := preload("res://scenes/room/student_figure.gdshader")
const SEAT_H := 0.47           # top of the chair seat
const SHIRTS := [Color("#3B4A63"), Color("#6E2B34"), Color("#2F3A2F"), Color("#C9C6BE"), Color("#1F1F22"),
	Color("#8A8F96"), Color("#4C6A8C"), Color("#3E5F46"), Color("#5B4A7A"), Color("#2C5E5A")]
const PANTS := [Color("#2E3E5C"), Color("#1D2230"), Color("#3A3A3D"), Color("#7C6A50"), Color("#4A5878")]
const SHOES := [Color("#E9E7E2"), Color("#2A2A2C"), Color("#1E2433"), Color("#B8BCC4")]
const SKIN := [Color(1.0, 1.0, 1.0), Color(0.86, 0.74, 0.66), Color(0.66, 0.5, 0.4), Color(0.48, 0.35, 0.28), Color(0.95, 0.86, 0.8)]
const HAIR_TINTS := [Color(0.25, 0.17, 0.11), Color(0.12, 0.1, 0.09), Color(0.55, 0.4, 0.25), Color(0.75, 0.6, 0.38), Color(0.4, 0.2, 0.1)]

static var _masked: Dictionary = {}   # body name -> ArrayMesh with the clothing mask in COLOR
static var _fabric_s: Texture2D
static var _fabric_p: Texture2D

var update_interval: float = 1.0 / 30.0  # LOD: far students update less often
var _sk: Skeleton3D
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0
var _accum: float = 0.0
var _bones: Dictionary = {}
var _write_speed: float = 1.0
var _right_handed: bool = true
var _lean: float = 0.0
var _glance: float = 0.0       # 0..1 looking up at the clock
var _next_glance: float = 0.0
var _shift: float = 0.0        # 0..1 sitting back / stretching
var _next_shift: float = 0.0
var _pause: float = 0.0        # 0..1 stopped writing to think
var _next_pause: float = 0.0


func setup(seed: int) -> void:
	_rng.seed = seed
	var sex := "f" if _rng.randf() < 0.5 else "m"
	var body := BODIES[sex] as String
	var path := Q + body + ".gltf"
	if not ResourceLoader.exists(path):
		return
	var root: Node3D = (load(path) as PackedScene).instantiate()
	add_child(root)
	root.rotation.y = PI  # the models face +Z; classmates face the front (-Z)
	var s := _rng.randf_range(0.9, 0.99) * (0.95 if sex == "f" else 1.0)
	# The base bodies are superhero-built; teenagers are slimmer.
	var slim := (0.84 if sex == "m" else 0.93) * _rng.randf_range(0.96, 1.04)
	root.scale = Vector3(s * slim, s, s * (slim + 0.04))
	_sk = root.find_children("*", "Skeleton3D", true, false)[0]
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.name.begins_with("Super"):
			_dress(m, body)
		elif m.name == "Eyebrows":
			_tint_hair(m, HAIR_TINTS[_rng.randi() % HAIR_TINTS.size()])
	_add_hair(sex)
	for b in ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "thigh_l", "thigh_r", "calf_l", "calf_r",
			"foot_l", "foot_r", "ball_l", "ball_r", "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r",
			"lowerarm_l", "lowerarm_r", "hand_l", "hand_r"]:
		_bones[b] = _sk.find_bone(b)
	_right_handed = _rng.randf() > 0.12
	_write_speed = _rng.randf_range(0.7, 1.4)
	_lean = _rng.randf_range(-0.3, 1.0)
	_t = _rng.randf_range(0.0, 100.0)
	_next_glance = _rng.randf_range(8.0, 50.0)
	_next_shift = _rng.randf_range(15.0, 70.0)
	_next_pause = _rng.randf_range(3.0, 15.0)
	# Sit so the pelvis rests on the chair seat.
	var pelvis_y := _sk.get_bone_global_rest(_bones.pelvis).origin.y * s
	root.position.y = SEAT_H + 0.06 - pelvis_y
	_pose()


## Clothes: a per-vertex mask from the rest pose (shirt on the torso and down the arm, trousers on
## the legs, shoes on the feet), shared by every student using the same body.
func _dress(m: MeshInstance3D, body: String) -> void:
	var src := m.mesh
	if not _masked.has(body):
		_masked[body] = _masked_mesh(src, _sk, body)
	var masked: Mesh = _masked[body]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var orig := src.surface_get_material(0) as BaseMaterial3D
	if orig:
		mat.set_shader_parameter("skin_tex", orig.albedo_texture)
		mat.set_shader_parameter("skin_rough", orig.roughness_texture)
	mat.set_shader_parameter("skin_tint", SKIN[_rng.randi() % SKIN.size()])
	mat.set_shader_parameter("shirt", SHIRTS[_rng.randi() % SHIRTS.size()])
	mat.set_shader_parameter("pants", PANTS[_rng.randi() % PANTS.size()])
	mat.set_shader_parameter("shoes", SHOES[_rng.randi() % SHOES.size()])
	mat.set_shader_parameter("sleeve", [0.38, 0.62, 0.95, 0.95][_rng.randi() % 4])
	if _fabric_s == null:
		_fabric_s = _load_tex("cotton_jersey")
		_fabric_p = _load_tex("denim_fabric")
	mat.set_shader_parameter("shirt_fabric", _fabric_s)
	mat.set_shader_parameter("pants_fabric", _fabric_p)
	m.mesh = masked
	m.material_override = mat


static func _load_tex(id: String) -> Texture2D:
	var p := "res://assets/third_party/polyhaven/textures/%s/%s_diff.jpg" % [id, id]
	return load(p) if ResourceLoader.exists(p) else null


static func _masked_mesh(src: Mesh, sk: Skeleton3D, body: String) -> ArrayMesh:
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var pelvis := sk.get_bone_global_rest(sk.find_bone("pelvis")).origin.y
	var neck := sk.get_bone_global_rest(sk.find_bone("neck_01")).origin.y
	var shoulder := absf(sk.get_bone_global_rest(sk.find_bone("upperarm_l")).origin.x)
	var hand := absf(sk.get_bone_global_rest(sk.find_bone("hand_l")).origin.x)
	var ankle := sk.get_bone_global_rest(sk.find_bone("foot_l")).origin.y
	var colors := PackedColorArray()
	colors.resize(verts.size())
	for i in verts.size():
		var v := verts[i]
		var ax := absf(v.x)
		# Crew neck: the shirt covers the shoulders and stops in a ring around the neck.
		var collar := v.y < neck + 0.035 and (Vector2(v.x, v.z + 0.01).length() > 0.072 or v.y < neck - 0.03)
		var torso := 1.0 if (v.y > pelvis - 0.02 and collar and ax < shoulder + 0.05) else 0.0
		var arm := 0.0
		if v.y > pelvis + 0.2 and ax >= shoulder + 0.05:
			arm = clampf((ax - shoulder) / (hand - shoulder), 0.002, 1.0)  # 0 at the shoulder, 1 at the wrist
			if ax > hand - 0.01:
				arm = 0.0  # hands stay bare
		var legs := 1.0 if (v.y <= pelvis + 0.1 and v.y > ankle + 0.02 and ax < shoulder + 0.08) else 0.0
		var feet := 1.0 if v.y <= ankle + 0.02 else 0.0
		colors[i] = Color(torso, legs, feet, arm)
	arrays[Mesh.ARRAY_COLOR] = colors
	for c in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		arrays[c] = null
	var flags := 0
	var bones: Variant = arrays[Mesh.ARRAY_BONES]
	if bones != null and (bones as PackedInt32Array).size() == verts.size() * 8:
		flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	out.resource_name = body + "_dressed"
	return out


func _tint_hair(m: MeshInstance3D, tint: Color) -> void:
	var src := m.get_active_material(0) as BaseMaterial3D
	if src == null:
		return
	var mat := src.duplicate() as BaseMaterial3D
	mat.albedo_color = tint * 1.6
	m.material_override = mat


## Hair is a separate CC0 mesh skinned to the head bone: move it onto this body's skeleton.
func _add_hair(sex: String) -> void:
	var options: Array = HAIRS[sex]
	var id: String = options[_rng.randi() % options.size()]
	var path := Q + id + ".gltf"
	if not ResourceLoader.exists(path):
		return
	var scene: Node3D = (load(path) as PackedScene).instantiate()
	var tint: Color = HAIR_TINTS[_rng.randi() % HAIR_TINTS.size()]
	if id == "Hair_Buzzed":
		tint = HAIR_TINTS[_rng.randi() % 2]  # light buzz cuts read as bald from behind
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.owner = null
		m.get_parent().remove_child(m)
		_sk.add_child(m)
		m.skeleton = NodePath("..")
		_tint_hair(m, tint)
	scene.free()


func _process(delta: float) -> void:
	if _sk == null:
		return
	_t += delta
	_accum += delta
	_update_moods(delta)
	if _accum < update_interval:
		return
	_accum = 0.0
	_pose()


func _update_moods(delta: float) -> void:
	_next_glance -= delta
	if _next_glance <= 0.0:
		_next_glance = _rng.randf_range(25.0, 90.0)
		var t := create_tween()
		t.tween_property(self, "_glance", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
		t.tween_interval(_rng.randf_range(0.8, 2.0))
		t.tween_property(self, "_glance", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	_next_shift -= delta
	if _next_shift <= 0.0:
		_next_shift = _rng.randf_range(40.0, 120.0)
		var t := create_tween()
		t.tween_property(self, "_shift", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
		t.tween_interval(_rng.randf_range(1.5, 4.0))
		t.tween_property(self, "_shift", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	_next_pause -= delta
	if _next_pause <= 0.0:
		_next_pause = _rng.randf_range(4.0, 18.0)
		var t := create_tween()
		t.tween_property(self, "_pause", 1.0, 0.4)
		t.tween_interval(_rng.randf_range(1.0, 5.0))
		t.tween_property(self, "_pause", 0.0, 0.4)


## Seated, leaning over the desk, writing. Directions are in the model's own space (it faces +Z,
## its left is +X).
func _pose() -> void:
	_sk.reset_bone_poses()
	var breathe := sin(_t * 1.7) * 0.012
	var lean := clampf(0.22 + _lean * 0.1 - _shift * 0.25 - _glance * 0.08, -0.1, 0.45)
	# Legs: thighs forward, shins down, a little apart.
	_aim("thigh_l", "calf_l", Vector3(0.12, -0.06, 1.0))
	_aim("thigh_r", "calf_r", Vector3(-0.1, -0.06, 1.0))
	_aim("calf_l", "foot_l", Vector3(0.05, -1.0, 0.18))
	_aim("calf_r", "foot_r", Vector3(-0.03, -1.0, 0.1 + _shift * 0.3))
	_aim("foot_l", "ball_l", Vector3(0.05, -0.25, 1.0))
	_aim("foot_r", "ball_r", Vector3(-0.05, -0.25, 1.0))
	# Back bends toward the paper.
	_aim("spine_01", "spine_02", Vector3(0, 1.0, lean * 0.8 + breathe))
	_aim("spine_02", "spine_03", Vector3(0, 1.0, lean + breathe))
	_aim("spine_03", "neck_01", Vector3(0, 1.0, lean * 1.2))
	var look_down := lerpf(0.75, -0.15, _glance)
	_aim("neck_01", "Head", Vector3(sin(_t * 0.31) * 0.08, 1.0, look_down))
	_turn("Head", Vector3.RIGHT, lerpf(0.45, -0.15, _glance) + sin(_t * 0.23) * 0.04)
	# Arms forward onto the desk; the writing hand moves across the page.
	var w := _write_speed * (1.0 - _pause)
	var wx := sin(_t * 3.1 * w) * 0.05 + sin(_t * 0.4) * 0.08
	var wz := cos(_t * 2.3 * w) * 0.025
	var writing := "r" if _right_handed else "l"
	var resting := "l" if _right_handed else "r"
	var ws := -1.0 if writing == "r" else 1.0  # writing side sign in model X
	_aim("upperarm_" + writing, "lowerarm_" + writing, Vector3(ws * 0.25, -0.62, 0.75 - _shift * 0.2))
	_aim("lowerarm_" + writing, "hand_" + writing, Vector3(-ws * 0.55 + wx, -0.42, 0.9 + wz))
	_aim("upperarm_" + resting, "lowerarm_" + resting, Vector3(-ws * 0.28, -0.55, 0.8))
	_aim("lowerarm_" + resting, "hand_" + resting, Vector3(ws * 0.85, -0.3, 0.6))
	_turn("hand_" + writing, Vector3.FORWARD, ws * 0.6)


## Turn `bone` so the direction toward `child` points along `dir` (skeleton space).
func _aim(bone: String, child: String, dir: Vector3) -> void:
	var b: int = _bones.get(bone, -1)
	var c: int = _bones.get(child, -1)
	if b < 0 or c < 0:
		return
	var gp := _sk.get_bone_global_pose(b)
	var cur := (_sk.get_bone_global_pose(c).origin - gp.origin).normalized()
	var want := dir.normalized()
	if cur.dot(want) > 0.99999:
		return
	var q := Quaternion(cur, want)
	_sk.set_bone_global_pose(b, Transform3D(Basis(q) * gp.basis, gp.origin))


## Rotate `bone` about a skeleton-space axis.
func _turn(bone: String, axis: Vector3, angle: float) -> void:
	var b: int = _bones.get(bone, -1)
	if b < 0:
		return
	var gp := _sk.get_bone_global_pose(b)
	_sk.set_bone_global_pose(b, Transform3D(Basis(axis, angle) * gp.basis, gp.origin))
