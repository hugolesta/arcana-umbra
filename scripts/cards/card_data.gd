class_name CardData
extends Resource
## Datos de una carta del tarot Rider-Waite adaptada a mecánica de combate.
## Los 78 recursos .tres en res://resources/cards/ se generan con
## tools/generate_tres.py a partir de los datos de elarboldelavida.com.ar.

enum Suit { ESPADAS, COPAS, BASTOS, OROS, ARCANO_MAYOR }
enum CardType { ATAQUE, DEFENSA, HABILIDAD, INTEGRACION }

@export var card_name: String
@export var suit: Suit
@export var card_type: CardType
@export var cost: int = 1
@export var base_value: int = 0
@export var description: String
@export var icon: Texture2D
@export var effects: Array[CardEffect]

@export_group("Tarot", "")
@export var element: String
@export var zodiac_sign: String
@export var planet: String
@export_multiline var upright_meaning: String
@export_multiline var reversed_meaning: String
@export_multiline var possible_plays: String


func suit_name() -> String:
	return Suit.keys()[suit].capitalize().replace("_", " ")


func type_name() -> String:
	return CardType.keys()[card_type].capitalize()
