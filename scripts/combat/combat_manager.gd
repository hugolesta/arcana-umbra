class_name CombatManager
extends Node
## Máquina de estados del combate. Desacoplada de la UI mediante señales:
## CombatScene escucha y renderiza; este nodo solo resuelve lógica.

signal state_changed(new_state: State)
signal card_played(card: CardData)
signal hand_changed(hand: Array[CardData])
signal energy_changed(current: int, max_energy: int)
signal enemy_intent_changed(intent: String)
signal combat_ended(victory: bool)

enum State { INICIO_TURNO, JUGADOR_ACCIONA, RESOLVER_CARTA, TURNO_ENEMIGO, CHEQUEO_CLARIDAD, FIN_TURNO }

const HAND_SIZE := 5
const MAX_ENERGY := 3
const INTEGRATED_BONUS := 1.25  # las cartas integradas rinden +25% en combate

var state: State = State.INICIO_TURNO
var player: Combatant
var enemy: Combatant
var ai: ShadowAI
var current_intent: ShadowAI.Intent = ShadowAI.Intent.ATACAR
var _charged := false  # ACECHAR: el próximo golpe hace x1.5
var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
var energy: int = MAX_ENERGY
var _combat_over := false


func start_combat(deck: Array[CardData], enemy_name: String, enemy_claridad: int, enemy_attack: int, archetype: String = "sombra_menor") -> void:
	player = Combatant.new("Viajero", GameState.player_max_claridad, 0)
	player.claridad = GameState.player_claridad
	enemy = Combatant.new(enemy_name, enemy_claridad, enemy_attack)
	ai = ShadowAI.new(archetype)
	player.defeated.connect(_on_player_defeated)
	enemy.defeated.connect(_on_enemy_defeated)
	# La intención mostrada se actualiza en vivo al aplicar disonancia.
	enemy.disonancia_changed.connect(func(_v): enemy_intent_changed.emit(_intent_description()))
	draw_pile = deck.duplicate()
	draw_pile.shuffle()
	hand.clear()
	discard_pile.clear()
	_combat_over = false
	_enter_state(State.INICIO_TURNO)


func play_card(card: CardData) -> void:
	if state != State.JUGADOR_ACCIONA or _combat_over:
		return
	if card.cost > energy or not hand.has(card):
		return
	_enter_state(State.RESOLVER_CARTA)
	energy -= card.cost
	energy_changed.emit(energy, MAX_ENERGY)
	var integrated := GameState.cartas_integradas.has(card.card_name)
	for effect in card.effects:
		var objective: Combatant = enemy if effect.target == "enemy" else player
		var value := int(ceil(effect.amount * INTEGRATED_BONUS)) if integrated else effect.amount
		effect.apply(player, objective, value)
	hand.erase(card)
	discard_pile.append(card)
	card_played.emit(card)
	hand_changed.emit(hand)
	if not _combat_over:
		_enter_state(State.JUGADOR_ACCIONA)


func end_turn() -> void:
	if state != State.JUGADOR_ACCIONA or _combat_over:
		return
	_enter_state(State.TURNO_ENEMIGO)
	player.reset_shield()
	_execute_enemy_intent()
	_enter_state(State.CHEQUEO_CLARIDAD)
	if _combat_over:
		return
	_enter_state(State.FIN_TURNO)
	discard_pile.append_array(hand)
	hand.clear()
	_enter_state(State.INICIO_TURNO)


func _enter_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(state)
	if new_state == State.INICIO_TURNO:
		energy = MAX_ENERGY
		energy_changed.emit(energy, MAX_ENERGY)
		_draw_hand()
		current_intent = ai.next_intent()
		enemy_intent_changed.emit(_intent_description())
		_enter_state(State.JUGADOR_ACCIONA)


func _execute_enemy_intent() -> void:
	# El escudo de la Sombra expira al comenzar su propia acción.
	enemy.reset_shield()
	match current_intent:
		ShadowAI.Intent.ATACAR, ShadowAI.Intent.ATAQUE_FUERTE:
			player.take_damage(enemy.strike_value(_planned_strike()))
			_charged = false
		ShadowAI.Intent.DEFENDER:
			enemy.add_shield(ShadowAI.intent_value(current_intent, enemy.base_attack))
		ShadowAI.Intent.ACECHAR:
			_charged = true
		ShadowAI.Intent.DRENAR:
			var drained := enemy.strike_value(ShadowAI.intent_value(current_intent, enemy.base_attack))
			player.take_damage(drained)
			enemy.heal(drained)


func _planned_strike() -> int:
	var planned := ShadowAI.intent_value(current_intent, enemy.base_attack)
	if _charged:
		planned = int(round(planned * 1.5))
	return planned


func _intent_description() -> String:
	var value := 0
	match current_intent:
		ShadowAI.Intent.ATACAR, ShadowAI.Intent.ATAQUE_FUERTE:
			value = maxi(_planned_strike() - enemy.disonancia, 1)
		_:
			value = ShadowAI.intent_value(current_intent, enemy.base_attack)
			if current_intent == ShadowAI.Intent.DRENAR:
				value = maxi(value - enemy.disonancia, 1)
	return ShadowAI.describe(current_intent, value)


func _draw_hand() -> void:
	while hand.size() < HAND_SIZE:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			draw_pile.shuffle()
			discard_pile.clear()
		hand.append(draw_pile.pop_back())
	hand_changed.emit(hand)


func _on_player_defeated() -> void:
	_finish(false)


func _on_enemy_defeated() -> void:
	_finish(true)


func _finish(victory: bool) -> void:
	if _combat_over:
		return
	_combat_over = true
	GameState.player_claridad = player.claridad
	combat_ended.emit(victory)
