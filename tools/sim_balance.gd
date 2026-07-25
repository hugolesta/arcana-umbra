extends Node
## Simulador de balance. Uso:
##   godot --headless --path . res://tools/SimBalance.tscn
## Juega N combates headless por arquetipo con el mazo inicial y una política
## golosa, con semilla fija (determinista), y verifica bandas de win-rate:
##   sombra_menor (piso 1)  >= 85%
##   sombra_elite (piso 5)  >= 50%
##   jefe_sombra  (piso 4)  entre 30% y 95% (ni imposible ni trivial)
## Sale 0 si todas las bandas se cumplen; imprime el detalle siempre.

const RUNS_PER_ARCHETYPE := 200
const SEED := 20260725

const SCENARIOS := [
	{"archetype": "sombra_menor", "name": "Sombra Menor", "floor": 1,
		"claridad_base": 18, "claridad_per_floor": 2, "attack": 5, "min_rate": 0.85, "max_rate": 1.0},
	{"archetype": "sombra_elite", "name": "Sombra Élite", "floor": 5,
		"claridad_base": 30, "claridad_per_floor": 2, "attack": 8, "min_rate": 0.50, "max_rate": 1.0},
	{"archetype": "jefe_sombra", "name": "Jefe de la Sombra", "floor": 4,
		"claridad_base": 50, "claridad_per_floor": 3, "attack": 10, "min_rate": 0.30, "max_rate": 0.95},
]

var _prev_claridad: int


func _ready() -> void:
	_prev_claridad = GameState.player_claridad
	seed(SEED)
	var failures := 0

	for scenario in SCENARIOS:
		var wins := 0
		var total_turns := 0
		for i in range(RUNS_PER_ARCHETYPE):
			var result := _simulate_combat(scenario)
			if result.victory:
				wins += 1
			total_turns += result.turns
		var rate := wins / float(RUNS_PER_ARCHETYPE)
		var verdict := "OK"
		if rate < scenario.min_rate or rate > scenario.max_rate:
			verdict = "FALLO"
			failures += 1
		print("%s %s: win-rate %.1f%% (banda %d-%d%%), %.1f turnos de media" % [
			verdict, scenario.name, rate * 100.0,
			int(scenario.min_rate * 100), int(scenario.max_rate * 100),
			total_turns / float(RUNS_PER_ARCHETYPE)])

	GameState.player_claridad = _prev_claridad
	print("BALANCE: %s" % ("PASA" if failures == 0 else "FALLA (%d bandas)" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _simulate_combat(scenario: Dictionary) -> Dictionary:
	GameState.player_claridad = GameState.player_max_claridad
	var manager := CombatManager.new()
	add_child(manager)
	var result := {"victory": false, "turns": 0, "done": false}
	manager.combat_ended.connect(func(victory: bool):
		result.victory = victory
		result.done = true)
	var enemy_claridad: int = scenario.claridad_base + scenario.floor * scenario.claridad_per_floor
	manager.start_combat(GameState.mazo_permanente, scenario.name,
		enemy_claridad, scenario.attack, scenario.archetype)

	while not result.done and result.turns < 40:
		result.turns += 1
		_play_turn(manager)
		if result.done:
			break
		manager.end_turn()
	manager.queue_free()
	return result


## Política golosa: escudo si viene golpe que superaría el escudo actual,
## curación si la claridad va baja, si no daño; disonancia antes de golpes.
func _play_turn(manager: CombatManager) -> void:
	var guard := 12
	while guard > 0:
		guard -= 1
		var card := _pick_card(manager)
		if card == null:
			return
		manager.play_card(card)
		if manager.hand.is_empty():
			return


func _pick_card(manager: CombatManager) -> CardData:
	var incoming := 0
	match manager.current_intent:
		ShadowAI.Intent.ATACAR, ShadowAI.Intent.ATAQUE_FUERTE:
			incoming = maxi(manager._planned_strike() - manager.enemy.disonancia, 1)
		ShadowAI.Intent.DRENAR:
			incoming = ShadowAI.intent_value(manager.current_intent, manager.enemy.base_attack)

	var affordable: Array[CardData] = []
	for card in manager.hand:
		if card.cost <= manager.energy:
			affordable.append(card)
	if affordable.is_empty():
		return null

	var hurt := manager.player.claridad < int(manager.player.max_claridad * 0.45)
	var priorities: Array[CardData.CardType] = []
	if incoming > manager.player.shield:
		priorities.append(CardData.CardType.DEFENSA)
	if hurt:
		priorities.append(CardData.CardType.HABILIDAD)
	priorities.append(CardData.CardType.ATAQUE)
	priorities.append(CardData.CardType.INTEGRACION)
	priorities.append(CardData.CardType.HABILIDAD)
	priorities.append(CardData.CardType.DEFENSA)

	for wanted in priorities:
		var best: CardData = null
		for card in affordable:
			if card.card_type == wanted and (best == null or card.base_value > best.base_value):
				best = card
		if best:
			return best
	return affordable[0]
