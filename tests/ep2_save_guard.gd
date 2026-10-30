extends RefCounted
## Tests that exercise real inventory/checkpoint writes preserve the caller's save.
var existed: bool=FileAccess.file_exists(GameManager.SAVE_PATH)
var contents: String=FileAccess.get_file_as_string(GameManager.SAVE_PATH) if existed else ""
func restore() -> void:
	if existed:
		var file:=FileAccess.open(GameManager.SAVE_PATH,FileAccess.WRITE)
		if file!=null:file.store_string(contents)
	elif FileAccess.file_exists(GameManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameManager.SAVE_PATH))
