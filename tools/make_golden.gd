extends SceneTree
## Regenerates tests/fixtures/golden/mc_letter_p0.png. Inspect the image by eye before committing.

func _init() -> void:
	var img := GoldenFixture.render(ProjectSettings.globalize_path("user://golden_export.pdf"))
	img.save_png(ProjectSettings.globalize_path(GoldenFixture.GOLDEN))
	print("golden written: ", img.get_size())
	quit()
