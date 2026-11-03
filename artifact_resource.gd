## artifact_resource.gd - Custom Resource for Equipable Inazuma Relics (Godot 4.3+)
class_name ArtifactResource
extends Resource

enum Slot { FLOWER, PLUME, SANDS, GOBLET, CIRCLET }
enum StatType { ATK, HP, ER, ELECTRO_DMG, CRIT_RATE, CRIT_DMG }

@export var artifact_id: String = ""
@export var artifact_name: String = "Magnificent Tsuba"
@export var slot: Slot = Slot.PLUME
@export_range(4, 5) var rarity: int = 5
@export_enum("Emblem of Severed Fate", "Thundering Fury", "Shimenawa's Reminiscence") var set_name: String = "Emblem of Severed Fate"

@export_group("Main Stat")
@export var main_stat_type: StatType = StatType.ATK
@export var main_stat_value: float = 47.0 # Flat or percentage depending on type
@export var is_percentage: bool = false

@export_group("Substats")
@export var substats: Array[Dictionary] = [
	{"name": "CRIT Rate", "value": 3.9, "is_percent": true},
	{"name": "Energy Recharge", "value": 6.5, "is_percent": true},
	{"name": "ATK%", "value": 5.8, "is_percent": true}
]

@export_group("Set Piece Ability")
@export_multiline var ability_description: String = "Increases Elemental Burst DMG by 25% of Energy Recharge. Maximum bonus of 75% DMG can be obtained."
@export var two_piece_bonus_text: String = "Energy Recharge +20%"
@export var four_piece_bonus_text: String = "Burst DMG scaling via ER"

## Evaluates deferred combat passive based on player state and set
func evaluate_deferred_ability(player_stats: Dictionary) -> Dictionary:
	var bonus_mods: Dictionary = {"burst_dmg_mult": 1.0, "electro_dmg_add": 0.0, "skill_cd_reduction": 0.0}
	
	match set_name:
		"Emblem of Severed Fate":
			# Deferred ability: Scales Burst DMG proportional to Energy Recharge
			var er: float = player_stats.get("energy_recharge", 100.0)
			var burst_bonus: float = minf(0.75, (er * 0.25) / 100.0)
			bonus_mods["burst_dmg_mult"] = 1.0 + burst_bonus
			
		"Thundering Fury":
			# Deferred ability: 15% Electro DMG + cooldown refund on Electro hits
			bonus_mods["electro_dmg_add"] = 15.0
			bonus_mods["skill_cd_reduction"] = 1.0
			
		"Shimenawa's Reminiscence":
			# Deferred ability: 18% ATK and normal attack bonus
			bonus_mods["normal_atk_mult"] = 1.5
			
	return bonus_mods
