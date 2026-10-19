class_name FallbackPdfWriter
extends RefCounted
## Minimal PDF 1.4 writer: one full-page JPEG per page. Used when vector export isn't possible.


static func write(pages: Array[Image], sizes_pt: Array[Vector2], out_path: String, jpeg_quality: float = 0.85) -> Error:
	var buf := PackedByteArray()
	var offsets: Array[int] = [0]  # index = object number; 0 is the free entry
	var n := pages.size()
	var page_obj := func(i: int) -> int: return 3 + i * 3
	buf.append_array("%PDF-1.4\n%âãÏÓ\n".to_utf8_buffer())
	offsets.append(buf.size())
	buf.append_array("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n".to_ascii_buffer())
	var kids := PackedStringArray()
	for i in n:
		kids.append("%d 0 R" % page_obj.call(i))
	offsets.append(buf.size())
	buf.append_array(("2 0 obj\n<< /Type /Pages /Kids [%s] /Count %d >>\nendobj\n" % [" ".join(kids), n]).to_ascii_buffer())
	for i in n:
		var size: Vector2 = sizes_pt[i]
		var img: Image = pages[i].duplicate()
		img.convert(Image.FORMAT_RGBA8)
		var flat := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		flat.fill(Color.WHITE)
		flat.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
		flat.convert(Image.FORMAT_RGB8)
		var jpg := flat.save_jpg_to_buffer(jpeg_quality)
		var p: int = page_obj.call(i)
		var w := "%.2f" % size.x
		var h := "%.2f" % size.y
		offsets.append(buf.size())
		buf.append_array(("%d 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %s %s] /Resources << /XObject << /Im0 %d 0 R >> >> /Contents %d 0 R >>\nendobj\n" % [p, w, h, p + 2, p + 1]).to_ascii_buffer())
		var content := "q %s 0 0 %s 0 0 cm /Im0 Do Q\n" % [w, h]
		offsets.append(buf.size())
		buf.append_array(("%d 0 obj\n<< /Length %d >>\nstream\n%sendstream\nendobj\n" % [p + 1, content.length(), content]).to_ascii_buffer())
		offsets.append(buf.size())
		buf.append_array(("%d 0 obj\n<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length %d >>\nstream\n" % [p + 2, flat.get_width(), flat.get_height(), jpg.size()]).to_ascii_buffer())
		buf.append_array(jpg)
		buf.append_array("\nendstream\nendobj\n".to_ascii_buffer())
	var xref_at := buf.size()
	var xref := "xref\n0 %d\n0000000000 65535 f \n" % offsets.size()
	for i in range(1, offsets.size()):
		xref += "%010d 00000 n \n" % offsets[i]
	xref += "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % [offsets.size(), xref_at]
	buf.append_array(xref.to_ascii_buffer())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer(buf)
	f.close()
	return OK
