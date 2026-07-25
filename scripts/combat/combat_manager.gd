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

var state: State = State.INICIO_TURNO
var player: Combatant
var enemy: Combatant
var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
var energy: int = MAX_ENERGY
var _combat_over := false


func start_combat(deck: Array[CardData], enemy_name: String, enemy_claridad: int, enemy_attack: int) -> void:
	player = Combatant.new("Viajero", GameState.player_max_claridad, 0)
	player.claridad = GameState.player_claridad
	enemy = Combatant.new(enemy_name, enemy_claridad, enemy_attack)
	player.defeated.connect(_on_player_defeated)
	enemy.defeated.connect(_on_enemy_defeated)
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
	for effect in card.effects:
		var objective: Combatant = enemy if effect.target == "enemy" else player
		effect.apply(player, objective)
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
	player.take_damage(enemy.attack_value())
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
		enemy_intent_changed.emit("La Sombra atacará con %d" % maxi(enemy.base_attack - enemy.disonancia, 1))
		_enter_state(State.JUGADOR_ACCIONA)


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
