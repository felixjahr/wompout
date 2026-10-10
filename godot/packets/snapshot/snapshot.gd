class_name Snapshot
extends RefCounted

const POSITION_SCALE := 4.0
const VELOCITY_SCALE := 4.0
const AIM_SCALE := 127.0
const SIGNED_16_BIAS := 32768
const SIGNED_8_BIAS := 128

var tick: int
var local_team_id: int

var participants: Array[ParticipantSnapshot] = []
var bullets: Array[BulletSnapshot] = []
var events: Array[EventSnapshot] = []


func to_packet() -> PackedByteArray:
	var peer := StreamPeerBuffer.new()
	peer.big_endian = false
	peer.put_u32(tick)
	peer.put_u8(local_team_id)
	peer.put_u8(participants.size())
	peer.put_u8(bullets.size())
	peer.put_u8(events.size())
	for snapshot in participants:
		_write_player(peer, snapshot)
	for snapshot in bullets:
		_write_bullet(peer, snapshot)
	for snapshot in events:
		_write_event(peer, snapshot)
	return peer.data_array


static func from_packet(packet: PackedByteArray) -> Snapshot:
	var peer := StreamPeerBuffer.new()
	peer.big_endian = false
	peer.data_array = packet
	var snapshot := Snapshot.new()
	snapshot.tick = int(peer.get_u32())
	snapshot.local_team_id = int(peer.get_u8())
	var player_count := int(peer.get_u8())
	var bullet_count := int(peer.get_u8())
	var event_count := int(peer.get_u8())
	snapshot.participants = []
	for i in player_count:
		snapshot.participants.append(_read_player(peer))
	snapshot.bullets = []
	for i in bullet_count:
		snapshot.bullets.append(_read_bullet(peer))
	snapshot.events = []
	for i in event_count:
		snapshot.events.append(_read_event(peer))
	return snapshot


static func _write_player(peer: StreamPeerBuffer, snapshot: ParticipantSnapshot) -> void:
	_write_string(peer, snapshot.participant_id)
	peer.put_u8(snapshot.team_id)
	_write_quantized_vector2(peer, snapshot.position, POSITION_SCALE)
	_write_quantized_vector2(peer, snapshot.velocity, VELOCITY_SCALE)
	peer.put_u16(clampi(snapshot.health, 0, 65535))
	peer.put_u8(clampi(snapshot.hearts, 0, 255))
	var flags := 0
	if snapshot.facing < 0:
		flags |= 1
	if snapshot.is_on_floor:
		flags |= 2
	if snapshot.attacking:
		flags |= 4
	if snapshot.ability_active:
		flags |= 8
	peer.put_u8(flags)
	peer.put_u8(clampi(snapshot.current_weapon, 0, 255))
	_write_quantized_unit_vector2(peer, snapshot.aim_direction)
	peer.put_u8(_encode_id(snapshot.melee_id, Data.MELEE_IDS))
	peer.put_u16(clampi(snapshot.melee_ammunition, 0, 65535))
	peer.put_float(snapshot.melee_recharge_time)
	peer.put_u8(_encode_id(snapshot.ranged_id, Data.RANGED_IDS))
	peer.put_u16(clampi(snapshot.ranged_ammunition, 0, 65535))
	peer.put_float(snapshot.ranged_recharge_time)
	peer.put_u8(_encode_id(snapshot.armour_id, Data.ARMOUR_IDS))
	peer.put_u8(_encode_id(snapshot.ability_id, Data.ABILITY_IDS))
	peer.put_u8(_encode_id(snapshot.style_id, Data.STYLE_IDS))
	peer.put_u32(maxi(snapshot.last_ability + 1, 0))
	peer.put_u16(clampi(snapshot.ability_charge, 0, 65535))


static func _read_player(peer: StreamPeerBuffer) -> ParticipantSnapshot:
	var snapshot := ParticipantSnapshot.new()
	snapshot.participant_id = _read_string(peer)
	snapshot.team_id = int(peer.get_u8())
	snapshot.position = _read_quantized_vector2(peer, POSITION_SCALE)
	snapshot.velocity = _read_quantized_vector2(peer, VELOCITY_SCALE)
	snapshot.health = int(peer.get_u16())
	snapshot.hearts = int(peer.get_u8())
	var flags := int(peer.get_u8())
	snapshot.facing = -1 if (flags & 1) != 0 else 1
	snapshot.is_on_floor = (flags & 2) != 0
	snapshot.attacking = (flags & 4) != 0
	snapshot.ability_active = (flags & 8) != 0
	snapshot.current_weapon = int(peer.get_u8())
	snapshot.aim_direction = _read_quantized_unit_vector2(peer)
	snapshot.melee_id = _decode_id(int(peer.get_u8()), Data.MELEE_IDS)
	snapshot.melee_ammunition = int(peer.get_u16())
	snapshot.melee_recharge_time = peer.get_float()
	snapshot.ranged_id = _decode_id(int(peer.get_u8()), Data.RANGED_IDS)
	snapshot.ranged_ammunition = int(peer.get_u16())
	snapshot.ranged_recharge_time = peer.get_float()
	snapshot.armour_id = _decode_id(int(peer.get_u8()), Data.ARMOUR_IDS)
	snapshot.ability_id = _decode_id(int(peer.get_u8()), Data.ABILITY_IDS)
	snapshot.style_id = _decode_id(int(peer.get_u8()), Data.STYLE_IDS)
	snapshot.last_ability = int(peer.get_u32()) - 1
	snapshot.ability_charge = int(peer.get_u16())
	return snapshot


static func _write_bullet(peer: StreamPeerBuffer, snapshot: BulletSnapshot) -> void:
	peer.put_u32(maxi(int(snapshot.bullet_id), 0))
	_write_quantized_vector2(peer, snapshot.position, POSITION_SCALE)
	peer.put_u16(clampi(snapshot.speed, 0, 65535))
	_write_quantized_unit_vector2(peer, snapshot.direction)


static func _read_bullet(peer: StreamPeerBuffer) -> BulletSnapshot:
	var snapshot := BulletSnapshot.new()
	snapshot.bullet_id = str(peer.get_u32())
	snapshot.position = _read_quantized_vector2(peer, POSITION_SCALE)
	snapshot.speed = int(peer.get_u16())
	snapshot.direction = _read_quantized_unit_vector2(peer)
	return snapshot


static func _write_event(peer: StreamPeerBuffer, snapshot: EventSnapshot) -> void:
	if snapshot is HitEventSnapshot:
		peer.put_u8(EventSnapshot.TYPE_HIT)
		_write_hit_event(peer, snapshot as HitEventSnapshot)
		return
	push_error("Unsupported event snapshot type: %s" % snapshot.get_class())


static func _read_event(peer: StreamPeerBuffer) -> EventSnapshot:
	var event_type := int(peer.get_u8())
	match event_type:
		EventSnapshot.TYPE_HIT:
			return _read_hit_event(peer)
		_:
			push_error("Unsupported event snapshot type id: %s" % event_type)
			return EventSnapshot.new()


static func _write_hit_event(peer: StreamPeerBuffer, snapshot: HitEventSnapshot) -> void:
	_write_string(peer, snapshot.event_id)
	_write_string(peer, snapshot.victim_player_id)
	_write_string(peer, snapshot.attacker_player_id)
	_write_string(peer, snapshot.effect_id)
	_write_quantized_vector2(peer, snapshot.effect_position, POSITION_SCALE)


static func _read_hit_event(peer: StreamPeerBuffer) -> HitEventSnapshot:
	var snapshot := HitEventSnapshot.new()
	snapshot.event_id = _read_string(peer)
	snapshot.victim_player_id = _read_string(peer)
	snapshot.attacker_player_id = _read_string(peer)
	snapshot.effect_id = _read_string(peer)
	snapshot.effect_position = _read_quantized_vector2(peer, POSITION_SCALE)
	return snapshot


static func _write_string(peer: StreamPeerBuffer, value: String) -> void:
	var bytes := value.to_utf8_buffer()
	peer.put_u8(clampi(bytes.size(), 0, 255))
	peer.put_data(bytes.slice(0, 255))


static func _read_string(peer: StreamPeerBuffer) -> String:
	var length := int(peer.get_u8())
	var result := peer.get_data(length)
	if result[0] != OK:
		return ""
	return result[1].get_string_from_utf8()


static func _write_quantized_vector2(peer: StreamPeerBuffer, value: Vector2, scale: float) -> void:
	peer.put_u16(_encode_signed_16(value.x, scale))
	peer.put_u16(_encode_signed_16(value.y, scale))


static func _read_quantized_vector2(peer: StreamPeerBuffer, scale: float) -> Vector2:
	return Vector2(
		_decode_signed_16(int(peer.get_u16()), scale),
		_decode_signed_16(int(peer.get_u16()), scale)
	)


static func _write_quantized_unit_vector2(peer: StreamPeerBuffer, value: Vector2) -> void:
	peer.put_u8(_encode_signed_8(value.x, AIM_SCALE))
	peer.put_u8(_encode_signed_8(value.y, AIM_SCALE))


static func _read_quantized_unit_vector2(peer: StreamPeerBuffer) -> Vector2:
	return Vector2(
		_decode_signed_8(int(peer.get_u8()), AIM_SCALE),
		_decode_signed_8(int(peer.get_u8()), AIM_SCALE)
	)


static func _encode_signed_16(value: float, scale: float) -> int:
	return clampi(int(round(value * scale)) + SIGNED_16_BIAS, 0, 65535)


static func _decode_signed_16(value: int, scale: float) -> float:
	return float(value - SIGNED_16_BIAS) / scale


static func _encode_signed_8(value: float, scale: float) -> int:
	return clampi(int(round(value * scale)) + SIGNED_8_BIAS, 0, 255)


static func _decode_signed_8(value: int, scale: float) -> float:
	return float(value - SIGNED_8_BIAS) / scale


static func _encode_id(id: String, ids: Array[String]) -> int:
	var index := ids.find(id)
	if index < 0:
		return 0
	return clampi(index, 0, 255)


static func _decode_id(index: int, ids: Array[String]) -> String:
	if index < 0 or index >= ids.size():
		return ids[0]
	return ids[index]
