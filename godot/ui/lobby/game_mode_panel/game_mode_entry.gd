extends AnimatedButton

var scale_tween: Tween

@onready var game_mode_label := %GameModeLabel
@onready var ranked_label := %RankedLabel
@onready var game_mode_texture_rect := %GameModeTextureRect
@onready var thumnnail_texture_rect := %ThumbnailTextureRect


func render_game_mode_entry(mode_id: String) -> void:
	var mode := Data.MODES[mode_id]
	game_mode_label.text = mode.display_name
	ranked_label.text = "RANKED" if mode.ranked else "UNRANKED"
	var ranked_label_color := Color("f5b51b") if mode.ranked else Color("3d70ff")
	ranked_label.add_theme_color_override("font_color", ranked_label_color)
	game_mode_texture_rect.texture = mode.icon_texture
	thumnnail_texture_rect.texture = mode.thumbnail_texture
