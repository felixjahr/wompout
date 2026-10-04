extends Control

signal draft_pick_made(draft_result: Array[int])
signal draft_finished(draft_result: Array[int])

@onready var card_a := $MarginContainer/HBoxContainer/HBoxContainer/CardA
@onready var card_b := $MarginContainer/HBoxContainer/HBoxContainer/CardB

@onready var left_slots_container := $MarginContainer/HBoxContainer/LeftSlotsContainer
@onready var right_slots_container := $MarginContainer/HBoxContainer/RightSlotsContainer
@onready var timer_progress_bar := $TimerProgressBar

var current_option: Dictionary
var current_slot_index := 0

var draft_options: Array[Dictionary]
var draft_result: Array[int] = []
var time_limit_seconds := 30.0
var elapsed_seconds := 0.0
var input_locked := false
var submitted := false

var _all_draft_options: Array = []
var _visible_draft_result: Array[int] = []


func _ready() -> void:
	timer_progress_bar.min_value = 0.0
	timer_progress_bar.max_value = 100.0
	_all_draft_options = draft_options.duplicate(true)
	card_a.pressed.connect(_on_card_selected.bind(0))
	card_b.pressed.connect(_on_card_selected.bind(1))
	_restore_completed_picks()
	if submitted:
		card_a.hide()
		card_b.hide()
	else:
		_show_next_category()


func _process(delta: float) -> void:
	elapsed_seconds = min(time_limit_seconds, elapsed_seconds + delta)
	_update_timer_progress()
	if elapsed_seconds >= time_limit_seconds:
		input_locked = true
		card_a.disabled = true
		card_b.disabled = true


func animate_server_picks(server_draft_result: Array[int]) -> void:
	input_locked = true
	submitted = true
	timer_progress_bar.value = 100.0
	draft_result = server_draft_result.duplicate()
	await _animate_remaining_server_picks()


func _show_next_category() -> void:
	if current_slot_index >= _all_draft_options.size():
		if not submitted:
			submitted = true
			emit_signal("draft_finished", draft_result)
		card_a.hide()
		card_b.hide()
		return
	
	current_option = _all_draft_options[current_slot_index]
	_show_current_option()
	card_a.disabled = input_locked
	card_b.disabled = input_locked


func _on_card_selected(index: int) -> void:
	if input_locked or submitted:
		return
	card_a.disabled = true
	card_b.disabled = true
	var slot_index := current_slot_index
	draft_result.append(index)
	_visible_draft_result.append(index)
	emit_signal("draft_pick_made", draft_result)
	_animate_current_option_to_slots(index, slot_index, true)


func _animate_current_option_to_slots(pick: int, slot_index: int, advance_after_animation := true) -> void:
	var selected_btn = card_a if pick == 0 else card_b
	var unselected_btn = card_b if pick == 0 else card_a
	var target_slots := _get_draft_slots(slot_index)
	var target_left_slot: TextureRect = target_slots["selected"]
	var target_right_slot: TextureRect = target_slots["unselected"]
	await _wait_for_layout()
	var selected_start_rect: Rect2 = selected_btn.get_global_rect()
	var unselected_start_rect: Rect2 = unselected_btn.get_global_rect()
	var selected_target_rect: Rect2 = target_left_slot.get_global_rect()
	var unselected_target_rect: Rect2 = target_right_slot.get_global_rect()
	
	var flying_selected: Button = _create_flying_card(selected_btn)
	var flying_unselected: Button = _create_flying_card(unselected_btn)
	add_child(flying_selected)
	add_child(flying_unselected)
	
	_fit_card_to_global_rect(flying_selected, selected_start_rect)
	_fit_card_to_global_rect(flying_unselected, unselected_start_rect)
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(flying_selected, "global_position", selected_target_rect.position, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(flying_selected, "size", selected_target_rect.size, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(flying_unselected, "global_position", unselected_target_rect.position, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(flying_unselected, "size", unselected_target_rect.size, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(
		func():
			_place_card_in_slot(flying_selected, target_left_slot)
			_place_card_in_slot(flying_unselected, target_right_slot)
			
			current_slot_index = max(current_slot_index, slot_index + 1)
			if advance_after_animation:
				_show_next_category()
	)
	
	card_a.hide()
	card_b.hide()
	await tween.finished


func _create_flying_card(btn: Button) -> Button:
	var card_copy = btn.duplicate()
	card_copy.disabled = true
	
	var glow = card_copy.get_node("GlowTexture")
	glow.queue_free()
	
	card_copy.custom_minimum_size = Vector2.ZERO
	card_copy.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)
	
	return card_copy


func _restore_completed_picks() -> void:
	var completed_count = min(draft_result.size(), _all_draft_options.size())
	var restored_result: Array[int] = []
	for i in completed_count:
		var pick = draft_result[i]
		pick = pick if pick == 0 or pick == 1 else 0
		_embed_pick_in_slots(_all_draft_options[i], pick, i)
		restored_result.append(pick)
	current_slot_index = completed_count
	_visible_draft_result = restored_result.duplicate()
	draft_result = restored_result
	_update_timer_progress()


func _embed_pick_in_slots(option: Dictionary, pick: int, slot_index: int) -> void:
	var target_slots := _get_draft_slots(slot_index)
	var selected_slot: TextureRect = target_slots["selected"]
	var unselected_slot: TextureRect = target_slots["unselected"]
	var selected_card := _create_slot_card(option, pick)
	var unselected_card := _create_slot_card(option, 0 if pick == 1 else 1)
	_place_card_in_slot(selected_card, selected_slot)
	_place_card_in_slot(unselected_card, unselected_slot)


func _create_slot_card(option: Dictionary, pick: int) -> Button:
	var card_copy = card_a.duplicate()
	card_copy.disabled = true
	var category_id = option["category_id"]
	var option_ids = option["option_ids"]
	card_copy.get_node("ItemTexture").texture = Data.CATEGORIES[category_id][option_ids[pick]].card_texture
	var glow = card_copy.get_node("GlowTexture")
	glow.queue_free()
	card_copy.custom_minimum_size = Vector2.ZERO
	card_copy.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)
	return card_copy


func _get_draft_slots(slot_index: int) -> Dictionary:
	return {
		"selected": left_slots_container.get_child(slot_index),
		"unselected": right_slots_container.get_child(slot_index),
	}


func _place_card_in_slot(card: Button, target_slot: TextureRect) -> void:
	if card.get_parent() != target_slot:
		if card.get_parent() != null:
			card.reparent(target_slot)
		else:
			target_slot.add_child(card)
	_fit_card_to_slot(card, target_slot)
	target_slot.self_modulate = Color.TRANSPARENT


func _fit_card_to_slot(card: Button, target_slot: TextureRect) -> void:
	card.custom_minimum_size = Vector2.ZERO
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)
	card.position = Vector2.ZERO
	card.size = target_slot.size


func _fit_card_to_global_rect(card: Button, rect: Rect2) -> void:
	card.custom_minimum_size = Vector2.ZERO
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)
	card.global_position = rect.position
	card.size = rect.size


func _wait_for_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _update_timer_progress() -> void:
	if time_limit_seconds <= 0.0:
		timer_progress_bar.value = 100.0
		return
	timer_progress_bar.value = clamp((elapsed_seconds / time_limit_seconds) * 100.0, 0.0, 100.0)


func _animate_remaining_server_picks() -> void:
	while _visible_draft_result.size() < draft_result.size() and _visible_draft_result.size() < _all_draft_options.size():
		var slot_index := _visible_draft_result.size()
		current_slot_index = slot_index
		current_option = _all_draft_options[slot_index]
		var pick := draft_result[slot_index]
		_show_current_option()
		await get_tree().process_frame
		_visible_draft_result.append(pick)
		await _animate_current_option_to_slots(pick, slot_index, false)
	card_a.hide()
	card_b.hide()


func _show_current_option() -> void:
	var current_category_id = current_option["category_id"]
	var current_options_ids = current_option["option_ids"]
	var texture_a: Texture2D = Data.CATEGORIES[current_category_id][current_options_ids[0]].card_texture
	var texture_b: Texture2D = Data.CATEGORIES[current_category_id][current_options_ids[1]].card_texture
	card_a.get_node("ItemTexture").texture = texture_a
	card_b.get_node("ItemTexture").texture = texture_b
	card_a.disabled = true
	card_b.disabled = true
	card_a.show()
	card_b.show()
