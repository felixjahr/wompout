class_name ParticipantInputBatch
extends RefCounted

const AIM_SCALE := 127.0
const SIGNED_8_BIAS := 128
const JUMPING_FLAG := 1
const ATTACKING_FLAG := 2
const ABILITY_FLAG := 4
const DIRECTION_FLAGS_SHIFT := 3
const DIRECTION_FLAGS_MASK := 3
const MAX_INPUTS_PER_BATCH := 3
const INPUT_BYTE_SIZE := 8

var inputs: Array[ParticipantInput] = []


func to_packet() -> PackedByteArray:
	var peer := StreamPeerBuffer.new()
	peer.big_endian = false
	var input_count := mini(inputs.size(), 255)
	peer.put_u8(input_count)
	for i in input_count:
		_write_input(peer, inputs[i])
	return peer.data_array


static func from_packet(packet: PackedByteArray) -> ParticipantInputBatch:
	if packet.is_empty():
		return null
	var input_count := int(packet[0])
	if input_count < 1 or input_count > MAX_INPUTS_PER_BATCH:
		return null
	if packet.size() != 1 + input_count * INPUT_BYTE_SIZE:
		return null
	var peer := StreamPeerBuffer.new()
	peer.big_endian = false
	peer.data_array = packet
	peer.seek(1)
	var batch := ParticipantInputBatch.new()
	for i in input_count:
		var input := _read_input(peer)
		if input.current_weapon not in [0, 1]:
			return null
		batch.inputs.append(input)
	return batch


static func _write_input(peer: StreamPeerBuffer, input: ParticipantInput) -> void:
	peer.put_u32(input.tick)
	var flags := 0
	if input.jumping:
		flags |= JUMPING_FLAG
	if input.attacking:
		flags |= ATTACKING_FLAG
	if input.ability:
		flags |= ABILITY_FLAG
	flags |= _encode_direction_flags(input.direction) << DIRECTION_FLAGS_SHIFT
	peer.put_u8(flags)
	peer.put_u8(clampi(input.current_weapon, 0, 255))
	_write_quantized_unit_vector2(peer, input.aim_direction)


static func _read_input(peer: StreamPeerBuffer) -> ParticipantInput:
	var input := ParticipantInput.new()
	input.tick = int(peer.get_u32())
	var flags := int(peer.get_u8())
	input.jumping = (flags & JUMPING_FLAG) != 0
	input.attacking = (flags & ATTACKING_FLAG) != 0
	input.ability = (flags & ABILITY_FLAG) != 0
	input.direction = _decode_direction_flags((flags >> DIRECTION_FLAGS_SHIFT) & DIRECTION_FLAGS_MASK)
	input.current_weapon = int(peer.get_u8())
	input.aim_direction = _read_quantized_unit_vector2(peer)
	return input


static func _encode_direction_flags(value: int) -> int:
	match clampi(value, -1, 1):
		-1:
			return 1
		1:
			return 2
		_:
			return 0


static func _decode_direction_flags(value: int) -> int:
	match value:
		1:
			return -1
		2:
			return 1
		_:
			return 0


static func _write_quantized_unit_vector2(peer: StreamPeerBuffer, value: Vector2) -> void:
	peer.put_u8(_encode_signed_8(value.x, AIM_SCALE))
	peer.put_u8(_encode_signed_8(value.y, AIM_SCALE))


static func _read_quantized_unit_vector2(peer: StreamPeerBuffer) -> Vector2:
	return Vector2(
		_decode_signed_8(int(peer.get_u8()), AIM_SCALE),
		_decode_signed_8(int(peer.get_u8()), AIM_SCALE)
	)


static func _encode_signed_8(value: float, scale: float) -> int:
	return clampi(int(round(value * scale)) + SIGNED_8_BIAS, 0, 255)


static func _decode_signed_8(value: int, scale: float) -> float:
	return float(value - SIGNED_8_BIAS) / scale
