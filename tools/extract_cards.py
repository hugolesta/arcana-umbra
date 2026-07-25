#!/usr/bin/env python3
"""Extrae los datos de las 78 cartas Rider-Waite desde el proyecto Kabbalah
(elarboldelavida.com.ar/tarot-rider-waite) y genera tools/cards.json.

Fuente (SOLO LECTURA): tarot-rider-waite.html del proyecto Kabbalah.
Uso: python3 tools/extract_cards.py [ruta-al-html]
"""
import json
import re
import sys
import unicodedata
from pathlib import Path

DEFAULT_SOURCE = "/Users/hugo.lesta/Desktop/Projects/hugolesta/Kabbalah/tarot-rider-waite.html"

PLANETS = {
    "Sol", "Luna", "Mercurio", "Venus", "Marte", "Júpiter", "Saturno",
    "Urano", "Neptuno", "Plutón", "Tierra (planeta)",
}
SIGNS = {
    "Aries", "Tauro", "Géminis", "Cáncer", "Leo", "Virgo", "Libra",
    "Escorpio", "Sagitario", "Capricornio", "Acuario", "Piscis",
}
ELEMENTS = {"Fuego", "Agua", "Aire", "Tierra"}

SUIT_BY_SLUG = {"bastos": "BASTOS", "copas": "COPAS", "espadas": "ESPADAS", "oros": "OROS"}


def strip_tags(html: str) -> str:
    text = re.sub(r"<[^>]+>", " ", html)
    return re.sub(r"\s+", " ", text).strip()


def classify_meta(names):
    planet = sign = element = ""
    for n in names:
        if n in PLANETS and not planet:
            planet = n
        elif n in SIGNS and not sign:
            sign = n
        elif n in ELEMENTS and not element:
            element = n
    return planet, sign, element


def main():
    source = Path(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SOURCE)
    html = source.read_text(encoding="utf-8")

    blocks = html.split('<div class="card"><div class="card-inner">')[1:]
    cards = []
    for block in blocks:
        img = re.search(r'src="/cards/(\d+)-([a-z0-9\-]+)\.webp"', block)
        if not img:
            continue
        index, slug = int(img.group(1)), img.group(2)

        name = strip_tags(re.search(r'<h3 class="card-name">(.*?)</h3>', block).group(1))
        metas = re.findall(r'<span class="card-meta-name">(.*?)</span>', block)
        planet, sign, element = classify_meta([strip_tags(m) for m in metas])
        short = strip_tags(re.search(r'<div class="card-meta-desc">(.*?)</div>', block).group(1))
        upright_m = re.search(r'<div class="card-desc"><p>(.*?)</p></div>', block, re.S)
        upright = strip_tags(upright_m.group(1)) if upright_m else ""
        reversed_m = re.search(r'<p class="back-section-text">(.*?)</p>', block, re.S)
        reversed_meaning = strip_tags(reversed_m.group(1)) if reversed_m else ""

        suit = "ARCANO_MAYOR"
        rank = index  # 0-21 para mayores
        for key, value in SUIT_BY_SLUG.items():
            if key in slug:
                suit = value
                rank = (index - 22) % 14 + 1  # 1=As ... 14=Rey
                break

        cards.append({
            "index": index,
            "slug": slug,
            "name": name,
            "suit": suit,
            "rank": rank,
            "planet": planet,
            "sign": sign,
            "element": element,
            "short_meaning": short,
            "upright_meaning": upright,
            "reversed_meaning": reversed_meaning,
        })

    cards.sort(key=lambda c: c["index"])
    out = Path(__file__).parent / "cards.json"
    out.write_text(json.dumps(cards, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"{len(cards)} cartas extraídas -> {out}")
    missing = [c["name"] for c in cards if not c["upright_meaning"] or not c["element"]]
    if missing:
        print(f"AVISO: cartas con datos incompletos: {missing}")


if __name__ == "__main__":
    main()
