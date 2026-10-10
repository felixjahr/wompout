extends ModeServer

const DRAFT_TIME_LIMIT := 10.0
const AUTO_DRAFT_ANIMATION_SECONDS := 2.0

var draft_options: Dictionary[String, Array] = {}
var draft_picks: Dictionary[String, Array] = {}
var draft_started_at: Dictionary[String, float] = {}
var submitted_drafts: Dictionary[String, int] = {}
var auto_draft_until: Dictionary[String, float] = {}

var loadouts: Dictionary[String, Dictionary] = {}


func _enter_preparing() -> void:
	var pool := _generate_draft_pool()

	for participant_id in remaining_ids:
		draft_options[participant_id] = [
			pool.pop_back(),
			pool.pop_back(),
		]
		draft_picks[participant_id] = []

	for bot in bots:
		_submit_draft(str(bot["id"]), [], true, false)


func _on_player_received(player_id: String) -> void:
	if state != ModeState.PREPARING:
		return
	if not remaining_ids.has(player_id):
		return
	if not draft_options.has(player_id):
		return

	if not draft_started_at.has(player_id):
		draft_started_at[player_id] = Time.get_ticks_msec() / 1000.0


func _process(_delta: float) -> void:
	if state != ModeState.PREPARING:
		return

	var now := Time.get_ticks_msec() / 1000.0

	for participant_id in remaining_ids:
		if submitted_drafts.has(participant_id):
			continue
		if not draft_started_at.has(participant_id):
			continue

		if now - draft_started_at[participant_id] >= DRAFT_TIME_LIMIT:
			_submit_draft(
				participant_id,
				draft_picks[participant_id],
				true,
				true
			)

	_try_start_fight()


func _try_start_fight() -> void:
	if state != ModeState.PREPARING:
		return
	if remaining_ids.size() != 2:
		return

	var now := Time.get_ticks_msec() / 1000.0

	for participant_id in remaining_ids:
		if not submitted_drafts.has(participant_id):
			return
		if now < auto_draft_until.get(participant_id, 0.0):
			return

	_change_state(ModeState.FIGHT)


func _generate_draft_pool() -> Array[Dictionary]:
	var categories := ["melee", "ranged", "armour", "ability"]
	categories.shuffle()

	var pool: Array[Dictionary] = []

	for category in categories:
		var item_ids: Array = Data.CATEGORIES[category].keys()
		item_ids.shuffle()

		pool.append({
			"category_id": category,
			"option_ids": [item_ids[0], item_ids[1]],
		})

	return pool


func _validated_picks(
	participant_id: String,
	raw_picks: Variant
) -> Array[int]:
	var picks: Array[int] = []

	if not (raw_picks is Array):
		return picks

	var count := mini(
		draft_options[participant_id].size(),
		raw_picks.size()
	)

	for i in count:
		var value: Variant = raw_picks[i]
		var pick := 0

		if value is int or value is float:
			if value == 1:
				pick = 1

		picks.append(pick)

	return picks


func _submit_draft(
	participant_id: String,
	raw_picks: Variant,
	fill_randomly: bool,
	delay_for_reveal: bool
) -> void:
	if submitted_drafts.has(participant_id):
		return

	var picks := _validated_picks(participant_id, raw_picks)
	submitted_drafts[participant_id] = picks.size()

	while picks.size() < draft_options[participant_id].size():
		picks.append(
			randi_range(0, 1) if fill_randomly else 0
		)

	draft_picks[participant_id] = picks

	if fill_randomly:
		auto_draft_until[participant_id] = (
			Time.get_ticks_msec() / 1000.0 + AUTO_DRAFT_ANIMATION_SECONDS
			if delay_for_reveal
			else 0.0
		)

	_sync_player(participant_id)


func _enter_fight() -> void:
	var first_id: String = remaining_ids[0]
	var second_id: String = remaining_ids[1]

	for participant_id in remaining_ids:
		loadouts[participant_id] = {
			"styleId": super._get_loadout(participant_id)["styleId"],
		}

	for participant_id in remaining_ids:
		var other_id := (
			second_id if participant_id == first_id else first_id
		)
		var options: Array = draft_options[participant_id]
		var picks: Array = draft_picks[participant_id]

		for i in options.size():
			var option: Dictionary = options[i]
			var item_ids: Array = option["option_ids"]
			var pick: int = picks[i]
			var key := str(option["category_id"]) + "Id"

			loadouts[participant_id][key] = item_ids[pick]
			loadouts[other_id][key] = item_ids[1 - pick]


func _get_loadout(participant_id: String) -> Dictionary:
	if loadouts.has(participant_id):
		return loadouts[participant_id]
	return super._get_loadout(participant_id)


func _on_net_game_request_received(
	player_id: String,
	request: GameRequest
) -> void:
	if state != ModeState.PREPARING:
		return
	if not remaining_ids.has(player_id):
		return
	if not draft_started_at.has(player_id):
		return

	if submitted_drafts.has(player_id):
		_sync_player(player_id)
		return

	if Time.get_ticks_msec() / 1000.0 - draft_started_at[player_id] >= DRAFT_TIME_LIMIT:
		_submit_draft(
			player_id,
			draft_picks[player_id],
			true,
			true
		)
		return

	match request.type:
		GameRequest.Type.DRAFT_PROGRESS:
			draft_picks[player_id] = _validated_picks(
				player_id,
				request.payload
			)

		GameRequest.Type.DRAFT_RESULT:
			_submit_draft(
				player_id,
				request.payload,
				false,
				false
			)


func _build_state_payload(participant_id: String) -> Dictionary:
	if state != ModeState.PREPARING:
		return {}
	if not draft_options.has(participant_id):
		return {}

	var elapsed := 0.0
	if draft_started_at.has(participant_id):
		elapsed = clampf(
			Time.get_ticks_msec() / 1000.0 - draft_started_at[participant_id],
			0.0,
			DRAFT_TIME_LIMIT
		)

	return {
		"draft_options": draft_options[participant_id].duplicate(true),
		"draft_submitted": submitted_drafts.has(participant_id),
		"draft_picks": draft_picks[participant_id].duplicate(),
		"draft_auto_picked": auto_draft_until.has(participant_id),
		"draft_manual_pick_count": submitted_drafts.get(
			participant_id,
			draft_picks[participant_id].size()
		),
		"draft_time_limit": DRAFT_TIME_LIMIT,
		"draft_elapsed": elapsed,
	}
