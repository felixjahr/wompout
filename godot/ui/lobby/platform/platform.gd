extends ShrinkButton

@onready var player_client := %PlayerClient
@onready var name_label: Label = %PlayerClient.name_label
@onready var ready_label := %ReadyLabel
@onready var rays := %Rays


func render_platform(player: Dictionary, ready: bool, local: bool) -> void:
	name_label.text = str(player.get("displayName", "Player"))
	ready_label.visible = ready
	
	var loadout = player.get("loadout")
	
	var armour_id := str(loadout.get("armourId", ""))
	for armour_sprite in player_client.armour_sprites:
		armour_sprite.texture = Data.ARMOUR[armour_id].texture
	
	var melee_id := str(loadout.get("meleeId", ""))
	player_client.animation_player.play(melee_id + "/idle_" + melee_id)
	
	rays.visible = local
	show()
