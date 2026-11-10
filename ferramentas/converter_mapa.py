#!/usr/bin/env python3
"""Converte uma imagem de drone (GeoTIFF multiespectral ou RGB comum) nos mapas do jogo.

Saída (na pasta --saida, padrão mapas/):
  <nome>_terreno.png  cores fixas da paleta do jogo (um pixel = uma célula)
  <nome>_secura.png   tons de cinza: 0 = úmido, 255 = muito seco

Modos:
  sintetico  gera um GeoTIFF multiespectral de teste (para validar o pipeline sem o drone)
  ndvi       GeoTIFF multiespectral -> NDVI -> classes por limiares + secura
  rgb        imagem RGB comum (GeoTIFF, PNG ou JPG) -> classificação aproximada por cor

Exemplos:
  python ferramentas/converter_mapa.py sintetico
  python ferramentas/converter_mapa.py ndvi dados/teste_sintetico.tif --banda-vermelho 3 --banda-nir 5 --banda-verde 2
  python ferramentas/converter_mapa.py rgb foto_aerea.jpg --nome fazenda

ATENÇÃO: a ordem das bandas do drone do CEPIN ainda não é conhecida. Os índices são passados por
argumento (começando em 1, como no rasterio/QGIS). O GeoTIFF sintético usa a ordem
1 Azul, 2 Verde, 3 Vermelho, 4 Red Edge, 5 NIR.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

# Paleta do jogo (mesma ordem de scripts/terreno.gd).
CANA, PASTO, MATA, ESTRADA, AGUA, SEDE = range(6)
NOMES = ["cana-de-açúcar", "pasto seco", "mata nativa", "estrada/solo", "água", "construção"]
CORES = np.array([
    (0xC8, 0xB4, 0x4A),
    (0xD9, 0xC2, 0x7A),
    (0x2E, 0x6B, 0x2E),
    (0x8A, 0x7F, 0x70),
    (0x3A, 0x6E, 0xA5),
    (0xB0, 0x3A, 0x2E),
], dtype=np.uint8)

# Cores típicas de cada classe numa foto aérea (modo rgb). Ajuste se a sua imagem for diferente.
CORES_REFERENCIA_RGB = np.array([
    (115, 140, 60),   # cana
    (185, 170, 115),  # pasto seco
    (40, 70, 38),     # mata
    (150, 125, 100),  # estrada / solo exposto
    (45, 75, 95),     # água
    (175, 75, 55),    # telhado cerâmico
], dtype=np.float32)


# --- Classificação --------------------------------------------------------------------------

def classificar_ndvi(ndvi: np.ndarray, args: argparse.Namespace,
                     vermelho: np.ndarray | None = None, verde: np.ndarray | None = None) -> np.ndarray:
    """Classes por limiares de NDVI. Com a banda verde, telhados avermelhados viram 'construção'."""
    classes = np.full(ndvi.shape, MATA, dtype=np.uint8)
    classes[ndvi < args.limiar_cana] = CANA
    classes[ndvi < args.limiar_pasto] = PASTO
    classes[ndvi < args.limiar_solo] = ESTRADA
    classes[ndvi < args.limiar_agua] = AGUA
    if vermelho is not None and verde is not None:
        telhado = (ndvi < args.limiar_solo) & (vermelho > args.razao_telhado * np.maximum(verde, 1e-6))
        classes[telhado] = SEDE
    return classes


def secura_de_ndvi(ndvi: np.ndarray, classes: np.ndarray, args: argparse.Namespace) -> np.ndarray:
    """Quanto menor o NDVI, mais seco: ndvi_seco -> 255, ndvi_umido -> 0. Água = 0."""
    s = (args.ndvi_umido - ndvi) / (args.ndvi_umido - args.ndvi_seco)
    s = np.clip(s, 0.0, 1.0) * 255.0
    s[classes == AGUA] = 0
    return s.astype(np.uint8)


def classificar_rgb(rgb: np.ndarray) -> np.ndarray:
    """Classe da cor de referência mais próxima (aproximação, sem NDVI). Antes, ajusta o brilho
    da imagem para a mediana ficar igual à das cores de referência (fotos mais claras ou escuras)."""
    brilho = np.median(rgb.mean(axis=-1))
    if brilho > 1.0:
        rgb = np.clip(rgb * (np.median(CORES_REFERENCIA_RGB.mean(axis=-1)) / brilho), 0.0, 255.0)
    d = ((rgb[:, :, None, :] - CORES_REFERENCIA_RGB[None, None, :, :]) ** 2).sum(axis=-1)
    return d.argmin(axis=-1).astype(np.uint8)


def vari(rgb: np.ndarray) -> np.ndarray:
    """VARI = (G - R) / (G + R - B): índice de verde só com RGB, usado como substituto do NDVI."""
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    den = g + r - b
    den = np.where(np.abs(den) < 1e-3, 1e-3, den)
    return np.clip((g - r) / den, -1.0, 1.0)


# --- Leitura e reamostragem -----------------------------------------------------------------

def recorte_central(largura: int, altura: int, alvo_l: int, alvo_a: int) -> tuple[int, int, int, int]:
    """Maior retângulo central com a proporção da grade (para não distorcer)."""
    proporcao = alvo_l / alvo_a
    if largura / altura > proporcao:
        w, h = round(altura * proporcao), altura
    else:
        w, h = largura, round(largura / proporcao)
    return (largura - w) // 2, (altura - h) // 2, w, h


def ler_bandas_tif(caminho: Path, bandas: list[int], alvo_l: int, alvo_a: int) -> list[np.ndarray]:
    """Lê as bandas pedidas já reamostradas para a grade (média por área), com recorte central."""
    import rasterio
    from rasterio.enums import Resampling
    from rasterio.windows import Window

    with rasterio.open(caminho) as src:
        for b in bandas:
            if not 1 <= b <= src.count:
                sys.exit(f"Erro: banda {b} não existe (o arquivo tem {src.count} bandas).")
        x, y, w, h = recorte_central(src.width, src.height, alvo_l, alvo_a)
        _avisar_recorte(src.width, src.height, w, h)
        print(f"Entrada: {caminho.name}, {src.width}×{src.height} px, {src.count} bandas, CRS {src.crs}")
        dados = src.read(bandas, window=Window(x, y, w, h), out_shape=(len(bandas), alvo_a, alvo_l),
                         resampling=Resampling.average, masked=True)
    return [np.ma.filled(d.astype(np.float32), np.nan) for d in dados]


def ler_rgb(caminho: Path, alvo_l: int, alvo_a: int, bandas_rgb: list[int]) -> np.ndarray:
    if caminho.suffix.lower() in (".tif", ".tiff"):
        bandas = ler_bandas_tif(caminho, bandas_rgb, alvo_l, alvo_a)
        rgb = np.nan_to_num(np.stack(bandas, axis=-1), nan=0.0)
        if rgb.max() > 255.0 or rgb.max() <= 1.5:
            # Refletância (0..1) ou 16 bits: estica cada banda (percentis 2-98) para 0..255.
            baixo, alto = np.percentile(rgb, 2, axis=(0, 1)), np.percentile(rgb, 98, axis=(0, 1))
            rgb = np.clip((rgb - baixo) / np.maximum(alto - baixo, 1e-6), 0.0, 1.0) * 255.0
        return rgb
    img = Image.open(caminho).convert("RGB")
    x, y, w, h = recorte_central(img.width, img.height, alvo_l, alvo_a)
    _avisar_recorte(img.width, img.height, w, h)
    print(f"Entrada: {caminho.name}, {img.width}×{img.height} px (RGB)")
    img = img.crop((x, y, x + w, y + h)).resize((alvo_l, alvo_a), Image.BOX)
    return np.asarray(img, dtype=np.float32)


def _avisar_recorte(largura: int, altura: int, w: int, h: int) -> None:
    if (w, h) != (largura, altura):
        print(f"Recorte central de {w}×{h} px para manter a proporção da grade (sem distorcer).")


# --- Saída ----------------------------------------------------------------------------------

def salvar(classes: np.ndarray, secura: np.ndarray, args: argparse.Namespace) -> None:
    for x, y, w, h in args.sede or []:
        classes[y:y + h, x:x + w] = SEDE
    saida = Path(args.saida)
    saida.mkdir(parents=True, exist_ok=True)
    caminho_t = saida / f"{args.nome}_terreno.png"
    caminho_s = saida / f"{args.nome}_secura.png"
    Image.fromarray(CORES[classes], mode="RGB").save(caminho_t)
    Image.fromarray(secura, mode="L").save(caminho_s)
    total = classes.size
    print(f"Grade {classes.shape[1]}×{classes.shape[0]}:")
    for i, nome in enumerate(NOMES):
        n = int((classes == i).sum())
        if n:
            print(f"  {nome:15s} {100 * n / total:5.1f}%")
    print(f"Secura média: {secura.mean():.0f}/255")
    print(f"Salvo: {caminho_t}\n       {caminho_s}")
    if not (classes == SEDE).any():
        print("Aviso: nenhuma construção encontrada. Marque a sede com --sede X,Y,L,A (em células).")


# --- GeoTIFF sintético ----------------------------------------------------------------------

# Refletâncias típicas (Azul, Verde, Vermelho, Red Edge, NIR) por classe, para o teste.
REFLETANCIAS = np.array([
    (0.04, 0.09, 0.07, 0.20, 0.30),  # cana      (NDVI ~0,62)
    (0.10, 0.14, 0.14, 0.22, 0.27),  # pasto seco (NDVI ~0,32)
    (0.03, 0.06, 0.03, 0.18, 0.42),  # mata      (NDVI ~0,87)
    (0.14, 0.17, 0.21, 0.23, 0.25),  # estrada   (NDVI ~0,09)
    (0.06, 0.07, 0.05, 0.03, 0.02),  # água      (NDVI ~-0,43)
    (0.10, 0.12, 0.30, 0.30, 0.31),  # telhado   (NDVI ~0,02, vermelho alto)
], dtype=np.float32)


def gerar_sintetico(args: argparse.Namespace) -> None:
    """GeoTIFF de 5 bandas (refletância 0..1, float32) feito a partir do mapa de exemplo, com
    ruído e uma faixa extra nas laterais (para testar o recorte). Pixel de 2 m, SIRGAS 2000 / UTM 22S."""
    import rasterio
    from rasterio.transform import from_origin

    from gerar_mapa_exemplo import gerar

    terreno, secura = gerar()
    escala = 4
    t = np.kron(terreno, np.ones((escala, escala), dtype=np.uint8))
    s = np.kron(secura.astype(np.float32), np.ones((escala, escala), dtype=np.float32)) / 255.0
    faixa = 64
    t = np.pad(t, ((0, 0), (faixa, faixa)), constant_values=CANA)
    s = np.pad(s, ((0, 0), (faixa, faixa)), constant_values=0.5)
    rng = np.random.default_rng(1)
    bandas = REFLETANCIAS[t].transpose(2, 0, 1).copy()
    # Vegetação mais seca: menos NIR e mais vermelho (NDVI menor).
    vegetacao = np.isin(t, [CANA, PASTO, MATA])
    bandas[4][vegetacao] *= (1.1 - 0.2 * s[vegetacao])
    bandas[2][vegetacao] *= (0.9 + 0.2 * s[vegetacao])
    bandas *= rng.normal(1.0, 0.05, bandas.shape).astype(np.float32)
    bandas = np.clip(bandas, 0.0, 1.0).astype(np.float32)

    destino = Path(args.saida_tif)
    destino.parent.mkdir(parents=True, exist_ok=True)
    perfil = {
        "driver": "GTiff", "width": t.shape[1], "height": t.shape[0], "count": 5, "dtype": "float32",
        "crs": "EPSG:31982", "transform": from_origin(789000.0, 7592000.0, 2.0, 2.0), "compress": "deflate",
    }
    with rasterio.open(destino, "w", **perfil) as dst:
        dst.write(bandas)
        for i, nome in enumerate(["Azul", "Verde", "Vermelho", "Red Edge", "NIR"], start=1):
            dst.set_band_description(i, nome)
    print(f"GeoTIFF sintético salvo em {destino} ({t.shape[1]}×{t.shape[0]} px, 5 bandas: "
          "1 Azul, 2 Verde, 3 Vermelho, 4 Red Edge, 5 NIR)")

    # Também uma "foto aérea" RGB sintética, para testar o modo rgb.
    foto = CORES_REFERENCIA_RGB[t] * rng.normal(1.0, 0.08, t.shape + (3,))
    foto[vegetacao] *= (0.9 + 0.2 * s[vegetacao])[:, None]
    destino_rgb = destino.with_name(destino.stem + "_rgb.png")
    Image.fromarray(np.clip(foto * 1.15, 0, 255).astype(np.uint8), mode="RGB").save(destino_rgb)
    print(f"Foto RGB sintética salva em {destino_rgb}")


# --- Linha de comando -----------------------------------------------------------------------

def retangulo(texto: str) -> tuple[int, int, int, int]:
    partes = [int(p) for p in texto.split(",")]
    if len(partes) != 4:
        raise argparse.ArgumentTypeError("use X,Y,LARGURA,ALTURA (em células)")
    return partes[0], partes[1], partes[2], partes[3]


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="modo", required=True)

    s = sub.add_parser("sintetico", help="gera um GeoTIFF multiespectral de teste")
    s.add_argument("--saida-tif", default=str(RAIZ / "dados" / "teste_sintetico.tif"))

    comuns = argparse.ArgumentParser(add_help=False)
    comuns.add_argument("entrada", type=Path)
    comuns.add_argument("--largura", type=int, default=128, help="células na horizontal (padrão 128)")
    comuns.add_argument("--altura", type=int, default=128, help="células na vertical (padrão 128)")
    comuns.add_argument("--saida", default=str(RAIZ / "mapas"), help="pasta de saída (padrão mapas/)")
    comuns.add_argument("--nome", default="mapa", help="prefixo dos arquivos (padrão: mapa)")
    comuns.add_argument("--sede", type=retangulo, action="append",
                        help="marca construções: X,Y,LARGURA,ALTURA em células (pode repetir)")

    n = sub.add_parser("ndvi", parents=[comuns], help="GeoTIFF multiespectral (NDVI)")
    n.add_argument("--banda-vermelho", type=int, required=True, help="índice da banda vermelha (1 = primeira)")
    n.add_argument("--banda-nir", type=int, required=True, help="índice da banda NIR (1 = primeira)")
    n.add_argument("--banda-verde", type=int, help="opcional: ajuda a achar telhados (construções)")
    n.add_argument("--limiar-agua", type=float, default=0.0, help="NDVI abaixo disso = água (padrão 0,0)")
    n.add_argument("--limiar-solo", type=float, default=0.18, help="abaixo disso = estrada/solo (0,18)")
    n.add_argument("--limiar-pasto", type=float, default=0.42, help="abaixo disso = pasto seco (0,42)")
    n.add_argument("--limiar-cana", type=float, default=0.72, help="abaixo disso = cana; acima = mata (0,72)")
    n.add_argument("--ndvi-seco", type=float, default=0.15, help="NDVI que vira secura 255 (0,15)")
    n.add_argument("--ndvi-umido", type=float, default=0.85, help="NDVI que vira secura 0 (0,85)")
    n.add_argument("--razao-telhado", type=float, default=1.6, help="vermelho/verde mínimo de telhado (1,6)")

    r = sub.add_parser("rgb", parents=[comuns], help="imagem RGB comum (classificação aproximada)")
    r.add_argument("--bandas-rgb", default="1,2,3",
                   help="só para GeoTIFF: índices das bandas vermelha, verde e azul (padrão 1,2,3)")

    args = p.parse_args()
    if args.modo == "sintetico":
        gerar_sintetico(args)
        return

    if args.modo == "ndvi":
        indices = [args.banda_vermelho, args.banda_nir] + ([args.banda_verde] if args.banda_verde else [])
        bandas = ler_bandas_tif(args.entrada, indices, args.largura, args.altura)
        vermelho, nir = bandas[0], bandas[1]
        verde = bandas[2] if args.banda_verde else None
        soma = nir + vermelho
        ndvi = np.where(soma > 1e-6, (nir - vermelho) / np.where(soma > 1e-6, soma, 1.0), 0.0)
        ndvi = np.nan_to_num(ndvi, nan=0.0)
        print(f"NDVI: mínimo {ndvi.min():.2f}, médio {ndvi.mean():.2f}, máximo {ndvi.max():.2f}")
        classes = classificar_ndvi(ndvi, args, vermelho, verde)
        secura = secura_de_ndvi(ndvi, classes, args)
    else:
        rgb = ler_rgb(args.entrada, args.largura, args.altura, [int(b) for b in args.bandas_rgb.split(",")])
        classes = classificar_rgb(rgb)
        indice = vari(rgb)
        args.ndvi_umido, args.ndvi_seco = 0.35, -0.05  # faixa típica do VARI
        secura = secura_de_ndvi(indice, classes, args)
    salvar(classes, secura, args)


if __name__ == "__main__":
    main()
