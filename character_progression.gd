## character_progression.gd - Character Progression & Artifact System (Godot 4.3+)
class_name CharacterProgression
extends Node

signal level_up(new_level: int, stats: Dictionary)
signal artifact_equipped(slot: int, artifact: ArtifactResource)
signal artifact_unequipped(slot: int)
signal skin_changed(skin_name: String)
signal aura_changed(aura_name: String)

# --- Progression State ---
@export_range(1, 90) var level: int = 20
@export var current_exp: int = 3400
@export var max_exp: int = 5000

# --- Wardrobe & Visual Customization ---
@export_enum("default", "shrine_maiden", "divine_sovereign", "thunder_empress") var skin_style: String = "default":
	set(val):
		skin_style = val
		skin_changed.emit(val)

@export_enum("electro_violet", "thunder_cyan", "celestial_gold") var aura_color: String = "electro_violet":
	set(val):
		aura_color = val
		aura_changed.emit(val)

# --- 5 Equipped Artifact Slots ---
# Keyed by ArtifactResource.Slot enum (0: Flower, 1: Plume, 2: Sands, 3: Goblet, 4: Circlet)
var equipped_artifacts: Dictionary = {}

# Inventory of unequipped relics
var inventory: Array[ArtifactResource] = []


func _ready() -> void:
	recalculate_total_stats()


## Levels up the character (caps at Lv. 90)
func perform_level_up() -> void:
	if level >= 90:
		return
	level = mini(90, level + 5)
	current_exp = 0
	max_exp = 1000 + (level * 250)
	
	var updated_stats: Dictionary = recalculate_total_stats()
	level_up.emit(level, updated_stats)


## Equips an artifact into its designated slot
func equip_artifact(artifact: ArtifactResource) -> void:
	if not artifact:
		return
	equipped_artifacts[artifact.slot] = artifact
	if artifact in inventory:
		inventory.erase(artifact)
		
	artifact_equipped.emit(artifact.slot, artifact)
	recalculate_total_stats()


## Unequips an artifact from a slot back to inventory
func unequip_artifact(slot: int) -> void:
	if equipped_artifacts.has(slot):
		var removed: ArtifactResource = equipped_artifacts[slot]
		equipped_artifacts.erase(slot)
		inventory.append(removed)
		artifact_unequipped.emit(slot)
		recalculate_total_stats()


## Computes combined Base + Artifact + Set Bonus stats
func recalculate_total_stats() -> Dictionary:
	# 1. Base Level Scaling Formulas (Lv. 1-90)
	var level_factor: float = 1.0 + (float(level - 1) * 0.038)
	var base_hp: float = 80.0 * level_factor
	var base_atk: float = 18.0 * level_factor
	var energy_recharge: float = 130.0 # Raiden Shogun innate ascension stat
	var crit_rate: float = 35.0
	var electro_dmg: float = 15.0
	
	# 2. Add Main Stats from 5 Equipped Artifacts
	var bonus_flat_atk: float = 0.0
	var bonus_pct_atk: float = 0.0
	var bonus_flat_hp: float = 0.0
	
	for slot_idx in equipped_artifacts.keys():
		var art: ArtifactResource = equipped_artifacts[slot_idx]
		if not art:
			continue
			
		match art.main_stat_type:
			ArtifactResource.StatType.ATK:
				if art.is_percentage:
					bonus_pct_atk += art.main_stat_value
				else:
					bonus_flat_atk += art.main_stat_value
			ArtifactResource.StatType.HP:
				bonus_flat_hp += art.main_stat_value
			ArtifactResource.StatType.ER:
				energy_recharge += art.main_stat_value
			ArtifactResource.StatType.ELECTRO_DMG:
				electro_dmg += art.main_stat_value
			ArtifactResource.StatType.CRIT_RATE:
				crit_rate += art.main_stat_value
				
	# 3. Detect Set Piece Bonuses (2pc and 4pc)
	var set_counts: Dictionary = {}
	for art in equipped_artifacts.values():
		if art:
			set_counts[art.set_name] = set_counts.get(art.set_name, 0) + 1
			
	for set_title in set_counts.keys():
		var count: int = set_counts[set_title]
		if set_title == "Emblem of Severed Fate" and count >= 2:
			energy_recharge += 20.0 # 2pc: ER +20%
		elif set_title == "Thundering Fury" and count >= 2:
			electro_dmg += 15.0 # 2pc: Electro DMG +15%
		elif set_title == "Shimenawa's Reminiscence" and count >= 2:
			bonus_pct_atk += 18.0 # 2pc: ATK +18%
			
	var total_hp: float = base_hp + bonus_flat_hp
	var total_atk: float = (base_atk * (1.0 + (bonus_pct_atk / 100.0))) + bonus_flat_atk
	
	return {
		"level": level,
		"max_hp": total_hp,
		"total_atk": total_atk,
		"base_atk": base_atk,
		"energy_recharge": energy_recharge,
		"crit_rate": crit_rate,
		"electro_dmg": electro_dmg
	}
