class_name ParticipantSnapshot
extends RefCounted

var participant_id: String
var team_id: int

var position: Vector2
var velocity: Vector2
var is_on_floor: bool

var health: int
var hearts: int
var facing: int

var current_weapon: int
var attacking: bool
var aim_direction: Vector2

var melee_id: String
var melee_ammunition: int
var melee_recharge_time: float

var ranged_id: String
var ranged_ammunition: int
var ranged_recharge_time: float

var ability_id: String
var ability_active: bool
var last_ability: int
var ability_charge: int

var armour_id: String

var style_id: String
