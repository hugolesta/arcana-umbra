#!/usr/bin/env python3
"""Genera los 78 recursos CardData (.tres) en resources/cards/ a partir de
tools/cards.json (creado por tools/extract_cards.py).

Mapeo de gameplay por palo:
  ESPADAS (Aire)  -> ATAQUE:    DamageEffect al enemigo
  BASTOS  (Fuego) -> HABILIDAD: DisonanciaEffect al enemigo
  COPAS   (Agua)  -> HABILIDAD: HealEffect al jugador
  OROS    (Tierra)-> DEFENSA:   ShieldEffect al jugador
  ARCANO_MAYOR    -> INTEGRACION: dos efectos según su elemento

Uso: python3 tools/generate_tres.py
"""
import json
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).parent.parent
OUT_DIR = ROOT / "resources" / "cards"
PIXEL_DIR = ROOT / "assets" / "cartas_pixel"

# Deben coincidir con los enums de scripts/cards/card_data.gd
SUITS = {"ESPADAS": 0, "COPAS": 1, "BASTOS": 2, "OROS": 3, "ARCANO_MAYOR": 4}
TYPES = {"ATAQUE": 0, "DEFENSA": 1, "HABILIDAD": 2, "INTEGRACION": 3}

EFFECT_SCRIPTS = {
    "damage": "res://scripts/cards/effects/damage_effect.gd",
    "heal": "res://scripts/cards/effects/heal_effect.gd",
    "shield": "res://scripts/cards/effects/shield_effect.gd",
    "disonancia": "res://scripts/cards/effects/disonancia_effect.gd",
}

EFFECT_TEXT = {
    "damage": "inflige {n} de daño a la Sombra",
    "heal": "restaura {n} de claridad",
    "shield": "otorga {n} de escudo",
    "disonancia": "aplica {n} de disonancia a la Sombra",
}

MAJOR_COMBOS = {
    "Fuego": [("damage", "enemy"), ("disonancia", "enemy")],
    "Agua": [("heal", "self"), ("shield", "self")],
    "Aire": [("damage", "enemy"), ("shield", "self")],
    "Tierra": [("shield", "self"), ("heal", "self")],
}


def gd_string(text: str) -> str:
    return '"%s"' % text.replace("\\", "\\\\").replace('"', '\\"')


def gameplay(card: dict) -> dict:
    suit, rank = card["suit"], card["rank"]
    if suit == "ESPADAS":
        return {"type": "ATAQUE", "cost": 1 + (rank - 1) // 5,
                "value": 4 + rank // 2, "effects": [("damage", "enemy")]}
    if suit == "BASTOS":
        return {"type": "HABILIDAD", "cost": 1 + (rank - 1) // 5,
                "value": 2 + rank // 3, "effects": [("disonancia", "enemy")]}
    if suit == "COPAS":
        return {"type": "HABILIDAD", "cost": 1 + (rank - 1) // 5,
                "value": 3 + rank // 2, "effects": [("heal", "self")]}
    if suit == "OROS":
        return {"type": "DEFENSA", "cost": 1 + (rank - 1) // 5,
                "value": 4 + rank // 2, "effects": [("shield", "self")]}
    element = card["element"] if card["element"] in MAJOR_COMBOS else "Aire"
    return {"type": "INTEGRACION", "cost": 2, "value": 5 + rank // 4,
            "effects": MAJOR_COMBOS[element]}


def build_tres(card: dict) -> str:
    play = gameplay(card)
    # El icono prefiere el pixel art (assets/cartas_pixel/) si existe;
    # si no, cae a la imagen Rider-Waite copiada de Kabbalah.
    img_name = "%02d-%s" % (card["index"], card["slug"])
    if (PIXEL_DIR / (img_name + ".png")).exists():
        icon_path = "res://assets/cartas_pixel/%s.png" % img_name
    else:
        icon_path = "res://assets/cards/%s.webp" % img_name
    ext = [
        ('Script', "res://scripts/cards/card_data.gd", "1_cd"),
        ('Script', "res://scripts/cards/card_effect.gd", "2_ce"),
        ('Texture2D', icon_path, "3_tex"),
    ]
    effect_ids = []
    for i, (kind, _target) in enumerate(play["effects"]):
        ext.append(('Script', EFFECT_SCRIPTS[kind], "eff_%d" % i))
        effect_ids.append("eff_%d" % i)

    lines = ['[gd_resource type="Resource" script_class="CardData" load_steps=%d format=3]'
             % (len(ext) + len(play["effects"]) + 1), ""]
    for rtype, path, rid in ext:
        lines.append('[ext_resource type="%s" path="%s" id="%s"]' % (rtype, path, rid))
    lines.append("")

    plays_text = []
    for i, (kind, target) in enumerate(play["effects"]):
        lines.append('[sub_resource type="Resource" id="sub_eff_%d"]' % i)
        lines.append('script = ExtResource("%s")' % effect_ids[i])
        lines.append("amount = %d" % play["value"])
        lines.append('target = "%s"' % target)
        lines.append("")
        plays_text.append(EFFECT_TEXT[kind].format(n=play["value"]))

    possible_plays = "Por %d de energía: %s." % (play["cost"], " y ".join(plays_text))

    lines.append("[resource]")
    lines.append('script = ExtResource("1_cd")')
    lines.append("card_name = %s" % gd_string(card["name"]))
    lines.append("suit = %d" % SUITS[card["suit"]])
    lines.append("card_type = %d" % TYPES[play["type"]])
    lines.append("cost = %d" % play["cost"])
    lines.append("base_value = %d" % play["value"])
    lines.append("description = %s" % gd_string(card["short_meaning"]))
    lines.append('icon = ExtResource("3_tex")')
    subs = ", ".join('SubResource("sub_eff_%d")' % i for i in range(len(play["effects"])))
    lines.append('effects = Array[ExtResource("2_ce")]([%s])' % subs)
    lines.append("element = %s" % gd_string(card["element"]))
    lines.append("zodiac_sign = %s" % gd_string(card["sign"]))
    lines.append("planet = %s" % gd_string(card["planet"]))
    lines.append("upright_meaning = %s" % gd_string(card["upright_meaning"]))
    lines.append("reversed_meaning = %s" % gd_string(card["reversed_meaning"]))
    lines.append("possible_plays = %s" % gd_string(possible_plays))
    return "\n".join(lines) + "\n"


def main():
    cards = json.loads((ROOT / "tools" / "cards.json").read_text(encoding="utf-8"))
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for card in cards:
        path = OUT_DIR / ("%02d-%s.tres" % (card["index"], card["slug"]))
        path.write_text(build_tres(card), encoding="utf-8")
    print("%d recursos generados en %s" % (len(cards), OUT_DIR))


if __name__ == "__main__":
    main()
