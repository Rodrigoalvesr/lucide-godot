## A [TextureRect] that renders any icon from the Lucide open-source library.
## Set [member icon_name] to the icon's kebab-case identifier (e.g. [code]"house"[/code],
## [code]"circle-check"[/code]) and adjust [member icon_size], [member color], and
## [member stroke_width] to fit your UI. Icons are rasterized on demand and cached for performance.
@tool
class_name Lucide
extends TextureRect

const DEFAULT_SIZE: float = 24.0
const DEFAULT_STROKE: float = 2.0
const DEFAULT_COLOR: Color = Color.WHITE

const _ICONS_DIR := "res://addons/lucide/icons/%s.svg"
const _SVG_BASE_SIZE := 24.0

var _initialized := false

static var _cache: Dictionary = {}

@export var icon_name: String = "":
	set(v):
		icon_name = v
		_reload()

@export var icon_size: float = DEFAULT_SIZE:
	set(v):
		icon_size = v
		custom_minimum_size = Vector2(v, v)
		size_flags_horizontal = SIZE_SHRINK_CENTER
		size_flags_vertical = SIZE_SHRINK_CENTER
		_reload()

@export var color: Color = DEFAULT_COLOR:
	set(v):
		color = v
		_reload()

@export var stroke_width: float = DEFAULT_STROKE:
	set(v):
		stroke_width = v
		_reload()


func _init(p_icon: String = "", p_size: float = DEFAULT_SIZE, p_color: Color = DEFAULT_COLOR, p_stroke: float = DEFAULT_STROKE) -> void:
	stretch_mode = STRETCH_KEEP_ASPECT_CENTERED
	size_flags_horizontal = SIZE_SHRINK_CENTER
	size_flags_vertical = SIZE_SHRINK_CENTER
	icon_size = p_size
	color = p_color
	stroke_width = p_stroke
	icon_name = p_icon


func _ready() -> void:
	_initialized = true
	_reload()


func _reload() -> void:
	if not _initialized:
		return
	if icon_name.is_empty():
		texture = null
		return
	var path := _ICONS_DIR % icon_name
	if not FileAccess.file_exists(path):
		push_warning("[Lucide] Icon not found: '%s'" % icon_name)
		texture = null
		return
	texture = _load_svg(path, color, icon_size, stroke_width)


static func _load_svg(path: String, p_color: Color, p_size: float, p_stroke: float) -> ImageTexture:
	var key := "%s|%.1f|%s|%.2f" % [path, p_size, p_color.to_html(false), p_stroke]
	if _cache.has(key):
		return _cache[key]
	var hex := "#" + p_color.to_html(false)
	var svg := FileAccess.get_file_as_string(path)
	svg = svg.replace('stroke="currentColor"', 'stroke="%s"' % hex)
	svg = svg.replace('fill="currentColor"', 'fill="%s"' % hex)
	svg = svg.replace('stroke-width="2"', 'stroke-width="%s"' % p_stroke)
	var image := Image.new()
	image.load_svg_from_string(svg, p_size / _SVG_BASE_SIZE)
	var tex := ImageTexture.create_from_image(image)
	_cache[key] = tex
	return tex
