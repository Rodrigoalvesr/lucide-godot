@tool
extends EditorPlugin

const ICONS_DIR = "res://addons/lucide/icons/"
const VERSION_FILE = "res://addons/lucide/.lucide-version"
const API_URL = "https://api.github.com/repos/lucide-icons/lucide/releases/latest"
const VERSION_TEXT := "Lucide: %s"

var _http: HTTPRequest
var _panel: Control
var _icon_size: float = LucideTexture.DEFAULT_SIZE
var _stroke_width: float = LucideTexture.DEFAULT_STROKE
var _icon_color: Color = LucideTexture.DEFAULT_COLOR
var _update_token: int = 0


func _enter_tree() -> void:
	var icon := load("res://addons/lucide/icon.svg")
	add_custom_type("LucideTexture", "ImageTexture", preload("lucide_texture.gd"), icon)
	add_custom_type("Lucide", "TextureRect", preload("lucide.gd"), icon)

	_build_panel()
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _panel)

	if not DirAccess.dir_exists_absolute(ICONS_DIR):
		_fetch_latest_and_download()
	else:
		_update_panel_version(_read_installed_version())
		_populate_icon_list()


func _exit_tree() -> void:
	if _panel:
		remove_control_from_docks(_panel)
		_panel.queue_free()

	if _http:
		_http.queue_free()


# ─── Panel ────────────────────────────────────────────────────────────────────

func _build_panel() -> void:
	_panel = VBoxContainer.new()
	_panel.name = "Lucide Icons"

	var search := LineEdit.new()
	search.name = "SearchField"
	search.placeholder_text = "Search icon..."
	search.text_changed.connect(_on_search_changed)
	_panel.add_child(search)

	var size_row := HBoxContainer.new()
	size_row.name = "SizeRow"
	var size_title := Label.new()
	size_title.text = "Size:"
	size_title.custom_minimum_size = Vector2(72, 0)
	size_row.add_child(size_title)
	var size_slider := HSlider.new()
	size_slider.name = "SizeSlider"
	size_slider.min_value = 8
	size_slider.max_value = 128
	size_slider.step = 4
	size_slider.value = _icon_size
	size_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	size_slider.value_changed.connect(_on_size_changed)
	size_row.add_child(size_slider)
	var size_label := Label.new()
	size_label.name = "SizeLabel"
	size_label.text = "%d px" % _icon_size
	size_label.custom_minimum_size = Vector2(72, 0)
	size_row.add_child(size_label)
	_panel.add_child(size_row)

	var stroke_row := HBoxContainer.new()
	stroke_row.name = "StrokeRow"
	var stroke_title := Label.new()
	stroke_title.text = "Stroke:"
	stroke_title.custom_minimum_size = Vector2(72, 0)
	stroke_row.add_child(stroke_title)
	var stroke_slider := HSlider.new()
	stroke_slider.name = "StrokeSlider"
	stroke_slider.min_value = 0.5
	stroke_slider.max_value = 5.0
	stroke_slider.step = 0.5
	stroke_slider.value = _stroke_width
	stroke_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stroke_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stroke_slider.value_changed.connect(_on_stroke_changed)
	stroke_row.add_child(stroke_slider)
	var stroke_label := Label.new()
	stroke_label.name = "StrokeLabel"
	stroke_label.text = "%.1f" % _stroke_width
	stroke_label.custom_minimum_size = Vector2(72, 0)
	stroke_row.add_child(stroke_label)
	_panel.add_child(stroke_row)

	var color_row := HBoxContainer.new()
	color_row.name = "ColorRow"
	var color_label := Label.new()
	color_label.text = "Color:"
	color_label.custom_minimum_size = Vector2(72, 0)
	color_row.add_child(color_label)
	var color_picker := ColorPickerButton.new()
	color_picker.name = "ColorPicker"
	color_picker.color = _icon_color
	color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_picker.color_changed.connect(_on_color_changed)
	color_row.add_child(color_picker)
	_panel.add_child(color_row)

	var scroll := ScrollContainer.new()
	scroll.name = "IconScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	_panel.add_child(scroll)

	var list := VBoxContainer.new()
	list.name = "IconList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var footer := HBoxContainer.new()
	footer.name = "FooterRow"

	var version_label := Label.new()
	version_label.name = "VersionLabel"
	version_label.text = VERSION_TEXT % "—"
	version_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	version_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	footer.add_child(version_label)

	var btn := Button.new()
	btn.name = "UpdateBtn"
	btn.text = "Update"
	btn.pressed.connect(_on_update_pressed)
	footer.add_child(btn)

	_panel.add_child(footer)


func _update_panel_version(version: String) -> void:
	if not _panel:
		return
	var label: Label = _panel.get_node_or_null("FooterRow/VersionLabel")
	if label:
		label.text = VERSION_TEXT % "v%s" % (version if version != "" else "unknown")


func _set_btn_enabled(enabled: bool) -> void:
	if not _panel:
		return
	var btn: Button = _panel.get_node_or_null("UpdateBtn")
	if btn:
		btn.disabled = not enabled


# ─── Version helpers ──────────────────────────────────────────────────────────

func _read_installed_version() -> String:
	if not FileAccess.file_exists(VERSION_FILE):
		return ""
	var text := FileAccess.get_file_as_string(VERSION_FILE).strip_edges()
	var json = JSON.parse_string(text)
	if json is Dictionary:
		return json.get("version", "")
	return ""


func _save_version(version: String) -> void:
	var data := {"version": version}
	var f := FileAccess.open(VERSION_FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


# ─── HTTP helper ──────────────────────────────────────────────────────────────

func _make_http() -> void:
	if _http:
		_http.queue_free()
	_http = HTTPRequest.new()
	add_child(_http)


# ─── Fetch latest release info ────────────────────────────────────────────────

func _fetch_latest_and_download() -> void:
	_set_btn_enabled(false)
	_make_http()
	_http.request_completed.connect(_on_version_fetched.bind(false), CONNECT_ONE_SHOT)
	_http.request(API_URL, ["User-Agent: GodotPlugin"])


func _on_update_pressed() -> void:
	_set_btn_enabled(false)
	_make_http()
	_http.request_completed.connect(_on_version_fetched.bind(true), CONNECT_ONE_SHOT)
	_http.request(API_URL, ["User-Agent: GodotPlugin"])


func _on_version_fetched(result: int, code: int, _headers, body: PackedByteArray, check_update: bool) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_btn_enabled(true)
		push_error("[Lucide] Error querying GitHub API (result=%d, code=%d)" % [result, code])
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json is Dictionary or not json.has("tag_name"):
		_set_btn_enabled(true)
		return

	var latest: String = json["tag_name"]

	var zip_url := ""
	for asset in json.get("assets", []):
		var asset_name := asset["name"] as String
		if asset_name.begins_with("lucide-icons-") and asset_name.ends_with(".zip"):
			zip_url = asset["browser_download_url"]
			break

	if zip_url == "":
		_set_btn_enabled(true)
		push_error("[Lucide] No ZIP found in release assets %s." % latest)
		return

	var installed := _read_installed_version()

	if check_update and installed == latest:
		_set_btn_enabled(true)
		print("[Lucide] Already on the latest version: %s" % latest)
		return

	print("[Lucide] Updating %s → %s" % [installed if installed != "" else "?", latest])
	_download_icons(latest, zip_url)


# ─── Download & extract ───────────────────────────────────────────────────────

func _download_icons(version: String, url: String) -> void:
	DirAccess.make_dir_recursive_absolute(ICONS_DIR)
	_set_btn_enabled(false)

	_make_http()
	_http.request_completed.connect(_on_download_complete.bind(version), CONNECT_ONE_SHOT)
	_http.request(url)
	print("[Lucide] Downloading from: %s" % url)


func _on_download_complete(result: int, code: int, _headers, body: PackedByteArray, version: String) -> void:
	_set_btn_enabled(true)

	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_error("[Lucide] Failed to download icons (result=%d, code=%d)" % [result, code])
		return


	var zip_path := "res://addons/lucide/icons.zip"
	var f := FileAccess.open(zip_path, FileAccess.WRITE)
	if not f:
		push_error("[Lucide] Failed to write ZIP file: %s" % zip_path)
		return
	f.store_buffer(body)
	f.close()

	_extract_zip(zip_path, ICONS_DIR)
	DirAccess.remove_absolute(zip_path)

	_save_version(version)
	_update_panel_version(version)
	EditorInterface.get_resource_filesystem().scan()
	_populate_icon_list()

	print("[Lucide] Icons installed (version %s)." % version)


func _extract_zip(zip_path: String, dest: String) -> void:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		push_error("[Lucide] Failed to open ZIP: %s" % zip_path)
		return

	for file in zip.get_files():
		if file.ends_with(".svg"):
			var data := zip.read_file(file)
			var out := FileAccess.open(dest + file.get_file(), FileAccess.WRITE)
			if out:
				out.store_buffer(data)
				out.close()
			else:
				push_error("[Lucide] Failed to create file: %s" % (dest + file.get_file()))

	zip.close()


# ─── Icon list ────────────────────────────────────────────────────────────────

func _on_search_changed(text: String) -> void:
	_populate_icon_list(text)


func _on_size_changed(value: float) -> void:
	_icon_size = int(value)
	var label: Label = _panel.get_node_or_null("SizeRow/SizeLabel")
	if label:
		label.text = "%d px" % _icon_size
	_schedule_icon_update()


func _on_stroke_changed(value: float) -> void:
	_stroke_width = value
	var label: Label = _panel.get_node_or_null("StrokeRow/StrokeLabel")
	if label:
		label.text = "%.1f" % _stroke_width
	_schedule_icon_update()


func _on_color_changed(color: Color) -> void:
	_icon_color = color
	_schedule_icon_update()


func _get_current_filter() -> String:
	var search: LineEdit = _panel.get_node_or_null("SearchField")
	return search.text if search else ""


func _schedule_icon_update() -> void:
	_update_token += 1
	var token := _update_token
	get_tree().create_timer(0.15).timeout.connect(func():
		if token == _update_token:
			_update_icons_in_place()
	)


func _update_icons_in_place() -> void:
	if not _panel:
		return
	var list: VBoxContainer = _panel.get_node_or_null("IconScroll/IconList")
	if not list:
		return
	for row in list.get_children():
		var icon = row.get_node_or_null("LucideIcon")
		if icon:
			icon.icon_size = _icon_size
			icon.color = _icon_color
			icon.stroke_width = _stroke_width


func _populate_icon_list(filter: String = "") -> void:
	if not _panel:
		return
	var list: VBoxContainer = _panel.get_node_or_null("IconScroll/IconList")
	if not list:
		return

	for child in list.get_children():
		child.queue_free()

	if not DirAccess.dir_exists_absolute(ICONS_DIR):
		return

	var dir := DirAccess.open(ICONS_DIR)
	if not dir:
		return

	var files: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".svg"):
			files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()

	var filter_lower := filter.to_lower()
	for f in files:
		var icon_name := f.get_basename()
		if filter_lower != "" and not icon_name.to_lower().contains(filter_lower):
			continue

		var row := HBoxContainer.new()

		var icon := Lucide.new(icon_name)
		icon.name = "LucideIcon"
		icon.icon_size = _icon_size
		icon.color = _icon_color
		icon.stroke_width = _stroke_width
		row.add_child(icon)

		var label := Label.new()
		label.text = icon_name
		label.clip_text = true
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(label)

		var copy_btn := Button.new()
		copy_btn.text = "Copy code"
		copy_btn.pressed.connect(_copy_icon.bind(icon_name))
		row.add_child(copy_btn)

		list.add_child(row)


func _copy_icon(icon_name: String) -> void:
	var text := "var icon := Lucide.new(\"%s\", %d, Color(%s, %s, %s, %s), %s)" % [
		icon_name,
		_icon_size,
		snappedf(_icon_color.r, 0.001),
		snappedf(_icon_color.g, 0.001),
		snappedf(_icon_color.b, 0.001),
		snappedf(_icon_color.a, 0.001),
		_stroke_width,
	]
	DisplayServer.clipboard_set(text)
	print("[Lucide] %s copied!" % icon_name)