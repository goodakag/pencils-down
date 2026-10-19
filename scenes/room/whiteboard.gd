class_name Whiteboard
extends Node3D
## Whiteboard with an aluminium tray. The teacher's marker writing is a Label3D in a handwriting font.

const SIZE := Vector2(3.6, 1.2)
const MARKER_BLUE := Color(0.12, 0.2, 0.45)

var _main: Label3D
var _sub: Label3D
var _note: Label3D


func _init() -> void:
	var frame := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(SIZE.x + 0.06, SIZE.y + 0.06, 0.03)
	frame.mesh = fb
	frame.material_override = _mat(Color(0.62, 0.63, 0.62), 0.35, 0.6)
	add_child(frame)
	var board := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(SIZE.x, SIZE.y, 0.032)
	board.mesh = bb
	board.material_override = _mat(Color(0.97, 0.97, 0.96), 0.18, 0.0)
	add_child(board)
	var tray := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(SIZE.x * 0.9, 0.025, 0.07)
	tray.mesh = tb
	tray.material_override = _mat(Color(0.6, 0.6, 0.6), 0.4, 0.6)
	tray.position = Vector3(0, -SIZE.y * 0.5 - 0.03, 0.04)
	add_child(tray)
	_main = _label(0.12, Vector3(0, 0.2, 0.02))
	_sub = _label(0.07, Vector3(0, -0.05, 0.02))
	_note = _label(0.09, Vector3(SIZE.x * 0.3, -0.38, 0.02))


func _label(size_m: float, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.font = HandwritingLayout.font_for(&"kalam")
	l.pixel_size = size_m / 96.0
	l.font_size = 96
	l.modulate = MARKER_BLUE
	l.outline_size = 0
	l.position = pos
	l.shaded = true
	l.double_sided = false
	add_child(l)
	return l


func set_lines(main: String, sub: String) -> void:
	_main.text = main
	_sub.text = sub


func set_note(text: String) -> void:
	_note.text = text


func _mat(color: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m
