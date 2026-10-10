extends AnimatedButton

@onready var player_client := %PlayerClient
@onready var name_label: Label = %PlayerClient.name_label
@onready var ready_label := %ReadyLabel
@onready var rays := %Rays
@onready var base := %Base


func render_platform(player: Dictionary, ready := false, local := false) -> void:
	name_label.text = str(player["displayName"])
	ready_label.visible = ready
	rays.visible = local
	
	var loadout = player["loadout"]
	
	var armour_id := str(loadout["armourId"])
	for armour_sprite in player_client.armour_sprites:
		armour_sprite.texture = Data.ARMOUR[armour_id].texture
	
	var melee_id := str(loadout["meleeId"])
	player_client.animation_player.play(melee_id + "/idle_" + melee_id)
	
	var style_id := str(loadout["styleId"])
	for body_sprite in player_client.body_sprites:
		body_sprite.self_modulate = Data.STYLE[style_id].color
