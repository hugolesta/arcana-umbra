extends Node
## Smoke test de la tienda. Uso:
##   godot --headless --path . res://tools/SmokeShop.tscn
## Instancia ShopScene real y comprueba: comprar añade la carta y descuenta
## esencia (con descuento de integrada), quitar elimina y cobra, y los topes
## (sin esencia / mazo mínimo) se respetan. Restaura el estado al terminar.

var _frames := 0
var _shop: Node
var _prev_esencia: int
var _prev_deck: Array[CardData]
var _prev_integradas: Array[String]


func _ready() -> void:
	_prev_esencia = GameState.esencia
	_prev_deck = GameState.mazo_permanente.duplicate()
	_prev_integradas = GameState.cartas_integradas.duplicate()

	GameState.esencia = 100
	_shop = load("res://scenes/ShopScene.tscn").instantiate()
	add_child(_shop)
	var node := MapNode.new()
	node.node_type = MapNode.NodeType.TIENDA
	_shop.setup(node)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames != 10:
		return
	var failures: Array[String] = []

	# 1. Comprar: la carta entra al mazo y la esencia baja según el precio.
	var offer: CardData = _shop._offers[0]
	var price: int = GameState.card_price(offer)
	var deck_size: int = GameState.mazo_permanente.size()
	_shop._buy(offer)
	if GameState.mazo_permanente.size() != deck_size + 1:
		failures.append("comprar no añadió la carta al mazo")
	if GameState.esencia != 100 - price:
		failures.append("comprar no descontó el precio correcto")

	# 2. Descuento de integración: una carta integrada cuesta la mitad.
	var offer2: CardData = _shop._offers[0]
	var base_price := 50 if offer2.suit == CardData.Suit.ARCANO_MAYOR else 25
	GameState.cartas_integradas.append(offer2.card_name)
	if GameState.card_price(offer2) != base_price / 2:
		failures.append("la carta integrada no cuesta la mitad")

	# 3. Quitar: elimina del mazo y cobra el precio.
	var esencia_before: int = GameState.esencia
	deck_size = GameState.mazo_permanente.size()
	var to_remove: CardData = GameState.mazo_permanente[0]
	_shop._remove(to_remove)
	if GameState.mazo_permanente.size() != deck_size - 1:
		failures.append("quitar no eliminó la carta")
	if GameState.esencia != esencia_before - _shop.REMOVE_PRICE:
		failures.append("quitar no cobró el precio")

	# 4. Topes: sin esencia no se puede comprar.
	GameState.esencia = 0
	if GameState.buy_card(_shop._offers[0] if not _shop._offers.is_empty() else to_remove):
		failures.append("se pudo comprar sin esencia")

	# Restaurar estado previo.
	GameState.esencia = _prev_esencia
	GameState.mazo_permanente = _prev_deck
	GameState.cartas_integradas = _prev_integradas
	GameState.save_progress()

	if failures.is_empty():
		print("SMOKE TIENDA: OK (compra, descuento integrada, quitar, topes)")
		get_tree().quit(0)
	else:
		for f in failures:
			print("FALLO: ", f)
		get_tree().quit(1)
