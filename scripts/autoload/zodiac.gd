class_name Zodiac
extends RefCounted
## Cálculo del signo zodiacal occidental a partir de una fecha de nacimiento.
## Mismos 12 nombres que ya usan los datos de tarot (tools/extract_cards.py
## SIGNS): coherencia entre el perfil del jugador y el vocabulario del juego.
## Clase pura sin autoloads (testeable desde verify.gd).

# (mes, día) del ÚLTIMO día de cada signo, en orden cronológico. El signo de
# una fecha es el primer límite que sea >= esa fecha; tras el 21 dic (fin de
# Sagitario) el año envuelve a Capricornio.
const RANGES := [
	[1, 19, "Capricornio"], [2, 18, "Acuario"], [3, 20, "Piscis"],
	[4, 19, "Aries"], [5, 20, "Tauro"], [6, 20, "Géminis"],
	[7, 22, "Cáncer"], [8, 22, "Leo"], [9, 22, "Virgo"],
	[10, 22, "Libra"], [11, 21, "Escorpio"], [12, 21, "Sagitario"],
]


static func sign_for(month: int, day: int) -> String:
	for entry in RANGES:
		if month < entry[0] or (month == entry[0] and day <= entry[1]):
			return entry[2]
	return "Capricornio"  # 22-31 dic: después de Sagitario, envuelve el año


## Clave en minúsculas sin acentos para nombres de archivo (assets/zodiaco/).
static func sign_key(sign_name: String) -> String:
	const KEYS := {
		"Aries": "aries", "Tauro": "tauro", "Géminis": "geminis",
		"Cáncer": "cancer", "Leo": "leo", "Virgo": "virgo", "Libra": "libra",
		"Escorpio": "escorpio", "Sagitario": "sagitario",
		"Capricornio": "capricornio", "Acuario": "acuario", "Piscis": "piscis",
	}
	return KEYS.get(sign_name, "")
