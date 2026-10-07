extends Node

const PIXELS_PER_ZONE_UNIT := 16.0

var server_address := ""
var character_name := ""
var character_id := ""
var character_state: Dictionary = {}
var experience := 0.0
var attributes := {
	"power": 0,
	"agility": 0,
	"endurance": 0,
	"insight": 0,
}
