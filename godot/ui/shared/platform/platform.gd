extends AnimatedButton

@onready var player_client := %PlayerClient
@onready var name_label: Label = %PlayerClient.name_label
@onready var ready_label := %ReadyLabel
@onready var rays := %Rays
@onready var base := %Base


func render_platform(player: Dictionary, ready := false, local := false, falling := false) -> void:
	name_label.text = str(player["displayName"])
	ready_label.visible = ready
	rays.visible = local
	
	var loadout = player["loadout"]
	
	var armour_id := str(loadout.get("armourId", ""))
	for armour_sprite in player_client.armour_sprites:
		armour_sprite.texture = Data.ARMOUR[armour_id].texture
	
	var melee_id := str(loadout.get("meleeId", ""))
	if not falling:
		player_client.animation_player.play(melee_id + "/idle_" + melee_id)
	else:
		player_client.animation_player.play(melee_id + "/fall_" + melee_id)
		name_label.hide()
		base.hide()
