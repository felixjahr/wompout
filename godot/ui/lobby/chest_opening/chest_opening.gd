extends TextureRect

const REQUIRED_CLICKS := 5
const CURRENCY_TEXTURES := {
	"coins": preload("res://ui/lobby/coin.png"),
	"gems": preload("res://ui/lobby/gem.png"),
}

enum Phase { CLOSED, CHEST, REVEAL, REWARD }

var phase := Phase.CLOSED
var clicks := 0
var chest_content: Dictionary = {}
var motion_tweens: Array[Tween] = []
var float_tween: Tween
var hit_tween: Tween
var home_positions: Dictionary = {}

@onready var chest: Button = %Chest
@onready var chest_visual: Control = $Chest/TextureRect
@onready var item_card: AnimatedButton = %ItemCard
@onready var item_label = %ItemLabel
@onready var currency_card: AnimatedButton = %CurrencyCard
@onready var currency_burst: GPUParticles2D = %CurrencyBurst
@onready var currency_texture_rect: TextureRect = %CurrencyTextureRect
@onready var currency_label: Label = %CurrencyLabel
@onready var currency_amount_label: Label = %CurrencyAmountLabel
@onready var collect_button: AnimatedButton = %CollectButton


func _ready() -> void:
	hide()


func show_chest_opening(content: Dictionary) -> void:
	_reset_animation()
	chest_content = content.duplicate(true)
	clicks = 0
	phase = Phase.CHEST
	show()
	_cache_positions()
	chest.show()
	chest.disabled = false
	chest_visual.pivot_offset = chest_visual.size / 2.0
	chest_visual.scale = Vector2.ONE * 0.65
	chest_visual.modulate.a = 0.0
	var entrance := _new_tween().set_parallel(true)
	entrance.tween_property(chest_visual, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrance.tween_property(chest_visual, "modulate:a", 1.0, 0.2)
	_start_float()


func _cache_positions() -> void:
	if not home_positions.is_empty():
		return
	for control in [chest_visual, item_card, currency_card, collect_button]:
		home_positions[control] = control.position


func _new_tween() -> Tween:
	var tween := create_tween()
	motion_tweens.append(tween)
	return tween


func _start_float() -> void:
	if float_tween:
		float_tween.kill()
	var home: Vector2 = home_positions[chest_visual]
	float_tween = create_tween().set_loops()
	float_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(chest_visual, "position", home + Vector2(7, -12), 1.15)
	float_tween.parallel().tween_property(chest_visual, "rotation", deg_to_rad(3.0), 1.15)
	float_tween.tween_property(chest_visual, "position", home + Vector2(-7, 8), 1.35)
	float_tween.parallel().tween_property(chest_visual, "rotation", deg_to_rad(-3.0), 1.35)


func _on_chest_pressed() -> void:
	if phase != Phase.CHEST:
		return
	clicks += 1
	if float_tween:
		float_tween.kill()
	if hit_tween:
		hit_tween.kill()
	for tween in motion_tweens:
		tween.kill()
	motion_tweens.clear()
	chest_visual.modulate.a = 1.0
	var direction := -1.0 if clicks % 2 == 0 else 1.0
	var tilt := deg_to_rad(randf_range(9.0, 16.0) + clicks * 2.0) * direction
	hit_tween = create_tween()
	hit_tween.tween_property(chest_visual, "rotation", tilt, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hit_tween.parallel().tween_property(chest_visual, "scale", Vector2(1.12, 0.87), 0.08)
	if clicks >= REQUIRED_CLICKS:
		phase = Phase.REVEAL
		chest.disabled = true
		hit_tween.tween_property(chest_visual, "scale", Vector2.ONE * 1.35, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		hit_tween.parallel().tween_property(chest_visual, "modulate:a", 0.0, 0.16)
		hit_tween.tween_callback(_reveal_reward)
	else:
		hit_tween.tween_property(chest_visual, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		hit_tween.parallel().tween_property(chest_visual, "rotation", -tilt * 0.2, 0.24)
		hit_tween.tween_callback(_start_float)


func _reveal_reward() -> void:
	chest.hide()
	var card: Control = currency_card
	if chest_content["type"] == "item":
		card = item_card
		var item_id: String = chest_content["itemId"]
		item_label.text = item_id.to_upper()
		for category_id in Data.CATEGORIES:
			if Data.CATEGORIES[category_id].has(item_id):
				item_card.render_item_card(category_id, item_id)
				break
	else:
		var currency: String = chest_content["type"]
		currency_texture_rect.texture = CURRENCY_TEXTURES[currency]
		currency_label.text = currency.to_upper()
		currency_amount_label.text = "+" + str(int(chest_content["amount"]))
		currency_amount_label.add_theme_color_override("font_color", Color("f5b51b") if currency == "coins" else Color("18b84a"))
	card.show()
	card.pivot_offset = card.size / 2.0
	card.position = home_positions[card] + Vector2(0, 70)
	card.scale = Vector2.ONE * 0.35
	card.rotation = deg_to_rad(-10.0)
	card.modulate.a = 0.0
	var reveal := _new_tween().set_parallel(true)
	reveal.tween_property(card, "position", home_positions[card], 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_property(card, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(card, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(card, "modulate:a", 1.0, 0.18)
	reveal.chain().tween_callback(_finish_reveal)


func _finish_reveal() -> void:
	phase = Phase.REWARD
	if chest_content["type"] != "item":
		_emit_currency(chest_content["type"], int(chest_content["amount"]))
	collect_button.show()
	collect_button.disabled = false
	collect_button.pivot_offset = collect_button.size / 2.0
	collect_button.scale = Vector2.ONE * 0.8
	collect_button.modulate.a = 0.0
	var reveal := _new_tween().set_parallel(true)
	reveal.tween_property(collect_button, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(collect_button, "modulate:a", 1.0, 0.2)


func _emit_currency(currency: String, amount: int) -> void:
	if amount <= 0:
		return
	var is_coins := currency == "coins"
	var minimum := 500.0 if is_coins else 5.0
	var maximum := 10000.0 if is_coins else 100.0
	var intensity := clampf((float(amount) - minimum) / (maximum - minimum), 0.0, 1.0)
	currency_burst.emitting = false
	currency_burst.texture = CURRENCY_TEXTURES[currency]
	currency_burst.amount = amount
	currency_burst.lifetime = lerpf(2.4 if is_coins else 1.8, 6.0 if is_coins else 3.0, intensity)
	currency_burst.explosiveness = lerpf(0.65, 0.05, intensity)
	var material := currency_burst.process_material as ParticleProcessMaterial
	material.spread = lerpf(65.0, 40.0, intensity)
	material.initial_velocity_min = lerpf(650.0, 900.0, intensity)
	material.initial_velocity_max = lerpf(1000.0, 1250.0, intensity)
	material.scale_min = lerpf(0.16, 0.10, intensity) if is_coins else 0.25
	material.scale_max = lerpf(0.28, 0.18, intensity) if is_coins else 0.40
	currency_burst.restart()
	currency_burst.emitting = true


func _on_collect_button_pressed() -> void:
	if phase != Phase.REWARD:
		return
	_reset_animation()
	hide()


func _reset_animation() -> void:
	phase = Phase.CLOSED
	if float_tween:
		float_tween.kill()
	if hit_tween:
		hit_tween.kill()
	for tween in motion_tweens:
		tween.kill()
	motion_tweens.clear()
	currency_burst.emitting = false
	currency_burst.restart()
	currency_burst.emitting = false
	for button in [item_card, currency_card, collect_button]:
		if button.shrink_tween:
			button.shrink_tween.kill()
		button.visual.scale = Vector2.ONE
	for control in [chest_visual, item_card, currency_card, collect_button]:
		control.scale = Vector2.ONE
		control.rotation = 0.0
		control.modulate = Color.WHITE
		if home_positions.has(control):
			control.position = home_positions[control]
	item_card.hide()
	currency_card.hide()
	collect_button.hide()
