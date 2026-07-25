extends Control
## UI placeholder del combate: escucha las señales de CombatManager y renderiza.
## La lógica vive en CombatManager; aquí solo hay presentación e input.

signal finished(victory: bool)

const SPRITE_DIR := "res://assets/sombras"
const VIAJERO_SPRITE := "res://assets/viajero/viajero.png"
const PERSONAJES_DIR := "res://assets/personajes"
const BACKGROUND_PATH := "res://assets/backgrounds/combate_santuario.png"

var manager: CombatManager

var _enemy_label: Label
var _enemy_slot: Control
var _enemy_holder: Control
var _viajero_slot: Control
var _viajero_holder: Control
var _intent_label: Label
var _claridad_bar: ProgressBar
var _claridad_label: Label
var _shield_label: Label
var _energy_label: Label
var _hand_box: HBoxContainer
var _node: MapNode
var _sprite_key := "sombra_menor"
var _last_enemy_claridad := 0


func _ready() -> void:
	# Solo construye la UI: main.gd llama a setup() DESPUÉS de add_child,
	# así que el arranque del combate no puede vivir aquí (_node sería null).
	set_anchors_preset(Control.PRESET_FULL_RECT)
	SceneBackground.add_to(self, BACKGROUND_PATH)
	manager = CombatManager.new()
	add_child(manager)
	_build_ui()


func setup(node: MapNode) -> void:
	_node = node
	manager.hand_changed.connect(_on_hand_changed)
	manager.energy_changed.connect(_on_energy_changed)
	manager.enemy_intent_changed.connect(func(intent): _intent_label.text = intent)
	manager.combat_ended.connect(_on_combat_ended)
	manager.card_played.connect(func(_card): SpriteStrip.play_once(
		_viajero_holder, PERSONAJES_DIR.path_join("viajero/attack_south"), 10.0))
	manager.state_changed.connect(func(state):
		if state == CombatManager.State.TURNO_ENEMIGO:
			SpriteStrip.play_once(_enemy_holder,
				PERSONAJES_DIR.path_join(_sprite_key + "/attack_south"), 10.0))

	var enemy_name := "Sombra Menor"
	var enemy_claridad := 18 + _node.floor_index * 2
	var enemy_attack := 5
	_sprite_key = "sombra_menor"
	match _node.node_type:
		MapNode.NodeType.ELITE:
			enemy_name = "Sombra Élite"
			enemy_claridad = 30 + _node.floor_index * 2
			enemy_attack = 8
			_sprite_key = "sombra_elite"
		MapNode.NodeType.JEFE_SOMBRA:
			enemy_name = "Jefe de la Sombra"
			enemy_claridad = 50 + _node.floor_index * 3
			enemy_attack = 10
			_sprite_key = "jefe_sombra"
	_fill_slot_enemy()
	_fill_slot_viajero()

	manager.start_combat(GameState.mazo_permanente, enemy_name, enemy_claridad, enemy_attack, _sprite_key)
	manager.enemy.claridad_changed.connect(_on_enemy_claridad_changed)
	manager.enemy.disonancia_changed.connect(func(_v): _refresh_enemy())
	manager.player.claridad_changed.connect(_on_player_claridad_changed)
	manager.player.shield_changed.connect(func(v): _shield_label.text = "Escudo: %d" % v)
	_last_enemy_claridad = manager.enemy.claridad
	_claridad_bar.max_value = manager.player.max_claridad
	_claridad_bar.value = manager.player.claridad
	_refresh_enemy()
	_on_player_claridad_changed(manager.player.claridad, manager.player.max_claridad)


func _build_ui() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 16
	layout.offset_right = -16
	layout.offset_top = 24
	layout.offset_bottom = -24
	add_child(layout)

	_enemy_label = Label.new()
	_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_enemy_label)

	_intent_label = Label.new()
	_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent_label.modulate = Color(1, 0.7, 0.7)
	layout.add_child(_intent_label)

	# Hueco para la Sombra: animación de personaje o imagen estática (setup()).
	# Expande para ocupar el espacio libre entre la cabecera y la zona del
	# jugador, en vez de dejar un vacío muerto en el centro de la pantalla.
	_enemy_slot = CenterContainer.new()
	_enemy_slot.custom_minimum_size = Vector2(256, 256)
	_enemy_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_enemy_slot)

	layout.add_child(HSeparator.new())

	# Zona del jugador: sprite del Viajero a la izquierda, stats a la derecha.
	var player_row := HBoxContainer.new()
	player_row.add_theme_constant_override("separation", 12)
	layout.add_child(player_row)

	_viajero_slot = CenterContainer.new()
	_viajero_slot.custom_minimum_size = Vector2(128, 128)
	player_row.add_child(_viajero_slot)

	var stats := VBoxContainer.new()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	player_row.add_child(stats)

	_claridad_label = Label.new()
	stats.add_child(_claridad_label)

	_claridad_bar = ProgressBar.new()
	_claridad_bar.custom_minimum_size.y = 24
	_claridad_bar.show_percentage = false
	stats.add_child(_claridad_bar)

	_shield_label = Label.new()
	_shield_label.text = "Escudo: 0"
	stats.add_child(_shield_label)

	_energy_label = Label.new()
	stats.add_child(_energy_label)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size.y = 250
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(hand_scroll)

	_hand_box = HBoxContainer.new()
	_hand_box.add_theme_constant_override("separation", 12)
	hand_scroll.add_child(_hand_box)

	var end_turn := Button.new()
	end_turn.text = "Terminar turno"
	end_turn.custom_minimum_size.y = 56
	end_turn.pressed.connect(func(): manager.end_turn())
	layout.add_child(end_turn)


func _fill_slot_enemy() -> void:
	_enemy_holder = SpriteStrip.make_animated_control(
		PERSONAJES_DIR.path_join(_sprite_key + "/idle_south"), 256.0)
	if _enemy_holder:
		_enemy_slot.add_child(_enemy_holder)
		return
	_add_static_fallback(_enemy_slot, SPRITE_DIR.path_join(_sprite_key + ".png"), 256.0)


func _fill_slot_viajero() -> void:
	_viajero_holder = SpriteStrip.make_animated_control(
		PERSONAJES_DIR.path_join("viajero/idle_south"), 128.0)
	if _viajero_holder:
		_viajero_slot.add_child(_viajero_holder)
		return
	_add_static_fallback(_viajero_slot, VIAJERO_SPRITE, 128.0)


func _add_static_fallback(slot: Control, texture_path: String, size_px: float) -> void:
	if not ResourceLoader.exists(texture_path):
		return
	var rect := TextureRect.new()
	rect.texture = load(texture_path)
	rect.custom_minimum_size = Vector2(size_px, size_px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slot.add_child(rect)


func _refresh_enemy() -> void:
	_enemy_label.text = "%s — Claridad %d/%d — Disonancia %d" % [
		manager.enemy.display_name, manager.enemy.claridad,
		manager.enemy.max_claridad, manager.enemy.disonancia]


func _on_enemy_claridad_changed(value: int, _max_value: int) -> void:
	if value < _last_enemy_claridad:
		_shake(_enemy_slot)
	_last_enemy_claridad = value
	_refresh_enemy()


func _on_player_claridad_changed(value: int, max_value: int) -> void:
	if value < _claridad_bar.value:
		_shake(_viajero_slot)
		_flash(_claridad_bar, Color(1.0, 0.4, 0.4))
	elif value > _claridad_bar.value:
		_flash(_claridad_bar, Color(0.6, 1.0, 0.6))
	_claridad_bar.max_value = max_value
	var tween := create_tween()
	tween.tween_property(_claridad_bar, "value", float(value), 0.25) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_claridad_label.text = "Claridad del Viajero: %d/%d" % [value, max_value]


## Juice: sacudida corta al recibir daño y flash de color en la barra.
func _shake(target: Control) -> void:
	if target == null:
		return
	var origin := target.position
	var tween := create_tween()
	for offset in [6.0, -5.0, 3.0, -2.0, 0.0]:
		tween.tween_property(target, "position:x", origin.x + offset, 0.04)


func _flash(target: CanvasItem, color: Color) -> void:
	if target == null:
		return
	target.modulate = color
	var tween := create_tween()
	tween.tween_property(target, "modulate", Color.WHITE, 0.35)


func _on_energy_changed(current: int, max_energy: int) -> void:
	_energy_label.text = "Energía: %d/%d" % [current, max_energy]


func _on_hand_changed(hand: Array[CardData]) -> void:
	for child in _hand_box.get_children():
		child.queue_free()
	for card in hand:
		var card_ui := CardUI.new(card)
		card_ui.pressed.connect(func(): manager.play_card(card))
		_hand_box.add_child(card_ui)


func _on_combat_ended(victory: bool) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Integración" if victory else "Disolución"
	dialog.dialog_text = ("La Sombra se integra. Continúas el viaje."
			if victory else "La claridad se agotó. El run vuelve a empezar.")
	add_child(dialog)
	dialog.confirmed.connect(func(): finished.emit(victory))
	dialog.canceled.connect(func(): finished.emit(victory))
	dialog.popup_centered()
