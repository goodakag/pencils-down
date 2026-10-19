class_name GreyboxClassroom
extends EnvironmentContract
## Blocked-out Morning Classroom (spec §6.1): 9 × 8 m, ceiling 2.9 m, windows on the left (-X),
## whiteboard and clock at the front (-Z). Plan 2 replaces the boxes with the modelled room.

const W := 9.0
const D := 8.0
const H := 2.9
const DESK_H := 0.74
const COLS := [-3.0, -1.5, 0.0, 1.5, 3.0]
const ROWS := [-1.6, -0.5, 0.6, 1.7, 2.8]
const PLAYER_COL := 1
const PLAYER_ROW := 2

const WALL := Color("#D8CDB8")
const FLOOR := Color("#B9AE9C")
const CEILING := Color("#E9E6DF")
const LAMINATE := Color("#C9A57A")
const CHAIR := Color("#2F3236")
const STEEL := Color(0.55, 0.56, 0.58)

var sun: DirectionalLight3D
var world_env: WorldEnvironment


func _init() -> void:
	_build_shell()
	_build_windows()
	_build_front()
	_build_desks()
	_build_paths()
	_build_lighting()


# --- Shell -------------------------------------------------------------------------------------

func _build_shell() -> void:
	_box(Vector3(W, 0.1, D), Vector3(0, -0.05, 0), FLOOR, 0.32)                  # floor (polished VCT)
	_box(Vector3(W, 0.1, D), Vector3(0, H + 0.05, 0), CEILING, 0.95)             # ceiling
	_box(Vector3(W, H, 0.2), Vector3(0, H * 0.5, -D * 0.5 - 0.1), WALL, 0.9)     # front
	_box(Vector3(W, H, 0.2), Vector3(0, H * 0.5, D * 0.5 + 0.1), WALL, 0.9)      # back
	_box(Vector3(0.2, H, D), Vector3(W * 0.5 + 0.1, H * 0.5, 0), WALL, 0.9)      # right
	# Ceiling troffers (2 rows × 3), lit softly.
	for x in [-1.8, 1.8]:
		for z in [-2.4, 0.0, 2.4]:
			var t := _box(Vector3(0.6, 0.03, 1.2), Vector3(x, H - 0.015, z), Color(1, 1, 1), 0.5)
			var m := t.material_override as StandardMaterial3D
			m.emission_enabled = true
			m.emission = Color(1.0, 0.97, 0.9)
			m.emission_energy_multiplier = 1.4


func _build_windows() -> void:
	# Left wall with three window bays cut out (CSG subtraction).
	var wall := CSGCombiner3D.new()
	add_child(wall)
	var solid := CSGBox3D.new()
	solid.size = Vector3(0.2, H, D)
	solid.position = Vector3(-W * 0.5 - 0.1, H * 0.5, 0)
	solid.material = _mat(WALL, 0.9)
	wall.add_child(solid)
	var shade_heights := [0.35, 0.6, 0.2]
	for i in 3:
		var z: float = [-2.2, 0.0, 2.2][i]
		var hole := CSGBox3D.new()
		hole.operation = CSGShape3D.OPERATION_SUBTRACTION
		hole.size = Vector3(0.4, 1.5, 1.7)
		hole.position = Vector3(-W * 0.5 - 0.1, 1.65, z)
		wall.add_child(hole)
		# Sill, frame mullion, and a roller shade pulled partly down.
		_box(Vector3(0.28, 0.04, 1.8), Vector3(-W * 0.5 + 0.02, 0.9, z), Color("#EDE6D6"), 0.6)
		_box(Vector3(0.05, 1.5, 0.05), Vector3(-W * 0.5 - 0.05, 1.65, z), Color("#EDE6D6"), 0.6)
		var shade_h: float = 1.5 * shade_heights[i]
		_box(Vector3(0.02, shade_h, 1.7), Vector3(-W * 0.5 + 0.05, 2.4 - shade_h * 0.5, z), Color("#E8E0CC"), 0.95)
		# HVAC unit under the sill.
		_box(Vector3(0.3, 0.6, 1.6), Vector3(-W * 0.5 + 0.15, 0.3, z), Color("#CFC8B8"), 0.7)


func _build_front() -> void:
	board = Whiteboard.new()
	board.position = Vector3(0, 1.45, -D * 0.5 + 0.02)
	add_child(board)
	wall_clock = WallClock.new()
	wall_clock.position = Vector3(0, 2.42, -D * 0.5 + 0.02)
	add_child(wall_clock)
	# Teacher's desk, monitor, mug.
	var td := Vector3(2.7, 0, -2.9)
	_box(Vector3(1.4, 0.04, 0.7), td + Vector3(0, 0.76, 0), Color("#9C7550"), 0.55)
	_box(Vector3(1.36, 0.72, 0.66), td + Vector3(0, 0.37, 0), Color("#8A6646"), 0.6)
	_box(Vector3(0.5, 0.32, 0.03), td + Vector3(-0.2, 0.98, -0.2), Color(0.1, 0.1, 0.11), 0.4)
	var mug := MeshInstance3D.new()
	var mc := CylinderMesh.new()
	mc.top_radius = 0.04
	mc.bottom_radius = 0.04
	mc.height = 0.1
	mug.mesh = mc
	mug.material_override = _mat(Color("#2F5D8C"), 0.4)
	mug.position = td + Vector3(0.45, 0.83, 0.1)
	add_child(mug)
	teacher_desk = _marker(td + Vector3(0, 0, 0.7), Basis(Vector3.UP, PI))


# --- Desks -------------------------------------------------------------------------------------

func _build_desks() -> void:
	for r in ROWS.size():
		for c in COLS.size():
			var base := Vector3(COLS[c], 0, ROWS[r])
			_desk(base)
			var seat := _marker(base + Vector3(0, DESK_H + 0.0125 + 0.0012, 0), Basis())  # paper rests just above the laminate
			if c == PLAYER_COL and r == PLAYER_ROW:
				player_seat = seat
			else:
				student_seats.append(seat)


func _desk(base: Vector3) -> void:
	_box(Vector3(0.66, 0.025, 0.48), base + Vector3(0, DESK_H, 0), LAMINATE, 0.5)
	_box(Vector3(0.6, 0.12, 0.4), base + Vector3(0, DESK_H - 0.08, -0.02), Color(0.35, 0.36, 0.38), 0.6)  # book box
	for sx in [-0.3, 0.3]:
		for sz in [-0.2, 0.2]:
			_box(Vector3(0.025, DESK_H, 0.025), base + Vector3(sx, DESK_H * 0.5, sz), STEEL, 0.4, 0.7)
	# Sled-base chair behind the desk.
	var ch := base + Vector3(0, 0, 0.45)
	_box(Vector3(0.42, 0.03, 0.4), ch + Vector3(0, 0.45, 0), CHAIR, 0.55)
	_box(Vector3(0.42, 0.32, 0.03), ch + Vector3(0, 0.68, 0.2), CHAIR, 0.55)
	for sx in [-0.19, 0.19]:
		_box(Vector3(0.02, 0.45, 0.02), ch + Vector3(sx, 0.225, -0.15), STEEL, 0.4, 0.7)
		_box(Vector3(0.02, 0.8, 0.02), ch + Vector3(sx, 0.4, 0.18), STEEL, 0.4, 0.7)


# --- Paths -------------------------------------------------------------------------------------

func _build_paths() -> void:
	teacher_patrol = _path([Vector3(-2.25, 0, -2.4), Vector3(-2.25, 0, 3.4), Vector3(0.75, 0, 3.4), Vector3(0.75, 0, -2.4), Vector3(-2.25, 0, -2.4)])
	var p := player_seat.position
	handin_path = _path([p + Vector3(0, -DESK_H, 0.45), p + Vector3(0.75, -DESK_H, 0.45), Vector3(-0.75, 0, -2.4), Vector3(1.9, 0, -2.4)])


func _path(points: Array) -> Path3D:
	var path := Path3D.new()
	var curve := Curve3D.new()
	for pt in points:
		curve.add_point(pt)
	path.curve = curve
	add_child(path)
	return path


# --- Lighting ----------------------------------------------------------------------------------

func _build_lighting() -> void:
	world_env = WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.45, 0.62, 0.85)
	sm.sky_horizon_color = Color(0.82, 0.86, 0.9)
	sm.ground_horizon_color = Color(0.7, 0.68, 0.62)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.93, 0.88, 0.8)
	e.ambient_light_energy = 0.5
	e.ssil_enabled = true
	e.ssil_intensity = 1.2
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.2
	e.ssao_enabled = true
	e.ssao_intensity = 1.4
	e.glow_enabled = true
	e.glow_intensity = 0.35
	world_env.environment = e
	add_child(world_env)
	# Low morning sun (~15° elevation) through the left windows.
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.85, 0.66)
	sun.light_energy = 4.5
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_max_distance = 14.0
	add_child(sun)
	sun.transform = Transform3D(Basis(), Vector3.ZERO).looking_at(Vector3(cos(deg_to_rad(15)), -sin(deg_to_rad(15)), 0.35).normalized(), Vector3.UP)
	# Soft fill from the ceiling panels.
	for x in [-1.8, 1.8]:
		for z in [-2.4, 0.0, 2.4]:
			var o := OmniLight3D.new()
			o.position = Vector3(x, H - 0.2, z)
			o.light_color = Color(1.0, 0.97, 0.9)
			o.light_energy = 0.6
			o.omni_range = 4.5
			add_child(o)


# --- Helpers -----------------------------------------------------------------------------------

func _marker(pos: Vector3, basis: Basis) -> Marker3D:
	var m := Marker3D.new()
	m.transform = Transform3D(basis, pos)
	add_child(m)
	return m


func _box(size: Vector3, pos: Vector3, color: Color, rough: float, metal: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(color, rough, metal)
	mi.position = pos
	add_child(mi)
	return mi


func _mat(color: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m
