class_name ClassificadorFoto
## Transforma uma foto aérea ou de satélite (RGB comum) numa grade do jogo, classificando cada
## célula pela cor de referência mais próxima. É a mesma aproximação do modo "rgb" do
## ferramentas/converter_mapa.py: sem NDVI, a precisão é bem menor que a do drone multiespectral.

## Cores típicas de cada classe numa foto aérea, na ordem: cana, pasto seco, mata, solo/estrada,
## água, telhado. Ajuste se as suas imagens forem diferentes.
const REFERENCIAS: Array[Color] = [
	Color8(115, 140, 60),
	Color8(185, 170, 115),
	Color8(40, 70, 38),
	Color8(150, 125, 100),
	Color8(45, 75, 95),
	Color8(175, 75, 55),
]
## Faixa do índice VARI usada para a secura (mais verde = mais úmido).
const VARI_UMIDO := 0.35
const VARI_SECO := -0.05


## Recorta o centro em quadrado e reduz para `lado` × `lado`, tirando a média dos pixels.
static func reduzir(origem: Image, lado: int) -> Image:
	var img := origem.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	var menor := mini(img.get_width(), img.get_height())
	if img.get_width() != img.get_height():
		@warning_ignore("integer_division")
		img = img.get_region(Rect2i((img.get_width() - menor) / 2, (img.get_height() - menor) / 2, menor, menor))
	var atual := menor
	# Reduz pela metade várias vezes: cada redução bilinear tira a média de 2×2 pixels.
	while atual >= lado * 2:
		atual = int(atual / 2.0)
		img.resize(atual, atual, Image.INTERPOLATE_BILINEAR)
	if atual != lado:
		img.resize(lado, lado, Image.INTERPOLATE_BILINEAR)
	return img


## Classifica uma foto já reduzida. Telhados viram solo exposto (a terra roxa da região tem a
## mesma cor): a sede vem do OpenStreetMap ou é marcada pelo jogador.
static func classificar(img: Image) -> Grade:
	var lado := img.get_width()
	var g := Grade.new(lado, img.get_height())
	var dados := img.get_data()
	var n := lado * img.get_height()
	# Ajuste de brilho: a mediana da imagem fica igual à das cores de referência.
	var brilhos := PackedFloat32Array()
	brilhos.resize(n)
	for i in n:
		brilhos[i] = (dados[i * 3] + dados[i * 3 + 1] + dados[i * 3 + 2]) / 3.0
	var ordenados := brilhos.duplicate()
	ordenados.sort()
	@warning_ignore("integer_division")
	var mediana := ordenados[n / 2]
	var mediana_ref := 0.0
	var brilhos_ref := PackedFloat32Array()
	for c in REFERENCIAS:
		brilhos_ref.append((c.r8 + c.g8 + c.b8) / 3.0)
	var ref_ordenados := brilhos_ref.duplicate()
	ref_ordenados.sort()
	mediana_ref = (ref_ordenados[2] + ref_ordenados[3]) / 2.0
	var fator := mediana_ref / mediana if mediana > 1.0 else 1.0

	for i in n:
		var r := minf(dados[i * 3] * fator, 255.0)
		var gr := minf(dados[i * 3 + 1] * fator, 255.0)
		var b := minf(dados[i * 3 + 2] * fator, 255.0)
		var melhor := 0
		var menor := INF
		for k in REFERENCIAS.size():
			var ref := REFERENCIAS[k]
			var d := (r - ref.r8) ** 2 + (gr - ref.g8) ** 2 + (b - ref.b8) ** 2
			if d < menor:
				menor = d
				melhor = k
		# Pela cor não dá para separar com segurança telhado de terra roxa, solo de palha seca e
		# água de sombra: solo e telhado viram palha seca (pasto) e água vira mata. Estradas, rios
		# e construções vêm do OpenStreetMap (ou da paleta, no mapa do drone).
		var tipo := melhor
		if tipo == Terreno.Tipo.SEDE or tipo == Terreno.Tipo.ESTRADA:
			tipo = Terreno.Tipo.PASTO
		elif tipo == Terreno.Tipo.AGUA:
			tipo = Terreno.Tipo.MATA
		g.terreno[i] = tipo
		var den := gr + r - b
		var vari := clampf((gr - r) / (den if absf(den) > 0.001 else 0.001), -1.0, 1.0)
		var secura := clampf((VARI_UMIDO - vari) / (VARI_UMIDO - VARI_SECO), 0.0, 1.0) * 255.0
		g.secura[i] = roundi(secura)
	for passada in 2:
		g.terreno = filtro_maioria(g.terreno, lado, img.get_height())
	g.fixar_original()
	return g


## Cada célula vira o tipo mais comum entre ela e as 8 vizinhas (tira os pontinhos isolados).
static func filtro_maioria(tipos: PackedByteArray, largura: int, altura: int) -> PackedByteArray:
	var saida := tipos.duplicate()
	var contagem := PackedInt32Array()
	contagem.resize(Terreno.QUANTIDADE)
	for y in range(1, altura - 1):
		for x in range(1, largura - 1):
			contagem.fill(0)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					contagem[tipos[(y + dy) * largura + x + dx]] += 1
			var melhor := tipos[y * largura + x]
			for t in Terreno.QUANTIDADE:
				if contagem[t] > contagem[melhor]:
					melhor = t
			saida[y * largura + x] = melhor
	return saida


## A imagem usa a paleta do jogo (mapa pronto) ou é uma foto? Olha quantos pixels estão perto
## de alguma cor da paleta.
static func eh_paleta(img: Image) -> bool:
	var amostra := img.duplicate() as Image
	if amostra.is_compressed():
		amostra.decompress()
	amostra.convert(Image.FORMAT_RGB8)
	if amostra.get_width() > 256 or amostra.get_height() > 256:
		amostra.resize(mini(amostra.get_width(), 256), mini(amostra.get_height(), 256), Image.INTERPOLATE_NEAREST)
	var dados := amostra.get_data()
	var n := amostra.get_width() * amostra.get_height()
	var perto := 0
	for i in n:
		for cor in Terreno.cores_mapa:
			if absi(dados[i * 3] - cor.r8) + absi(dados[i * 3 + 1] - cor.g8) + absi(dados[i * 3 + 2] - cor.b8) < 24:
				perto += 1
				break
	return perto >= n * 0.85
