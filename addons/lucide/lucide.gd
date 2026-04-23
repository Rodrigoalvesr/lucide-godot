## A [TextureRect] that renders any icon from the Lucide open-source library.
## Set [member icon_name] to the icon's kebab-case identifier (e.g. [code]"house"[/code],
## [code]"circle-check"[/code]) and adjust [member icon_size], [member color], and
## [member stroke_width] to fit your UI. Icons are rasterized on demand and cached for performance.
@tool
class_name Lucide
extends TextureRect

@export var icon_name: String = "":
	set(v):
		icon_name = v
		_reload()

@export var icon_size: float = LucideTexture.DEFAULT_SIZE:
	set(v):
		icon_size = v
		custom_minimum_size = Vector2(v, v)
		size_flags_horizontal = SIZE_SHRINK_CENTER
		size_flags_vertical = SIZE_SHRINK_CENTER
		_reload()

@export var color: Color = LucideTexture.DEFAULT_COLOR:
	set(v):
		color = v
		_reload()

@export var stroke_width: float = LucideTexture.DEFAULT_STROKE:
	set(v):
		stroke_width = v
		_reload()


func _init(p_icon: String = "", p_size: float = LucideTexture.DEFAULT_SIZE, p_color: Color = LucideTexture.DEFAULT_COLOR, p_stroke: float = LucideTexture.DEFAULT_STROKE) -> void:
	stretch_mode = STRETCH_KEEP_ASPECT_CENTERED
	size_flags_horizontal = SIZE_SHRINK_CENTER
	size_flags_vertical = SIZE_SHRINK_CENTER
	icon_size = p_size
	color = p_color
	stroke_width = p_stroke
	icon_name = p_icon


func _reload() -> void:
	texture = LucideTexture.new(icon_name, icon_size, color, stroke_width)
