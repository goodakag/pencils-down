extends SceneTree
# Prints the real PDFium-GDE API so docs/pdfium-gde-api.md matches the installed version.

func _init() -> void:
	for cls in ["PDFDocument", "PDFPage"]:
		print("## ", cls, " (exists: ", ClassDB.class_exists(cls), ", parent: ", ClassDB.get_parent_class(cls), ")")
		for m in ClassDB.class_get_method_list(cls, true):
			var args := []
			for a in m.args:
				args.append("%s: %s" % [a.name, type_string(a.type) if a.type != TYPE_OBJECT else a.class_name])
			print("- ", m.name, "(", ", ".join(args), ") -> ", type_string(m.return.type) if m.return.type != TYPE_OBJECT else m.return.class_name)
		for c in ClassDB.class_get_integer_constant_list(cls, true):
			print("  const ", c, " = ", ClassDB.class_get_integer_constant(cls, c))
	quit()
