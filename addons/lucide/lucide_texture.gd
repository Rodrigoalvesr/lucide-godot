## A [ImageTexture] that renders any icon from the Lucide open-source library.
## Set [member icon_name] to the icon's kebab-case identifier (e.g. [code]"house"[/code],
## [code]"circle-check"[/code]) and adjust [member icon_size], [member color], and
## [member stroke_width] to fit your UI. Icons are rasterized on demand and cached for performance.
@tool
class_name LucideTexture
extends ImageTexture

const DEFAULT_SIZE: float = 24.0
const DEFAULT_STROKE: float = 2.0
const DEFAULT_COLOR: Color = Color.WHITE

const _ICONS_DIR := "res://addons/lucide/icons/%s.svg"
const _SVG_BASE_SIZE := 24.0

static var _cache_icons: Dictionary[String, String] = {}

var _ready := false

@export var icon_name: String = "":
	set(v):
		icon_name = v
		_reload()

@export var icon_size: float = DEFAULT_SIZE:
	set(v):
		icon_size = v
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
	icon_name = p_icon
	icon_size = p_size
	color = p_color
	stroke_width = p_stroke
	_ready = true
	_reload()

func _reload() -> void:
	if not _ready or icon_name.is_empty():
		return
	var svg: String
	if _cache_icons.has(icon_name):
		svg = _cache_icons.get(icon_name)
	else:
		var path := _ICONS_DIR % icon_name
		if not FileAccess.file_exists(path):
			push_warning("[Lucide] Icon not found: '%s'" % icon_name)
			return
		svg = FileAccess.get_file_as_string(path)
		_cache_icons.set(icon_name, svg)
	var hex := "#" + color.to_html(false)
	svg = svg.replace('stroke="currentColor"', 'stroke="%s"' % hex)
	svg = svg.replace('fill="currentColor"', 'fill="%s"' % hex)
	svg = svg.replace('stroke-width="2"', 'stroke-width="%s"' % stroke_width)
	var image := Image.new()
	image.load_svg_from_string(svg, icon_size / _SVG_BASE_SIZE)
	set_image(image)
