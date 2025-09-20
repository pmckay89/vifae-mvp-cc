extends Label

var descriptions = {
    "attack": "Basic strike dealing 10-15 damage. Timing QTE.",

    # Player1 (Sword Spirit) abilities
    "2x_cut": "Double slash dealing medium damage. Confirm Attack QTE.",
    "moonfall_slash": "Powerful overhead strike. Confirm Attack QTE.",
    "spirit_wave": "Ranged spiritual attack. Confirm Attack QTE.",
    "uppercut": "Rising sword attack. Confirm Attack QTE.",
    "whirlwind": "Spinning attack hitting all enemies. Confirm Attack QTE.",
    "poison": "Toxic blade that inflicts poison damage over time. Confirm Attack QTE.",
    "burn_strike": "Fiery slash that burns the target. Confirm Attack QTE.",
    "shield_boost": "Increases defense temporarily. No QTE.",
    "mark_target": "Marks enemy for increased damage. No QTE.",

    # Player2 (Gun Girl) abilities
    "big_shot": "Powerful shot dealing 50-70 damage. Confirm Attack QTE.",
    "scatter_shot": "Spread shot hitting multiple areas. Confirm Attack QTE.",
    "grenade": "Explosive area damage. Confirm Attack QTE.",
    "bullet_rain": "Fires multiple shots for 7-10 damage each. Confirm Attack QTE.",
    "freezing_shot": "Ice bullet that slows the enemy. Confirm Attack QTE.",
    "armor_piercing": "Shot that ignores enemy defense. Confirm Attack QTE.",
    "bleeding_shot": "Bullet that causes bleeding damage over time. Confirm Attack QTE.",

    # Shared abilities
    "berserker_rage": "Increases attack power but reduces defense. No QTE.",
    "healing_touch": "Restores HP to self or ally. No QTE.",
    "curse_strike": "Dark attack that weakens the enemy. Confirm Attack QTE.",
    "time_shift": "Slows down time for tactical advantage. No QTE.",
    "energy_barrier": "Creates protective barrier absorbing damage. No QTE.",
    "spirit_slash": "Spiritual sword attack. Confirm Attack QTE.",

    # Legacy abilities (may be unused)
    "jump_shot": "Aerial shot dealing 15-25 damage. Confirm Attack QTE.",
    "precision_strike": "Focused shot dealing 20-30 damage. Confirm Attack QTE.",

    # Items
    "hp_potion": "Restores 50 HP. Uses drink animation. One per turn.",
    "resolve_potion": "Restores 3 Resolve. Uses drink animation. One per turn.",
    "bandages": "Heal 15 HP per turn for 3 turns. Regeneration effect.",
    "phoenix_feather": "Revive with 50% HP if you die this battle. One-time use.",
    "rage_potion": "Gain rage status: +100% damage, +25% incoming damage for 3 turns.",
    "speed_boost": "Gain haste status: act twice per turn for 2 turns.",
    "pain_killer": "Immune to next damage taken. One-time protection."
}

func show_description(key: String):
    text = descriptions.get(key, "")
    visible = true

    # Essential fix: Ensure parent container is visible
    if get_parent():
        get_parent().visible = true

    # Show the background panel
    var bg_panel = get_node("../../DescriptionBackground")
    if bg_panel:
        bg_panel.visible = true

    # Dynamically position both elements below the PlayerUIContainer
    # Use call_deferred to ensure UI layout is updated first
    call_deferred("_position_below_player_ui")

    # Set proper styling - white text with outline for visibility
    add_theme_color_override("font_color", Color.WHITE)
    add_theme_color_override("font_outline_color", Color.BLACK)
    add_theme_constant_override("outline_size", 2)

func _position_below_player_ui():
    # Find the PlayersVBox to get the actual content height
    var players_vbox = get_node_or_null("/root/BattleScene/UILayer/PlayerUIContainer/PlayersVBox")
    var player_ui_container = get_node_or_null("/root/BattleScene/UILayer/PlayerUIContainer")

    if not players_vbox or not player_ui_container:
        print("⚠️ Could not find PlayerUIContainer or PlayersVBox for description positioning")
        return

    # Get the actual bottom of the content, accounting for dynamic upgrade rows
    var container_top = player_ui_container.position.y
    var container_padding = 10  # Approximate padding inside PanelContainer
    var content_height = _calculate_vbox_content_height(players_vbox)
    var actual_bottom = container_top + container_padding + content_height
    var new_y = actual_bottom + 15  # 15px margin below actual content

    # Update this label's position
    position.y = new_y

    # Update background panel position
    var bg_panel = get_node("../../DescriptionBackground")
    if bg_panel:
        bg_panel.position.y = new_y
        print("🎯 [Description] Positioned description at Y: ", new_y, " (content height: ", content_height, ")")

func _calculate_vbox_content_height(vbox: VBoxContainer) -> float:
    var total_height = 0.0
    var separation = vbox.get_theme_constant("separation", "VBoxContainer")

    # Add up heights of all visible children
    var visible_children = 0
    for child in vbox.get_children():
        if child.visible:
            total_height += child.size.y
            visible_children += 1

    # Add separations between children
    if visible_children > 1:
        total_height += separation * (visible_children - 1)

    return total_height

func hide_description():
    visible = false

    # Hide the background panel too
    var bg_panel = get_node("../../DescriptionBackground")
    if bg_panel:
        bg_panel.visible = false
