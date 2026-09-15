extends RefCounted
## Local anonymous diagnostics; no networking, accounts, or personal identifiers.
const FILE := "user://sessions.jsonl"
var enabled := true
var max_bytes := 1048576
var backups := 5

func configure(settings: Dictionary) -> void:
	max_bytes = maxi(1024, int(settings.get("log_limit_bytes", max_bytes)))
	backups = clampi(int(settings.get("log_backups", backups)), 1, 10)

func record(kind: String, session_id: String, data: Dictionary = {}) -> void:
	if not enabled:
		return
	_rotate()
	var file: FileAccess
	if FileAccess.file_exists(FILE):
		file = FileAccess.open(FILE, FileAccess.READ_WRITE)
	else:
		file = FileAccess.open(FILE, FileAccess.WRITE)
	if file == null:
		push_warning("Local session log unavailable; gameplay continues.")
		return
	file.seek_end()
	file.store_line(JSON.stringify({"event": kind, "session_id": session_id,
		"time": Time.get_datetime_string_from_system(true), "data": data}))
	file.close()

func _rotate() -> void:
	if not FileAccess.file_exists(FILE):
		return
	var file := FileAccess.open(FILE, FileAccess.READ)
	if file == null:
		return
	var length := file.get_length()
	file.close()
	if length < max_bytes:
		return
	for index in range(backups, 0, -1):
		var destination := "%s.%d" % [FILE, index]
		var source := FILE if index == 1 else "%s.%d" % [FILE, index - 1]
		if FileAccess.file_exists(destination):
			DirAccess.remove_absolute(destination)
		if FileAccess.file_exists(source):
			DirAccess.rename_absolute(source, destination)
