class_name Grade
extends RefCounted
## Grade da simulação: o tipo de terreno e a secura de cada célula.
## A secura vai de 0 (úmido) a 255 (muito seco); no projeto real ela virá do NDVI do drone.

var largura: int
var altura: int
var terreno := PackedByteArray()
var secura := PackedByteArray()
var _terreno_original := PackedByteArray()


func _init(p_largura: int, p_altura: int) -> void:
	largura = p_largura
	altura = p_altura
	terreno.resize(largura * altura)
	terreno.fill(Terreno.Tipo.CANA)
	secura.resize(largura * altura)
	secura.fill(128)
	fixar_original()


## Monta a grade a partir do PNG de terreno (paleta fixa) e, opcionalmente, do PNG de secura
## (tons de cinza). Imagens de outro tamanho são reamostradas para `p_largura` × `p_altura`.
static func de_imagens(img_terreno: Image, img_secura: Image, p_largura: int, p_altura: int) -> Grade:
	var grade := Grade.new(p_largura, p_altura)
	var img := _preparar(img_terreno, Image.FORMAT_RGB8, p_largura, p_altura, Image.INTERPOLATE_NEAREST)
	var dados := img.get_data()
	var cache := {}
	for i in p_largura * p_altura:
		var r := dados[i * 3]
		var g := dados[i * 3 + 1]
		var b := dados[i * 3 + 2]
		var chave := (r << 16) | (g << 8) | b
		if not cache.has(chave):
			cache[chave] = Terreno.classificar(Color8(r, g, b))
		grade.terreno[i] = cache[chave]
	if img_secura != null:
		var img_s := _preparar(img_secura, Image.FORMAT_L8, p_largura, p_altura, Image.INTERPOLATE_BILINEAR)
		grade.secura = img_s.get_data()
	grade.fixar_original()
	return grade


## Carrega uma imagem de `res://` (recurso importado) ou de um caminho qualquer do disco.
static func carregar_imagem(caminho: String) -> Image:
	if caminho.is_empty():
		return null
	if caminho.begins_with("res://"):
		if not ResourceLoader.exists(caminho):
			return null
		var textura := load(caminho) as Texture2D
		return textura.get_image() if textura != null else null
	if not FileAccess.file_exists(caminho):
		return null
	return Image.load_from_file(caminho)


static func _preparar(origem: Image, formato: Image.Format, p_largura: int, p_altura: int,
		interpolacao: Image.Interpolation) -> Image:
	var img := origem.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(formato)
	if img.get_width() != p_largura or img.get_height() != p_altura:
		img.resize(p_largura, p_altura, interpolacao)
	return img


## Guarda o terreno atual como o "original" (o mapa antes dos aceiros do jogador).
func fixar_original() -> void:
	_terreno_original = terreno.duplicate()


func restaurar_original() -> void:
	terreno = _terreno_original.duplicate()


func contem(celula: Vector2i) -> bool:
	return celula.x >= 0 and celula.y >= 0 and celula.x < largura and celula.y < altura


func indice(celula: Vector2i) -> int:
	return celula.y * largura + celula.x


func posicao(i: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(i % largura, i / largura)


## Quantas células de cada tipo existem no mapa original.
func contar_originais() -> PackedInt32Array:
	var contagem := PackedInt32Array()
	contagem.resize(Terreno.QUANTIDADE)
	for t in _terreno_original:
		contagem[t] += 1
	return contagem


func para_imagem_terreno() -> Image:
	var img := Image.create(largura, altura, false, Image.FORMAT_RGB8)
	for i in largura * altura:
		var tipo := terreno[i]
		if tipo >= Terreno.TIPOS_DO_MAPA:
			tipo = Terreno.Tipo.ESTRADA
		var p := posicao(i)
		img.set_pixel(p.x, p.y, Terreno.cores_mapa[tipo])
	return img


func para_imagem_secura() -> Image:
	return Image.create_from_data(largura, altura, false, Image.FORMAT_L8, secura)
