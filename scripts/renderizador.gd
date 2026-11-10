class_name Renderizador
extends RefCounted
## Mantém a textura de dados que o shader do mapa (recursos/mapa.gdshader) desenha. Cada texel é
## uma célula: R = tipo, G = estado, B = intensidade (fogo restante, brasa ou água), A = secura.
## Só as células que mudaram são reescritas; a animação (chama, água, fumaça) é feita no shader.
## `imagem_plana()` gera a versão antiga, de cores chapadas, para salvar imagens nos testes.

const COR_QUEIMADA := Color(0.17, 0.155, 0.14)
const COR_SEDE_QUEIMADA := Color(0.3, 0.07, 0.05)
const COR_MOLHADA := Color(0.35, 0.62, 0.95)
const FOGO_NOVO := Color(1.0, 0.94, 0.4)
const FOGO_MEIO := Color(1.0, 0.55, 0.08)
const FOGO_FIM := Color(0.8, 0.14, 0.05)
## Quanto a brasa esfria a cada passo (de 255 até 0).
const ESFRIAMENTO := 18

var sim: SimulacaoFogo
var imagem: Image
var textura: ImageTexture

var _largura: int
var _altura: int
var _buffer := PackedByteArray()
var _brasa := PackedByteArray()
var _esfriando := PackedInt32Array()
var _ultimo_passo := -1


func _init(p_sim: SimulacaoFogo) -> void:
	sim = p_sim
	_largura = sim.largura
	_altura = sim.altura
	var n := _largura * _altura
	_buffer.resize(n * 4)
	_brasa.resize(n)
	imagem = Image.create_empty(_largura, _altura, false, Image.FORMAT_RGBA8)
	textura = ImageTexture.create_from_image(imagem)
	redesenhar_tudo()


func redesenhar_tudo() -> void:
	_brasa.fill(0)
	_esfriando = PackedInt32Array()
	var todas := PackedInt32Array()
	todas.resize(_largura * _altura)
	for i in todas.size():
		todas[i] = i
	_escrever_varias(todas)
	sim.alteradas.clear()
	_ultimo_passo = sim.passo
	_enviar()


## Chame uma vez por quadro (`_t` fica por compatibilidade: a animação agora é do shader).
func atualizar(_t: float = 0.0) -> void:
	var novo_passo := sim.passo != _ultimo_passo
	var estado := sim.estado
	var terreno := sim.grade.terreno
	for i in sim.alteradas:
		if estado[i] == SimulacaoFogo.Estado.QUEIMADA and _brasa[i] == 0 and terreno[i] != Terreno.Tipo.ACEIRO:
			_brasa[i] = 255
			_esfriando.append(i)
	_escrever_varias(sim.alteradas)
	sim.alteradas.clear()
	if novo_passo:
		_ultimo_passo = sim.passo
		var ainda := PackedInt32Array()
		for i in _esfriando:
			_brasa[i] = maxi(_brasa[i] - ESFRIAMENTO, 0)
			if _brasa[i] > 0:
				ainda.append(i)
		_escrever_varias(_esfriando)
		_esfriando = ainda
		_escrever_varias(sim.ativos)
		_escrever_varias(sim.molhadas)
	_enviar()


func _enviar() -> void:
	imagem.set_data(_largura, _altura, false, Image.FORMAT_RGBA8, _buffer)
	textura.update(imagem)


func _escrever_varias(indices: PackedInt32Array) -> void:
	if indices.is_empty():
		return
	var terreno := sim.grade.terreno
	var secura := sim.grade.secura
	var estado := sim.estado
	var tempo := sim.tempo
	var inverso := PackedFloat32Array()
	for t in Terreno.QUANTIDADE:
		inverso.append(255.0 / sim.tempo_queima_tipo(t))
	var inverso_molhada := 255.0 / maxi(sim.config.passos_molhada, 1)
	for i in indices:
		var o := i * 4
		var tipo := terreno[i]
		var e := estado[i]
		var valor := 0
		if e == SimulacaoFogo.Estado.QUEIMANDO:
			valor = mini(int(tempo[i] * inverso[tipo]), 255)
		elif e == SimulacaoFogo.Estado.QUEIMADA:
			valor = _brasa[i]
		elif e == SimulacaoFogo.Estado.MOLHADA:
			valor = clampi(int(tempo[i] * inverso_molhada), 0, 255)
		_buffer[o] = tipo
		_buffer[o + 1] = e
		_buffer[o + 2] = valor
		_buffer[o + 3] = secura[i]


## Imagem de cores chapadas (uma célula por pixel), para salvar quadros nos testes.
func imagem_plana() -> Image:
	var img := Image.create_empty(_largura, _altura, false, Image.FORMAT_RGBA8)
	for i in _largura * _altura:
		var tipo := sim.grade.terreno[i]
		var cor: Color
		match sim.estado[i]:
			SimulacaoFogo.Estado.INTACTA:
				cor = Terreno.cores_tela[tipo]
			SimulacaoFogo.Estado.QUEIMADA:
				cor = COR_SEDE_QUEIMADA if tipo == Terreno.Tipo.SEDE else COR_QUEIMADA
			SimulacaoFogo.Estado.MOLHADA:
				cor = Terreno.cores_tela[tipo].lerp(COR_MOLHADA, 0.6)
			_:
				cor = FOGO_MEIO
		img.set_pixel(i % _largura, int(i / float(_largura)), cor)
	return img
