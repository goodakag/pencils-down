class_name WallClock
extends Node3D
## Analog school wall clock: white face, black hands, red sweeping second hand. Faces +Z.

const RADIUS := 0.16

var _hour: Node3D
var _minute: Node3D
var _second: Node3D


func _init() -> void:
	var rim := _mesh(_cyl(RADIUS + 0.012, 0.035), Color(0.12, 0.12, 0.13), 0.4)
	rim.rotation.x = PI / 2
	var face := _mesh(_cyl(RADIUS, 0.036), Color(0.96, 0.95, 0.92), 0.7)
	face.rotation.x = PI / 2
	face.position.z = 0.001
	for i in 12:
		var a := TAU * i / 12.0
		var tick := _mesh(_box(Vector3(0.006 if i % 3 else 0.01, 0.024, 0.002)), Color(0.1, 0.1, 0.1), 0.6)
		tick.position = Vector3(sin(a), cos(a), 0) * (RADIUS - 0.022) + Vector3(0, 0, 0.02)
		tick.rotation.z = -a
	_hour = _hand(Vector3(0.012, 0.085, 0.003), Color(0.08, 0.08, 0.08), 0.021)
	_minute = _hand(Vector3(0.008, 0.125, 0.003), Color(0.08, 0.08, 0.08), 0.024)
	_second = _hand(Vector3(0.003, 0.135, 0.002), Color(0.75, 0.1, 0.08), 0.027)
	var cap := _mesh(_cyl(0.008, 0.01), Color(0.75, 0.1, 0.08), 0.5)
	cap.rotation.x = PI / 2
	cap.position.z = 0.03


func set_time(seconds_of_day: float) -> void:
	var a := WallClockMath.hand_angles(seconds_of_day)
	_hour.rotation.z = -a.x
	_minute.rotation.z = -a.y
	_second.rotation.z = -a.z


func _hand(size: Vector3, color: Color, z: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position.z = z
	add_child(pivot)
	var m := MeshInstance3D.new()
	m.mesh = _box(size)
	m.position.y = size.y * 0.4
	m.material_override = _mat(color, 0.5)
	pivot.add_child(m)
	return pivot


func _mesh(m: Mesh, color: Color, rough: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _mat(color, rough)
	add_child(mi)
	return mi


func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 48
	return c


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b
