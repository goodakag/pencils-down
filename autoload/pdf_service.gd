extends Node
## Autoload "PdfService": the one place scenes open PDFs.

var last_error: String = ""


func open(path: String) -> PdfDoc:
	var d := PdfDoc.open(path)
	last_error = PdfDoc.last_error
	return d
