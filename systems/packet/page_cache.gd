class_name PageCache
extends RefCounted
## Page textures: full DPI for the current page ±1, small thumbnails for everything else,
## so 100+ page tests stay within memory.

var async: bool = true

var _doc: PdfDoc
var _full_dpi: float
var _thumb_dpi: float
var _full: Dictionary = {}     # index -> ImageTexture
var _pending: Dictionary = {}  # index -> WorkerThreadPool task id
var _thumbs: Dictionary = {}   # index -> ImageTexture
var _window := Vector2i(0, -1)
var _mutex := Mutex.new()      # PDFium calls are serialized
var _ready_images: Dictionary = {}  # index -> Image rendered by a worker
var _arrived: bool = false  # a full-res texture arrived since the last poll()


func _init(doc: PdfDoc, full_dpi: float, thumb_dpi: float = 24.0) -> void:
	_doc = doc
	_full_dpi = full_dpi
	_thumb_dpi = thumb_dpi


func texture_for(i: int, current: int) -> Texture2D:
	_set_window(current)
	_collect_finished()
	if i >= _window.x and i <= _window.y:
		if _full.has(i):
			return _full[i]
		_request_full(i)
		if _full.has(i):
			return _full[i]
	return _thumb(i)


func resident_full_pages() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in range(_window.x, _window.y + 1):
		if _full.has(i) or _pending.has(i):
			out.append(i)
	return out


func _set_window(current: int) -> void:
	var w := Vector2i(maxi(current - 1, 0), mini(current + 1, _doc.page_count() - 1))
	if w == _window:
		return
	_window = w
	for k in _full.keys():
		if k < w.x or k > w.y:
			_full.erase(k)
	for i in range(w.x, w.y + 1):
		_request_full(i)


func _request_full(i: int) -> void:
	if _full.has(i) or _pending.has(i):
		return
	if not async:
		_full[i] = ImageTexture.create_from_image(_render(i, _full_dpi))
		return
	_pending[i] = WorkerThreadPool.add_task(_render_job.bind(i))


func _render_job(i: int) -> void:
	var img := _render(i, _full_dpi)
	img.generate_mipmaps()
	_mutex.lock()
	_ready_images[i] = img
	_mutex.unlock()


func _collect_finished() -> void:
	for i in _pending.keys():
		if WorkerThreadPool.is_task_completed(_pending[i]):
			WorkerThreadPool.wait_for_task_completion(_pending[i])
			_pending.erase(i)
			_mutex.lock()
			var img: Image = _ready_images.get(i)
			_ready_images.erase(i)
			_mutex.unlock()
			if img and i >= _window.x and i <= _window.y:
				_full[i] = ImageTexture.create_from_image(img)
				_arrived = true


func _thumb(i: int) -> Texture2D:
	if not _thumbs.has(i):
		_thumbs[i] = ImageTexture.create_from_image(_render(i, _thumb_dpi))
	return _thumbs[i]


func _render(i: int, dpi: float) -> Image:
	_mutex.lock()
	var img := _doc.render_page(i, dpi)
	_mutex.unlock()
	return img


## Call every frame: picks up finished background renders. Returns true once after new full-res
## textures arrive, even if another call collected them first.
func poll() -> bool:
	_collect_finished()
	var arrived := _arrived
	_arrived = false
	return arrived
