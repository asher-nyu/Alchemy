# New Enemies Implementation Guide

## Overview
Two new enemies have been added to the game:
1. **Ghost Enemy** - Drops MINT (brews Jump Potions)
2. **Wizard Enemy** - Drops PEPPER (brews Hulk Potions)

## Files Created

### Core Enemy Files
- `ghost_enemy.gd` - Ghost enemy script
- `ghost_enemy.tscn` - Ghost enemy scene
- `wizard_enemy.gd` - Wizard enemy script
- `wizard_enemy.tscn` - Wizard enemy scene

### Pickup Visual Files
- `mint_pickup.gd` - Mint pickup animation script
- `mint_pickup.tscn` - Mint pickup scene
- `pepper_pickup.gd` - Pepper pickup animation script
- `pepper_pickup.tscn` - Pepper pickup scene

### Updated System Files
- `Inventory.gd` - Added mint/pepper tracking and jump/hulk potions
- `token.gd` - Added pepper token texture support
- `match3.gd` - Updated enum to include PEPPER
- `match_detector.gd` - Updated enum to include PEPPER
- `grid_refiller.gd` - Updated enum to include PEPPER

## Enemy Statistics Comparison

| Enemy    | Health | Speed | Damage | Cooldown | Range | Patrol Distance | Drop      |
|----------|--------|-------|--------|----------|-------|-----------------|-----------|
| Skeleton | 50     | 50    | 10     | 1.5s     | 200   | 400             | Garlic    |
| Ghost    | 40     | 70    | 8      | 1.8s     | 250   | 500             | Mint      |
| Wizard   | 80     | 40    | 15     | 2.0s     | 300   | 300             | Pepper    |

## Enemy Behaviors

### Ghost Enemy
- **Movement**: Floats with sine wave vertical motion
- **Behavior**: Fast and agile, wide patrol range
- **Attack**: Drifts slowly toward player during attack
- **Visual**: Uses `sprGhost3.png` asset
- **Drop**: Mint (unlocks mint tokens for match-3)
- **Theme**: Light, floaty, mint is "thin/floating"

### Wizard Enemy
- **Movement**: Slow ground-based patrol
- **Behavior**: Tanky with high health, stops to cast spells
- **Attack**: Long-range magic attacks (300 units)
- **Visual**: Uses `sprWizard.png` asset (7-frame animation)
- **Drop**: Pepper (unlocks pepper tokens for match-3)
- **Theme**: Powerful, spicy damage dealer

## Inventory System Additions

### New Variables
```gdscript
var mint_count: int = 0
var pepper_count: int = 0
var jump_potions: int = 0    # From mint matches
var hulk_potions: int = 0    # From pepper matches
```

### New Functions
```gdscript
Inventory.add_mint(1)        # Called when ghost dies
Inventory.add_pepper(1)      # Called when wizard dies
Inventory.add_jump_potions(1)
Inventory.add_hulk_potions(1)
Inventory.use_jump_potion()
Inventory.use_hulk_potion()
```

### New Signals
```gdscript
signal mint_changed(new_count: int)
signal pepper_changed(new_count: int)
signal jump_potions_changed(new_count: int)
signal hulk_potions_changed(new_count: int)
```

## How to Use in Your Levels

### Adding Enemies to a Level
Open your level scene (e.g., `level_1.tscn`, `level_2.tscn`) and:

1. **Add Ghost Enemy**:
   - Instance `ghost_enemy.tscn`
   - Position where desired
   - Scale appropriately (suggest `scale = Vector2(4, 4)` or `Vector2(6, 6)`)

2. **Add Wizard Enemy**:
   - Instance `wizard_enemy.tscn`
   - Position where desired
   - Scale appropriately (suggest `scale = Vector2(6, 6)`)

### Example Placement
```gdscript
# In level scene
[node name="ghost_enemy" parent="." instance=ExtResource("ghost_enemy")]
position = Vector2(2000, 2000)
scale = Vector2(5, 5)

[node name="wizard_enemy" parent="." instance=ExtResource("wizard_enemy")]
position = Vector2(4000, 2000)
scale = Vector2(6, 6)
```

## Match-3 Integration

### Token Types (Updated Enum)
```gdscript
enum TokenType {
    ROCK = -1,
    GINGER = 0,
    GARLIC = 1,
    MINT = 2,
    PEPPER = 3  # NEW!
}
```

### Match-3 Behavior
When you kill enemies and collect their drops:
- **Garlic** → Unlocks garlic tokens → Match 3 garlic = Health Potion
- **Mint** → Unlocks mint tokens → Match 3 mint = Jump Potion
- **Pepper** → Unlocks pepper tokens → Match 3 pepper = Hulk Potion

### Adding Match Detection for New Potions
You'll need to update `match3.gd` to detect mint and pepper matches similar to garlic:

```gdscript
# In process_all_matches() function, add:
var mint_matches = match_detector.check_for_mint_matches(matches, grid, GRID_WIDTH, GRID_HEIGHT)
if mint_matches > 0:
    Inventory.add_jump_potions(mint_matches)

var pepper_matches = match_detector.check_for_pepper_matches(matches, grid, GRID_WIDTH, GRID_HEIGHT)
if pepper_matches > 0:
    Inventory.add_hulk_potions(pepper_matches)
```

## TODO: Additional Implementation Needed

### 1. Add Match Detection Functions
In `match_detector.gd`, add:
```gdscript
func check_for_mint_matches(matches: Array, grid: Array, width: int, height: int) -> int:
    # Copy the logic from check_for_garlic_matches but check for MINT

func check_for_pepper_matches(matches: Array, grid: Array, width: int, height: int) -> int:
    # Copy the logic from check_for_garlic_matches but check for PEPPER
```

### 2. Update Player Script
Add potion usage keybindings to `player.gd`:
```gdscript
# Jump Potion - Press J
if Input.is_action_just_pressed("use_jump_potion") and can_use_potion:
    if Inventory.use_jump_potion():
        # Apply super jump boost
        velocity.y = JUMP_VELOCITY * 2.0
        can_use_potion = false
        await get_tree().create_timer(POTION_COOLDOWN).timeout
        can_use_potion = true

# Hulk Potion - Press H
if Input.is_action_just_pressed("use_hulk_potion") and can_use_potion:
    if Inventory.use_hulk_potion():
        # Apply damage boost (temporary)
        attack_damage *= 2
        await get_tree().create_timer(5.0).timeout  # 5 second boost
        attack_damage /= 2
```

### 3. Add Input Actions
In Project Settings → Input Map, add:
- `use_jump_potion` (key: J)
- `use_hulk_potion` (key: H)

### 4. ~~Find Wizard Sprite~~ ✅ DONE
The wizard now uses `sprWizard.png` with 7-frame animation!

### 5. Update UI
Update `InventoryUI.gd` to display:
- Mint count
- Pepper count
- Jump potion count
- Hulk potion count

## Testing

### Test Ghost Enemy
1. Open a level scene
2. Add ghost enemy instance
3. Run game and kill ghost
4. Verify mint pickup animates to corner
5. Go to match-3 scene
6. Verify mint tokens appear in grid

### Test Wizard Enemy
1. Add wizard enemy to level
2. Test combat (should be tanky, hard to kill)
3. Verify pepper pickup animation
4. Check match-3 for pepper tokens

## Visual Polish Suggestions

### Ghost
- Add transparency/fade effects
- Add particle effects for ethereal look
- Consider adding glow shader

### Wizard
- Replace skeleton sprite with proper wizard sprite
- Add spell casting particle effects
- Add magic projectile visuals

## Balancing Notes

Feel free to adjust these constants in the enemy scripts:

- **Health**: `max_health` variable
- **Speed**: `PATROL_SPEED` constant
- **Damage**: `attack_damage` variable
- **Range**: `ATTACK_RANGE` constant
- **Cooldown**: `attack_cooldown` variable

Example:
```gdscript
# To make wizard easier
var max_health = 60  # Instead of 80
var attack_damage = 12  # Instead of 15
```

---

## Summary

You now have:
✅ Ghost enemy (mint dropper)
✅ Wizard enemy (pepper dropper)
✅ Mint pickup visuals
✅ Pepper pickup visuals
✅ Updated token system for PEPPER
✅ Inventory system for mint/pepper/jump/hulk potions

**Next steps:**
1. Add mint/pepper match detection to match3.gd
2. Add potion usage keybindings to player.gd
3. Update UI to show new resources
4. Find proper wizard sprite
5. Test and balance!

