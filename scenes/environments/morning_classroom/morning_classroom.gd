class_name MorningClassroom
extends EnvironmentContract
## The Morning Classroom (spec §6.1): a 9 × 8 m room with a 2.9 m drop ceiling. Painted block
## walls, VCT floor, windows with venetian blinds on the left (-X), the whiteboard and the digital
## clock at the front (-Z), the door on the right. Furniture and props are CC0 models from
## Poly Haven (fetched by tools/fetch_assets.py); anything missing falls back to simple boxes.

const W := 9.0
const D := 8.0
const H := 2.9
const COLS := [-3.0, -1.5, 0.0, 1.5, 3.0]
const ROWS := [-1.6, -0.45, 0.7, 1.85, 3.0]
const PLAYER_COL := 1
const PLAYER_ROW := 2
const WINDOW_ZS := [-2.3, 0.0, 2.3]
const WINDOW_W := 1.9
const SILL_Y := 0.9
const WINDOW_TOP := 2.45

const PH := "res://assets/third_party/polyhaven/"
const TRIM := Color(0.86, 0.85, 0.82)

var sun: DirectionalLight3D
var world_env: WorldEnvironment
var desk_top_y: float = 0.75
var _fill_lights: Array[Light3D] = []
var _rng := RandomNumberGenerator.new()
var _paper_tex: Texture2D
var _grain: NoiseTexture2D
var _wall_mat: ShaderMaterial
var _desk_vscale: float = 1.0


func _init() -> void:
	_rng.seed = 1979
	_build_shell()
	_build_ceiling()
	_build_windows()
	_build_front()
	_build_right_wall()
	_build_back()
	_build_desks()
	_build_paths()
	_build_lighting()
	apply_preset("medium")


# --- Materials and models ----------------------------------------------------------------------

func _tex(id: String, map: String) -> Texture2D:
	var p := PH + "textures/%s/%s_%s.jpg" % [id, id, map]
	return load(p) if ResourceLoader.exists(p) else null


## A tiling PBR material in world space (so boxes of any size keep the same texel density).
func _pbr(id: String, tint: Color, metres_per_tile: float, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = rough
	var diff := _tex(id, "diff")
	if diff:
		m.albedo_texture = diff
		var nor := _tex(id, "nor_gl")
		if nor:
			m.normal_enabled = true
			m.normal_texture = nor
			m.normal_scale = 0.8
		var arm := _tex(id, "arm")
		if arm:
			m.roughness = 1.0
			m.roughness_texture = arm
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			m.ao_enabled = true
			m.ao_texture = arm
			m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		else:
			var r := _tex(id, "rough")
			if r:
				m.roughness = 1.0
				m.roughness_texture = r
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / metres_per_tile
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Seamless noise shared by the procedural wall, floor and ceiling shaders.
func _grain_tex() -> NoiseTexture2D:
	if _grain == null:
		_grain = NoiseTexture2D.new()
		_grain.width = 512
		_grain.height = 512
		_grain.seamless = true
		_grain.generate_mipmaps = true
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.02
		n.fractal_octaves = 5
		n.seed = 7
		_grain.noise = n
	return _grain


func _surface(shader_name: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://scenes/environments/morning_classroom/%s.gdshader" % shader_name)
	m.set_shader_parameter("grain", _grain_tex())
	return m


func _wall() -> ShaderMaterial:
	if _wall_mat == null:
		_wall_mat = _surface("cinderblock")
	return _wall_mat


func _plain(color: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


## Instances a Poly Haven model; null if the art hasn't been fetched.
func _model(id: String, pos: Vector3, yaw_deg: float = 0.0, scale: float = 1.0) -> Node3D:
	var p := PH + "models/%s/%s.gltf" % [id, id]
	if not ResourceLoader.exists(p):
		return null
	var n: Node3D = (load(p) as PackedScene).instantiate()
	n.position = pos
	n.rotation.y = deg_to_rad(yaw_deg)
	n.scale = Vector3.ONE * scale
	add_child(n)
	return n


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


# --- Shell -------------------------------------------------------------------------------------

func _build_shell() -> void:
	_box(Vector3(W, 0.1, D), Vector3(0, -0.05, 0), _surface("vct_floor"))
	var wall := _wall()
	_box(Vector3(W, H, 0.2), Vector3(0, H * 0.5, -D * 0.5 - 0.1), wall)   # front
	_box(Vector3(W, H, 0.2), Vector3(0, H * 0.5, D * 0.5 + 0.1), wall)    # back
	_build_right_shell(wall)
	# Rubber cove base along every wall.
	var cove := _plain(Color(0.22, 0.2, 0.19), 0.6)
	_box(Vector3(W, 0.1, 0.012), Vector3(0, 0.05, -D * 0.5 + 0.006), cove)
	_box(Vector3(W, 0.1, 0.012), Vector3(0, 0.05, D * 0.5 - 0.006), cove)
	_box(Vector3(0.012, 0.1, D), Vector3(-W * 0.5 + 0.006, 0.05, 0), cove)
	_box(Vector3(0.012, 0.1, D), Vector3(W * 0.5 - 0.006, 0.05, 0), cove)


func _build_right_shell(wall: Material) -> void:
	# Right wall with the door opening near the front.
	var csg := CSGCombiner3D.new()
	add_child(csg)
	var solid := CSGBox3D.new()
	solid.size = Vector3(0.2, H, D)
	solid.position = Vector3(W * 0.5 + 0.1, H * 0.5, 0)
	solid.material = wall
	csg.add_child(solid)
	var hole := CSGBox3D.new()
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.size = Vector3(0.4, 2.13, 0.95)
	hole.position = Vector3(W * 0.5 + 0.1, 2.13 * 0.5, -2.9)
	csg.add_child(hole)


func _build_ceiling() -> void:
	_box(Vector3(W, 0.05, D), Vector3(0, H + 0.025, 0), _surface("acoustic_tile"))
	# Exposed T-bar grid: 0.6 m across, 1.2 m deep.
	var tbar := _plain(Color(0.94, 0.94, 0.92), 0.5, 0.2)
	var x := -W * 0.5 + 0.6
	while x < W * 0.5 - 0.01:
		_box(Vector3(0.022, 0.012, D), Vector3(x, H - 0.006, 0), tbar)
		x += 0.6
	var z := -D * 0.5 + 0.8
	while z < D * 0.5 - 0.01:
		_box(Vector3(W, 0.012, 0.022), Vector3(0, H - 0.006, z), tbar)
		z += 1.2
	# 2×4 troffers with prismatic lenses.
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color(1, 1, 1)
	lens.emission_enabled = true
	lens.emission = Color(1.0, 0.98, 0.93)
	lens.emission_energy_multiplier = 2.2
	lens.roughness = 0.3
	var housing := _plain(Color(0.92, 0.92, 0.9), 0.4, 0.3)
	for tx in [-2.1, 0.3, 2.7]:
		for tz in [-2.0, 0.4, 2.8]:
			_box(Vector3(0.6, 0.02, 1.2), Vector3(tx, H - 0.012, tz), housing)
			var l := _box(Vector3(0.52, 0.01, 1.12), Vector3(tx, H - 0.024, tz), lens)
			l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var s := SpotLight3D.new()
			s.position = Vector3(tx, H - 0.06, tz)
			s.rotation.x = -PI / 2
			s.spot_range = 4.2
			s.spot_angle = 68.0
			s.spot_attenuation = 0.8
			s.light_energy = 1.6
			s.light_color = Color(1.0, 0.97, 0.9)
			s.light_specular = 0.3
			add_child(s)
			_fill_lights.append(s)
			# Light bouncing off the desks and floor keeps a real ceiling from going dark.
			var up := OmniLight3D.new()
			up.position = Vector3(tx, 1.2, tz)
			up.omni_range = 3.2
			up.omni_attenuation = 1.2
			up.light_energy = 0.22
			up.light_specular = 0.0
			up.light_color = Color(1.0, 0.95, 0.88)
			add_child(up)
	# Ceiling-mounted projector in the middle of the room.
	var proj := _plain(Color(0.9, 0.9, 0.88), 0.45)
	_box(Vector3(0.04, 0.35, 0.04), Vector3(0, H - 0.175, -0.8), _plain(Color(0.2, 0.2, 0.21), 0.4, 0.6))
	_box(Vector3(0.36, 0.11, 0.3), Vector3(0, H - 0.38, -0.8), proj)
	var lens_m := _plain(Color(0.03, 0.03, 0.04), 0.1)
	var pl := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.035
	cyl.height = 0.02
	pl.mesh = cyl
	pl.material_override = lens_m
	pl.rotation.x = PI / 2
	pl.position = Vector3(0.09, H - 0.38, -0.96)
	add_child(pl)


# --- Windows -------------------------------------------------------------------------------------

func _build_windows() -> void:
	var wall_mat := _wall()
	var csg := CSGCombiner3D.new()
	add_child(csg)
	var solid := CSGBox3D.new()
	solid.size = Vector3(0.2, H, D)
	solid.position = Vector3(-W * 0.5 - 0.1, H * 0.5, 0)
	solid.material = wall_mat
	csg.add_child(solid)
	var frame := _plain(Color(0.78, 0.79, 0.8), 0.35, 0.8)  # anodised aluminium
	var sill := _plain(Color(0.84, 0.82, 0.78), 0.4)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.9, 0.92, 0.08)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.03
	glass.metallic_specular = 0.8
	var hvac := _plain(Color(0.84, 0.81, 0.74), 0.45, 0.3)
	var wx := -W * 0.5
	var h := WINDOW_TOP - SILL_Y
	var drops := [0.45, 0.62, 0.3]
	for i in WINDOW_ZS.size():
		var z: float = WINDOW_ZS[i]
		var hole := CSGBox3D.new()
		hole.operation = CSGShape3D.OPERATION_SUBTRACTION
		hole.size = Vector3(0.4, h, WINDOW_W)
		hole.position = Vector3(wx - 0.1, SILL_Y + h * 0.5, z)
		csg.add_child(hole)
		# Frame: head, jambs, a transom and a centre mullion.
		_box(Vector3(0.1, 0.05, WINDOW_W), Vector3(wx - 0.05, WINDOW_TOP - 0.025, z), frame)
		_box(Vector3(0.1, 0.05, WINDOW_W), Vector3(wx - 0.05, SILL_Y + 0.025, z), frame)
		for jz in [-WINDOW_W * 0.5 + 0.025, WINDOW_W * 0.5 - 0.025, 0.0]:
			_box(Vector3(0.1, h, 0.05), Vector3(wx - 0.05, SILL_Y + h * 0.5, z + jz), frame)
		_box(Vector3(0.1, 0.04, WINDOW_W), Vector3(wx - 0.05, SILL_Y + h * 0.7, z), frame)
		var g := _box(Vector3(0.006, h, WINDOW_W), Vector3(wx - 0.08, SILL_Y + h * 0.5, z), glass)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_box(Vector3(0.24, 0.03, WINDOW_W + 0.1), Vector3(wx + 0.07, SILL_Y - 0.015, z), sill)
		_box(Vector3(0.28, 0.62, WINDOW_W - 0.1), Vector3(wx + 0.14, 0.31, z), hvac)  # unit ventilator
		_box(Vector3(0.3, 0.02, WINDOW_W - 0.08), Vector3(wx + 0.14, 0.63, z), _plain(Color(0.42, 0.42, 0.4), 0.5, 0.5))
		_blinds(Vector3(wx + 0.06, WINDOW_TOP - 0.02, z), WINDOW_W - 0.06, h * drops[i])
		if i == 1:
			_model("potted_plant_01", Vector3(wx + 0.16, SILL_Y, z + 0.55), 20.0, 0.32)


## Venetian blinds lowered `drop` metres from the head, slats tilted open so sun comes through in
## stripes.
func _blinds(top: Vector3, width: float, drop: float) -> void:
	var slat := BoxMesh.new()
	slat.size = Vector3(0.025, 0.0012, width)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = slat
	var spacing := 0.022
	var n := int(drop / spacing)
	mm.instance_count = n
	var tilt := Basis(Vector3(0, 0, 1), deg_to_rad(-38.0))
	for i in n:
		mm.set_instance_transform(i, Transform3D(tilt, Vector3(0, -i * spacing, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _plain(Color(0.9, 0.89, 0.85), 0.5, 0.1)
	mmi.position = top + Vector3(0, -0.04, 0)
	add_child(mmi)
	# Head rail and bottom rail.
	_box(Vector3(0.05, 0.04, width), top, _plain(Color(0.9, 0.89, 0.86), 0.45))
	_box(Vector3(0.03, 0.012, width), top + Vector3(0, -0.04 - n * spacing, 0), _plain(Color(0.88, 0.87, 0.84), 0.45))


# --- Front wall --------------------------------------------------------------------------------

func _build_front() -> void:
	var fz := -D * 0.5
	board = Whiteboard.new()
	board.position = Vector3(0, 1.45, fz + 0.02)
	add_child(board)
	wall_clock = WallClock.new()
	wall_clock.position = Vector3(0, 2.4, fz + 0.03)
	add_child(wall_clock)
	_bulletin(Vector3(-3.1, 1.5, fz + 0.012), Vector2(1.5, 1.1), [
		{"t": "CLASSROOM RULES", "c": Color("#F2D16B"), "s": Vector2(0.42, 0.56), "p": Vector2(-0.4, 0.12)},
		{"t": "PERIODIC TABLE", "c": Color("#9CC3E6"), "s": Vector2(0.6, 0.4), "p": Vector2(0.3, 0.22)},
		{"t": "Fire Exit Plan", "c": Color("#F4F1EA"), "s": Vector2(0.28, 0.36), "p": Vector2(0.48, -0.28)},
		{"t": "October", "c": Color("#E9A27A"), "s": Vector2(0.38, 0.3), "p": Vector2(-0.05, -0.32)},
	])
	# PA speaker grille, top corner.
	_box(Vector3(0.3, 0.3, 0.03), Vector3(3.8, 2.6, fz + 0.015), _plain(Color(0.86, 0.85, 0.8), 0.6))
	_box(Vector3(0.24, 0.24, 0.01), Vector3(3.8, 2.6, fz + 0.032), _plain(Color(0.6, 0.59, 0.55), 0.7, 0.3))
	# Teacher's desk, chair and what's on the desk.
	var td := Vector3(2.75, 0, -2.85)
	if _model("metal_office_desk", td, 180.0, 0.78) == null:
		_box(Vector3(1.5, 0.75, 0.75), td + Vector3(0, 0.375, 0), _plain(Color("#8A6646"), 0.6))
	_model("modern_arm_chair_01", td + Vector3(0.1, 0, -0.75), 15.0, 0.92)
	_model("clipboard", td + Vector3(-0.35, 0.787 * 0.78, 0.05), 80.0)
	_model("stationery_supplies", td + Vector3(0.55, 0.787 * 0.78, -0.12), 190.0)
	_model("book_encyclopedia_set_01", td + Vector3(0.15, 0.787 * 0.78, -0.25), 180.0, 0.8)
	_paper_stack(td + Vector3(-0.05, 0.787 * 0.78, 0.08), 0.03, 12.0)
	teacher_desk = _marker(td + Vector3(0, 0, 0.75), Basis(Vector3.UP, PI))


## A cork board with paper notices. Built facing +Z; `yaw_deg` turns it to face another way.
func _bulletin(center: Vector3, size: Vector2, items: Array, yaw_deg: float = 0.0) -> void:
	var root := Node3D.new()
	root.position = center
	root.rotation.y = deg_to_rad(yaw_deg)
	add_child(root)
	_box(Vector3(size.x + 0.05, size.y + 0.05, 0.02), Vector3.ZERO, _plain(Color(0.55, 0.42, 0.28), 0.6), root)   # wood frame
	_box(Vector3(size.x, size.y, 0.024), Vector3.ZERO, _plain(Color(0.66, 0.5, 0.36), 0.95), root)                 # cork
	for it in items:
		var s: Vector2 = it.s
		var p: Vector2 = it.p
		var paper := _box(Vector3(s.x, s.y, 0.002), Vector3(p.x, p.y, 0.014), _plain(it.c, 0.9), root)
		paper.rotation.z = deg_to_rad(_rng.randf_range(-2.0, 2.0))
		var l := Label3D.new()
		l.text = it.t
		l.font = load("res://assets/fonts/AtkinsonHyperlegible-Bold.ttf")
		l.font_size = 48
		l.pixel_size = 0.0007
		l.modulate = Color(0.15, 0.14, 0.13)
		l.outline_size = 0
		l.shaded = true
		l.position = Vector3(0, s.y * 0.38, 0.002)
		paper.add_child(l)
		# A few "lines" of print under the title.
		for k in 4:
			_box(Vector3(s.x * 0.7, 0.008, 0.001), Vector3(0, s.y * (0.18 - k * 0.12), 0.0015), _plain(Color(0.35, 0.34, 0.32), 0.9), paper)


# --- Right wall: door ------------------------------------------------------------------------------

func _build_right_wall() -> void:
	var rx := W * 0.5
	var dz := -2.9
	var frame := _plain(Color(0.42, 0.44, 0.46), 0.4, 0.6)  # hollow metal frame
	_box(Vector3(0.22, 0.06, 1.07), Vector3(rx, 2.16, dz), frame)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.22, 2.16, 0.06), Vector3(rx, 1.08, dz + s * 0.505), frame)
	var door := _pbr("plastered_wall_04", Color(0.72, 0.55, 0.36), 2.0, 0.55)  # oak-veneer look
	_box(Vector3(0.045, 2.11, 0.94), Vector3(rx - 0.02, 1.055, dz), door)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.8, 0.85, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	_box(Vector3(0.05, 0.8, 0.12), Vector3(rx - 0.02, 1.5, dz - 0.28), glass)
	_box(Vector3(0.05, 0.25, 0.85), Vector3(rx - 0.02, 0.14, dz), _plain(Color(0.7, 0.7, 0.72), 0.3, 0.9))  # kick plate
	_box(Vector3(0.07, 0.02, 0.13), Vector3(rx - 0.07, 1.0, dz + 0.36), _plain(Color(0.75, 0.75, 0.77), 0.25, 0.9))  # lever
	# Light switch, fire alarm pull, wall map.
	_box(Vector3(0.01, 0.12, 0.075), Vector3(rx - 0.005, 1.2, dz + 0.75), _plain(Color(0.95, 0.94, 0.9), 0.5))
	if _model("fire_alarm", Vector3(rx - 0.01, 1.25, dz + 1.15), -90.0) == null:
		_box(Vector3(0.03, 0.14, 0.1), Vector3(rx - 0.015, 1.25, dz + 1.15), _plain(Color(0.75, 0.1, 0.08), 0.5))
	var map := _box(Vector3(0.004, 0.9, 1.4), Vector3(rx - 0.004, 1.6, 0.6), _plain(Color(0.62, 0.77, 0.86), 0.9))
	for k in 5:
		var land := _box(Vector3(0.002, _rng.randf_range(0.12, 0.3), _rng.randf_range(0.15, 0.4)),
			Vector3(-0.003, _rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.5, 0.5)), _plain(Color(0.76, 0.72, 0.5), 0.9), map)
		land.rotation.x = _rng.randf_range(-0.6, 0.6)


# --- Back of the room ------------------------------------------------------------------------------

func _build_back() -> void:
	var bz := D * 0.5
	if _model("drawer_cabinet", Vector3(-2.6, 0, bz - 0.26), 180.0, 0.9) != null:
		_model("book_encyclopedia_set_01", Vector3(-2.85, 1.88 * 0.9, bz - 0.3), 180.0, 0.9)
	_model("steel_frame_shelves_03", Vector3(1.6, 0, bz - 0.38), 180.0, 0.8)
	_model("potted_plant_01", Vector3(4.0, 0, bz - 0.45), 0.0, 0.85)
	_bulletin(Vector3(-0.4, 1.5, bz - 0.012), Vector2(1.8, 1.0), [
		{"t": "Student Work", "c": Color("#B9D8A8"), "s": Vector2(0.5, 0.36), "p": Vector2(-0.55, 0.22)},
		{"t": "Book Report", "c": Color("#F4F1EA"), "s": Vector2(0.3, 0.4), "p": Vector2(0.05, 0.18)},
		{"t": "Science Fair", "c": Color("#F2D16B"), "s": Vector2(0.44, 0.32), "p": Vector2(0.58, 0.2)},
		{"t": "Lunch Menu", "c": Color("#F4F1EA"), "s": Vector2(0.3, 0.38), "p": Vector2(-0.3, -0.25)},
	], 180.0)


# --- Desks -------------------------------------------------------------------------------------

func _build_desks() -> void:
	desk_top_y = _measure_desk_top()
	desk_far_edge = -0.2776 - 0.05  # SchoolDesk_01 front edge, minus the paper's offset toward the student
	for r in ROWS.size():
		for c in COLS.size():
			var base := Vector3(COLS[c], 0, ROWS[r])
			var jitter := Vector3(_rng.randf_range(-0.04, 0.04), 0, _rng.randf_range(-0.04, 0.04))
			var yaw := _rng.randf_range(-2.5, 2.5)
			var mine := c == PLAYER_COL and r == PLAYER_ROW
			if mine:
				jitter = Vector3.ZERO
				yaw = 0.0
			_desk(base + jitter, yaw)
			# The paper sits a little toward the student's edge of the desk, where people keep it.
			var seat := _marker(base + jitter + Vector3(0, desk_top_y + 0.0012, 0.05), Basis(Vector3.UP, deg_to_rad(yaw)))
			if mine:
				player_seat = seat
			else:
				student_seats.append(seat)
				_desk_clutter(base + jitter, yaw)


func _desk(base: Vector3, yaw: float) -> void:
	var desk := _model("SchoolDesk_01", base, yaw)
	if desk:
		desk.scale = Vector3(1.0, _desk_vscale, 1.0)
	else:
		_box(Vector3(0.66, 0.025, 0.48), base + Vector3(0, 0.74, 0), _plain(Color("#C9A57A"), 0.5))
		for sx in [-0.3, 0.3]:
			for sz in [-0.2, 0.2]:
				_box(Vector3(0.025, 0.74, 0.025), base + Vector3(sx, 0.37, sz), _plain(Color(0.55, 0.56, 0.58), 0.4, 0.7))
	var chair := _model("SchoolChair_01", base + Vector3(_rng.randf_range(-0.03, 0.03), 0, 0.5), 180.0 + yaw + _rng.randf_range(-6, 6))
	if chair == null:
		var ch := base + Vector3(0, 0, 0.45)
		_box(Vector3(0.42, 0.03, 0.4), ch + Vector3(0, 0.45, 0), _plain(Color("#2F3236"), 0.55))
		_box(Vector3(0.42, 0.32, 0.03), ch + Vector3(0, 0.68, 0.2), _plain(Color("#2F3236"), 0.55))


## The Poly Haven desk is 0.88 m tall; school desks are about 0.76 m, so it is squashed
## vertically (its legs are telescopic anyway). Returns the desk-top height after scaling.
const DESK_TARGET_H := 0.76


func _measure_desk_top() -> float:
	var p := PH + "models/SchoolDesk_01/SchoolDesk_01.gltf"
	if not ResourceLoader.exists(p):
		return 0.7525
	var n: Node3D = (load(p) as PackedScene).instantiate()
	var top := 0.0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		top = maxf(top, (mi as MeshInstance3D).get_aabb().end.y)
	n.free()
	if top < 0.3:
		return 0.7525
	_desk_vscale = DESK_TARGET_H / top
	return DESK_TARGET_H


## What sits on other students' desks: their own copy of the test, a pencil, sometimes a binder
## or a water bottle.
func _desk_clutter(base: Vector3, yaw: float) -> void:
	var top := base + Vector3(0, desk_top_y + 0.001, 0)
	var paper := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.216, 0.279)
	paper.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _student_paper()
	mat.roughness = 0.95
	paper.material_override = mat
	paper.position = top + Vector3(_rng.randf_range(-0.06, 0.06), 0.0008, _rng.randf_range(0.0, 0.06))
	paper.rotation.y = deg_to_rad(yaw + _rng.randf_range(-12, 12))
	add_child(paper)
	var pencil := _box(Vector3(0.007, 0.007, 0.175), top + Vector3(_rng.randf_range(0.12, 0.22), 0.004, _rng.randf_range(-0.05, 0.1)),
		_plain(Color(0.93, 0.72, 0.18), 0.5))
	pencil.rotation.y = _rng.randf_range(-0.8, 0.8)
	if _rng.randf() < 0.35:
		_model("binder_notebook", top + Vector3(-0.2, 0.0, -0.12), yaw + _rng.randf_range(-20, 20), 0.55)
	if _rng.randf() < 0.3:
		var b := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.032
		cyl.bottom_radius = 0.034
		cyl.height = 0.22
		b.mesh = cyl
		var bm := _plain([Color(0.2, 0.45, 0.75), Color(0.15, 0.55, 0.45), Color(0.8, 0.3, 0.35), Color(0.8, 0.8, 0.82)][_rng.randi() % 4], 0.3, 0.4)
		b.material_override = bm
		b.position = top + Vector3(0.27, 0.11, -0.17)
		add_child(b)


## One shared texture for the other students' test pages: grey "print" lines and answer bubbles.
func _student_paper() -> Texture2D:
	if _paper_tex:
		return _paper_tex
	var img := Image.create(216, 279, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.97, 0.965, 0.95))
	var ink := Color(0.45, 0.45, 0.46)
	img.fill_rect(Rect2i(20, 16, 120, 6), ink)
	var y := 36
	while y < 260:
		img.fill_rect(Rect2i(24, y, 150 - (y * 7) % 50, 3), ink)
		for k in 4:
			img.fill_rect(Rect2i(34 + k * 26, y + 9, 6, 6), Color(0.6, 0.6, 0.6))
		y += 26
	img.generate_mipmaps()
	_paper_tex = ImageTexture.create_from_image(img)
	return _paper_tex


func _paper_stack(pos: Vector3, h: float, yaw: float) -> void:
	var s := _box(Vector3(0.216, h, 0.279), pos + Vector3(0, h * 0.5, 0), _plain(Color(0.95, 0.94, 0.91), 0.9))
	s.rotation.y = deg_to_rad(yaw)


# --- Paths -------------------------------------------------------------------------------------

func _build_paths() -> void:
	teacher_patrol = _path([Vector3(-2.25, 0, -2.4), Vector3(-2.25, 0, 3.6), Vector3(0.75, 0, 3.6), Vector3(0.75, 0, -2.4), Vector3(-2.25, 0, -2.4)])
	var p := player_seat.position
	handin_path = _path([p + Vector3(0, -p.y, 0.5), p + Vector3(0.75, -p.y, 0.5), Vector3(-0.75, 0, -2.4), Vector3(1.9, 0, -2.4)])


func _path(points: Array) -> Path3D:
	var path := Path3D.new()
	var curve := Curve3D.new()
	for pt in points:
		curve.add_point(pt)
	path.curve = curve
	add_child(path)
	return path


func _marker(pos: Vector3, basis: Basis) -> Marker3D:
	var m := Marker3D.new()
	m.transform = Transform3D(basis, pos)
	add_child(m)
	return m


# --- Lighting ----------------------------------------------------------------------------------

func _build_lighting() -> void:
	world_env = WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var hdr_path := PH + "hdri/autumn_park.hdr"
	if ResourceLoader.exists(hdr_path):
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = load(hdr_path)
		pano.energy_multiplier = 1.0
		sky.sky_material = pano
	else:
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = Color(0.45, 0.62, 0.85)
		sm.sky_horizon_color = Color(0.82, 0.86, 0.9)
		sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.sky_rotation = Vector3(0, deg_to_rad(90), 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.86, 0.8)
	e.ambient_light_energy = 0.35
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.0
	e.ssao_enabled = true
	e.ssao_radius = 0.8
	e.ssao_intensity = 1.6
	e.glow_enabled = true
	e.glow_intensity = 0.12
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.8
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.05
	e.adjustment_contrast = 1.03
	world_env.environment = e
	add_child(world_env)
	# Morning sun, low (~24°) through the left windows.
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.88, 0.72)
	sun.light_energy = 3.2
	sun.light_angular_distance = 0.6
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	sun.shadow_blur = 1.4
	sun.directional_shadow_max_distance = 12.0
	sun.light_volumetric_fog_energy = 2.0
	add_child(sun)
	sun.transform = Transform3D(Basis(), Vector3.ZERO).looking_at(Vector3(cos(deg_to_rad(24)), -sin(deg_to_rad(24)), 0.42).normalized(), Vector3.UP)


## Graphics presets: low = no GI, no fog, cheap shadows; medium = SSIL and SSAO; high = SDFGI
## bounce light and sunbeams in volumetric fog.
func apply_preset(preset: String) -> void:
	var e := world_env.environment
	var high := preset == "high"
	var low := preset == "low"
	e.ssao_enabled = not low
	e.ssil_enabled = not low
	e.ssil_intensity = 0.9
	e.sdfgi_enabled = high
	e.sdfgi_use_occlusion = true
	e.sdfgi_energy = 1.3
	e.volumetric_fog_enabled = high
	e.volumetric_fog_density = 0.006
	e.volumetric_fog_albedo = Color(1.0, 0.96, 0.9)
	e.volumetric_fog_anisotropy = 0.6
	e.ambient_light_energy = 0.5 if low else (0.3 if high else 0.35)
	sun.shadow_blur = 1.0 if low else 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if low else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	for l in _fill_lights:
		l.shadow_enabled = high
