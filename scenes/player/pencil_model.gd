class_name PencilModel
extends Node3D
## A yellow #2 hexagonal pencil built from primitives. The node origin is the graphite tip.
## Plan 3 replaces this with the full hand rig; the tip contract stays the same.

const LENGTH := 0.175
const RADIUS := 0.0036

var left_handed: bool = false
var _body: Node3D
var _flip_tween: Tween
var _eraser_down: bool = false


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	var cone_len := 0.018
	_add_part(_cyl(0.0004, RADIUS * 0.35, 0.004, 12), Color("#2E2D30"), 0.45, 0.002)           # graphite point
	_add_part(_cyl(RADIUS * 0.35, RADIUS, cone_len - 0.004, 6), Color("#E2C39B"), 0.8, 0.004 + (cone_len - 0.004) * 0.5)  # sharpened cedar
	var body_len := LENGTH - cone_len - 0.02
	_add_part(_cyl(RADIUS, RADIUS, body_len, 6), Color("#E8B33A"), 0.42, cone_len + body_len * 0.5)  # painted hex body
	_add_part(_cyl(RADIUS * 1.04, RADIUS * 1.04, 0.009, 16), Color("#C9C6BE"), 0.35, cone_len + body_len + 0.0045, 0.4)  # ferrule
	_add_part(_cyl(RADIUS * 0.98, RADIUS * 0.98, 0.011, 16), Color("#F2A5B2"), 0.85, cone_len + body_len + 0.009 + 0.0055)  # eraser
	_apply_pose(false)


func _cyl(bottom: float, top: float, h: float, segs: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = bottom
	c.top_radius = top
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


func _add_part(m: Mesh, color: Color, rough: float, center_y: float, metal: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	mi.material_override = mat
	mi.position.y = center_y
	_body.add_child(mi)


## Tilts the pencil up and back toward the writing hand; eraser-down turns it end over end so the
## eraser sits on the paper at the same tip point.
func _apply_pose(eraser: bool) -> void:
	var side := -1.0 if left_handed else 1.0
	var d := Vector3(0.3 * side, 0.5, 0.81).normalized()
	var x := d.cross(Vector3.FORWARD).normalized()
	var z := x.cross(d)
	var b := Basis(x, d, z)
	if eraser:
		_body.basis = b * Basis(Vector3.RIGHT, PI)
		_body.position = d * LENGTH
	else:
		_body.basis = b
		_body.position = Vector3.ZERO


func set_eraser(on: bool) -> void:
	if on == _eraser_down:
		return
	_eraser_down = on
	if _flip_tween:
		_flip_tween.kill()
	# A quick dip-and-flip: shrink to the turn, swap ends, come back (0.2 s total).
	_flip_tween = create_tween()
	_flip_tween.tween_property(self, "scale", Vector3(1, 0.2, 1), 0.1)
	_flip_tween.tween_callback(_apply_pose.bind(on))
	_flip_tween.tween_property(self, "scale", Vector3.ONE, 0.1)


func set_left_handed(v: bool) -> void:
	left_handed = v
	_apply_pose(_eraser_down)
