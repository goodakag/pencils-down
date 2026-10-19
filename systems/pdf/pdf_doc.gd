class_name PdfDoc
extends RefCounted
## Adapter over PDFium-GDE's PDFDocument. All sizes and rects are PDF points, origin top-left, y down.

static var last_error: String = ""
## PDFium is not thread-safe: every native call (any document) goes through this one lock.
## Godot's Mutex is recursive, so nested calls from the same thread are fine.
static var _lock := Mutex.new()

var path: String
var sha1: String
var _doc: PDFDocument
var _sizes: Dictionary = {}  # page index -> Vector2


static func open(file_path: String) -> PdfDoc:
	last_error = ""
	if not FileAccess.file_exists(file_path):
		last_error = "not_found"
		return null
	var bytes := FileAccess.get_file_as_bytes(file_path)
	var native := PDFDocument.new()
	_lock.lock()
	var err: int = native.load_from_buffer(bytes, "")
	_lock.unlock()
	if err != OK:
		# PDFium-GDE returns ERR_FILE_CANT_OPEN when a password is required.
		last_error = "encrypted" if err == ERR_FILE_CANT_OPEN or _looks_encrypted(bytes) else "corrupt"
		return null
	var d := PdfDoc.new()
	d.path = file_path
	d._doc = native
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	ctx.update(bytes)
	d.sha1 = ctx.finish().hex_encode()
	return d


static func _looks_encrypted(bytes: PackedByteArray) -> bool:
	# Byte search: string conversion would stop at the first NUL in binary PDF data.
	var needle := "/Encrypt".to_ascii_buffer()
	var i := bytes.find(needle[0])
	while i != -1 and i + needle.size() <= bytes.size():
		if bytes.slice(i, i + needle.size()) == needle:
			return true
		i = bytes.find(needle[0], i + 1)
	return false


static func lock() -> void:
	_lock.lock()


static func unlock() -> void:
	_lock.unlock()


func page_count() -> int:
	_lock.lock()
	var n := _doc.get_page_count()
	_lock.unlock()
	return n


func page_size_pt(index: int) -> Vector2:
	_lock.lock()
	if not _sizes.has(index):
		_sizes[index] = _doc.get_page(index).get_page_size()
	var size: Vector2 = _sizes[index]
	_lock.unlock()
	return size


func render_page(index: int, dpi: float) -> Image:
	_lock.lock()
	var img: Image = _doc.get_page(index).render_to_image(dpi / 72.0)
	_lock.unlock()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


## Words on the page: [{ "text": String, "rect": Rect2 }].
func text_words(index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_lock.lock()
	var data: Array = _doc.get_page(index).get_text_data()
	_lock.unlock()
	for w in data:
		out.append({"text": String(w.text), "rect": w.rect as Rect2})
	return out


func text_boxes(index: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for w in text_words(index):
		out.append(w.rect)
	return out


func title() -> String:
	_lock.lock()
	var t := _doc.get_metadata("Title").strip_edges()
	_lock.unlock()
	return t if t != "" else path.get_file().get_basename()


func native() -> PDFDocument:
	return _doc
