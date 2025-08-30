extends Label

var descriptions = {
    "attack": "Basic strike dealing 10-15 damage. Timing QTE.",
    # Player1 (Sword Spirit) abilities
    "2x_cut": "Double slash dealing medium damage. Confirm Attack QTE.",
    "moonfall_slash": "Powerful overhead strike. Confirm Attack QTE.",
    "spirit_wave": "Ranged spiritual attack. Confirm Attack QTE.",
    "uppercut": "Rising sword attack. Confirm Attack QTE.",
    # Player2 (Gun Girl) abilities
    "big_shot": "Powerful shot dealing 50-70 damage. Confirm Attack QTE.",
    "scatter_shot": "Spread shot hitting multiple areas. Confirm Attack QTE.",
    "focus": "Doubles damage of next attack. No QTE.",
    "grenade": "Explosive area damage. Confirm Attack QTE.",
    "bullet_rain": "Fires multiple shots for 7-10 damage each. Confirm Attack QTE.",
    # Legacy abilities (may be unused)
    "jump_shot": "Aerial shot dealing 15-25 damage. Confirm Attack QTE.",
    "precision_strike": "Focused shot dealing 20-30 damage. Confirm Attack QTE.",
    # Items
    "hp_potion": "Restores 30 HP to selected player. No QTE."
}

func show_description(key: String):
    text = descriptions.get(key, "")
    visible = true
    
    # Essential fix: Ensure parent container is visible
    if get_parent():
        get_parent().visible = true
    
    # Set proper styling - red text with outline for visibility
    add_theme_color_override("font_color", Color.RED)
    add_theme_color_override("font_outline_color", Color.BLACK) 
    add_theme_constant_override("outline_size", 2)

func hide_description():
    visible = false
