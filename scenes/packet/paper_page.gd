class_name PaperPage
extends MeshInstance3D
## One sheet of paper on the desk. Lies flat in local XZ (facing +Y), top edge toward -Z.
## Pencil ink is drawn by an InkLayer into this page's SubViewport.

const PT_PER_M := 2834.65
const SHADER := preload("res://scenes/packet/paper_page.gdshader")

var size_pt: Vector2 = Vector2(612, 792)
var ink_dpi: float = 150.0
var _mat: ShaderMaterial
var _viewport: SubViewport
var _ink_layer: InkLayer


func _init() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material_override = _mat
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	_ink_layer = InkLayer.new()
	_viewport.add_child(_ink_layer)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func set_page(tex: Texture2D, page_size_pt: Vector2, dpi: float = 150.0) -> void:
	size_pt = page_size_pt
	ink_dpi = dpi
	var m := size_m()
	var plane := PlaneMesh.new()
	plane.size = m
	plane.subdivide_width = 6
	plane.subdivide_depth = 24
	mesh = plane
	_mat.set_shader_parameter("page_len", m.y)
	set_texture(tex)
	_viewport.size = Vector2i((page_size_pt * dpi / 72.0).ceil())
	_mat.set_shader_parameter("ink_tex", _viewport.get_texture())


func set_texture(tex: Texture2D) -> void:
	_mat.set_shader_parameter("has_page", tex != null)
	_mat.set_shader_parameter("page_tex", tex)


func size_m() -> Vector2:
	return size_pt / PT_PER_M


func set_curl(v: float) -> void:
	_mat.set_shader_parameter("curl", v)


func get_curl() -> float:
	return _mat.get_shader_parameter("curl")


func set_lift(v: float) -> void:
	_mat.set_shader_parameter("lift", v)


func ink_viewport() -> SubViewport:
	return _viewport


func ink_layer() -> InkLayer:
	return _ink_layer


func show_ink(ink: PageInk) -> void:
	_ink_layer.show_ink(ink, ink_dpi)


## Redraw the ink texture on the next frame.
func mark_ink_dirty() -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Local point on the (flat) page → PDF points, origin top-left.
func local_to_pt(local: Vector3) -> Vector2:
	var m := size_m()
	var uv := Vector2(local.x / m.x + 0.5, local.z / m.y + 0.5)
	return PageMapper.uv_to_pt(uv, size_pt)


## PDF points → local point on the flat page.
func pt_to_local(p: Vector2) -> Vector3:
	var m := size_m()
	var uv := PageMapper.pt_to_uv(p, size_pt)
	return Vector3((uv.x - 0.5) * m.x, 0.0, (uv.y - 0.5) * m.y)
