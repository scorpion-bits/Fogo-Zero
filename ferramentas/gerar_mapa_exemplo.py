#!/usr/bin/env python3
"""Gera o mapa de exemplo do protótipo: uma fazenda fictícia de 128×128 células.

Saída: mapas/exemplo_terreno.png (paleta fixa) e mapas/exemplo_secura.png (tons de cinza).
Só precisa de numpy e Pillow. O resultado é sempre o mesmo (semente fixa).

Uso:
    python3 ferramentas/gerar_mapa_exemplo.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

CANA, PASTO, MATA, ESTRADA, AGUA, SEDE = range(6)
CORES = np.array([
    (0xC8, 0xB4, 0x4A),  # cana-de-açúcar
    (0xD9, 0xC2, 0x7A),  # pasto seco
    (0x2E, 0x6B, 0x2E),  # mata nativa
    (0x8A, 0x7F, 0x70),  # estrada / aceiro
    (0x3A, 0x6E, 0xA5),  # água
    (0xB0, 0x3A, 0x2E),  # construção / sede
], dtype=np.uint8)

TAM = 128
RAIZ = Path(__file__).resolve().parent.parent


def ruido_suave(rng: np.random.Generator, celulas: int) -> np.ndarray:
    """Ruído suave entre 0 e 1 (grade aleatória pequena ampliada com bicúbica)."""
    pequeno = rng.random((celulas, celulas)).astype(np.float32)
    img = Image.fromarray(pequeno, mode="F").resize((TAM, TAM), Image.BICUBIC)
    r = np.asarray(img)
    return (r - r.min()) / (r.max() - r.min())


def gerar() -> tuple[np.ndarray, np.ndarray]:
    rng = np.random.default_rng(42)
    yy, xx = np.mgrid[0:TAM, 0:TAM]
    t = np.full((TAM, TAM), CANA, dtype=np.uint8)
    ruido = ruido_suave(rng, 10)

    # Córrego com mata ciliar, de norte a sul, na parte oeste.
    centro = 22 + 5 * np.sin(np.arange(TAM) / 14.0) + 2 * np.sin(np.arange(TAM) / 5.0)
    distancia_corrego = np.abs(xx - centro[yy])
    t[distancia_corrego <= 5 + 2 * ruido] = MATA
    anterior = int(round(centro[0]))
    for y in range(TAM):
        x = int(round(centro[y]))
        # Preenche entre a posição anterior e a atual: o córrego fica sem furos diagonais.
        t[y, min(anterior, x):max(anterior, x) + 2] = AGUA
        anterior = x

    # Mancha de mata nativa a nordeste.
    d_mata = np.hypot(xx - 106, yy - 24)
    t[d_mata < 9 + 12 * ruido_suave(rng, 14)] = MATA

    # Pasto a sudoeste.
    d_pasto = np.hypot((xx - 46) / 1.2, yy - 92)
    pasto = d_pasto < 10 + 12 * ruido_suave(rng, 12)
    t[pasto & (t == CANA)] = PASTO

    # Piquete de pasto em volta da sede.
    d_sede = np.hypot(xx - 92, yy - 84)
    t[(d_sede <= 11) & (t == CANA)] = PASTO

    # Estrada municipal (ao sul) e carreadores de terra entre os talhões de cana.
    t[108:110, :] = ESTRADA
    t[110:, :] = np.where(xx[110:, :] < 60, PASTO, CANA)
    t[110:, :][np.abs(xx[110:, :] - centro[110:, None].astype(int)) <= 1] = AGUA
    t[0:59, 64] = ESTRADA
    t[58, 64:105] = ESTRADA
    t[85:108, 92] = ESTRADA

    # Açude.
    t[np.hypot(xx - 72, yy - 93) <= 4] = AGUA

    # Sede: casa e galpão.
    t[80:85, 87:93] = SEDE
    t[81:85, 95:98] = SEDE

    # Secura: base com ruído, pasto mais seco, perto da água e na mata mais úmido.
    secura = 110 + 90 * ruido_suave(rng, 8)
    secura[t == PASTO] += 40
    secura[t == MATA] -= 35
    agua = (t == AGUA).astype(np.float32)
    perto_agua = _borrar(agua, 4)
    secura -=70 * np.clip(perto_agua * 3, 0, 1)
    secura[(xx > 28) & (xx < 64) & (yy < 57)] += 25  # talhão de cana com palha seca
    secura = np.clip(secura, 0, 255).astype(np.uint8)
    return t, secura


def _borrar(mascara: np.ndarray, raio: int) -> np.ndarray:
    """Média em caixa simples, para saber o quanto cada célula está perto da água."""
    acumulado = np.zeros_like(mascara)
    for dy in range(-raio, raio + 1):
        for dx in range(-raio, raio + 1):
            acumulado += np.roll(np.roll(mascara, dy, axis=0), dx, axis=1)
    return acumulado / (2 * raio + 1) ** 2


def main() -> None:
    terreno, secura = gerar()
    destino = RAIZ / "mapas"
    destino.mkdir(exist_ok=True)
    Image.fromarray(CORES[terreno], mode="RGB").save(destino / "exemplo_terreno.png")
    Image.fromarray(secura, mode="L").save(destino / "exemplo_secura.png")
    print(f"Mapa de exemplo salvo em {destino}")


if __name__ == "__main__":
    main()
