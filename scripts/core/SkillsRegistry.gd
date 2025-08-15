extends Node

# Centralized skills data registry
# Note: This is a data-only registry - no behavioral changes yet

func get_skills() -> Dictionary:
	return {
		"Basic Attack": {
			"qte": "tap",
			"window_ms": 600,
			"damage": 10,
			"crit_mult": 1.5,
			"sfx": "hit",
			"vfx": null
		},
		"Big Shot": {
			"qte": "sniper_box",
			"window_ms": 650,
			"damage": 20,
			"crit_mult": 2.0,
			"sfx": "hit_crit",
			"vfx": "muzzle_flash"
		},
		"Scatter Shot": {
			"qte": "sniper_box",
			"window_ms": 700,
			"damage": 35,
			"crit_mult": 1.0,
			"sfx": "hit_crit",
			"vfx": "muzzle_flash"
		},
		"2x Cut": {
			"qte": "tap",
			"window_ms": 500,
			"damage": 14,
			"crit_mult": 2.1,
			"sfx": "blade_hit",
			"vfx": "slash_effect"
		},
		"Moonfall Slash": {
			"qte": "tap",
			"window_ms": 400,
			"damage": 15,
			"crit_mult": 1.7,
			"sfx": "blade_crit",
			"vfx": "moon_slash"
		},
		"Spirit Wave": {
			"qte": "tap",
			"window_ms": 450,
			"damage": 20,
			"crit_mult": 1.5,
			"sfx": "spirit_hit",
			"vfx": "spirit_wave"
		}
	}