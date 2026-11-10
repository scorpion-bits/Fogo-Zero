class_name Renderizador
extends RefCounted
## Desenha a grade numa única Image/ImageTexture (sem um nó por célula).
## A cada passo só as células alteradas são repintadas; a cada quadro, só as que estão queimando
## (para a chama piscar de amarelo a vermelho).

const COR_QUEIMADA := Color(0.17, 0.155, 0.14)
const COR_SEDE_QUEIMADA := Color(0.3, 0.07, 0.05)
const COR_MOLHADA := Color(0.35, 0.62, 0.95)
const FOGO_NOVO := Color(1.0, 0.94, 0.4)
const FOGO_MEIO := Color(1.0, 0.55, 0.08)
const FOGO_FIM := Color(0.8, 0.14, 0.05)

var sim: SimulacaoFogo
var imagem: Image
var textura: ImageTexture

var _largura: int
var _altura: int
var _buffer := PackedByteArray()
## Pequena variação de brilho por célula, para o mapa não ficar chapado.
var _variacao := PackedFloat32Array()


func _init(p_sim: SimulacaoFogo) -> void:
	sim = p_sim
	_largura = sim.largura
	_altura = sim.altura
	var n := _largura * _altura
	_buffer.resize(n * 4)
	_variacao.resize(n)
	for i in n:
		var h := sin(i * 12.9898 + 78.233) * 43758.5453
		_variacao[i] = 0.93 + 0.14 * (h - floorf(h))
	imagem = Image.create_empty(_largura, _altura, false, Image.FORMAT_RGBA8)
	textura = ImageTexture.create_from_image(imagem)
	redesenhar_tudo()


func redesenhar_tudo() -> void:
	for i in _largura * _altura:
		_pintar(i)
	sim.alteradas.clear()
	_enviar()


## Chame uma vez por quadro. `t` é o tempo em segundos, usado na animação da chama.
func atualizar(t: float) -> void:
	for i in sim.alteradas:
		_pintar(i)
	sim.alteradas.clear()
	for i in sim.ativos:
		_pintar_fogo(i, t)
	_enviar()


func _enviar() -> void:
	imagem.set_data(_largura, _altura, false, Image.FORMAT_RGBA8, _buffer)
	textura.update(imagem)


func _pintar(i: int) -> void:
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
			cor = FOGO_NOVO
	_escrever(i, cor, _variacao[i])


func _pintar_fogo(i: int, t: float) -> void:
	var fracao := float(sim.tempo[i]) / sim.tempo_queima_tipo(sim.grade.terreno[i])
	var cor: Color
	if fracao > 0.5:
		cor = FOGO_MEIO.lerp(FOGO_NOVO, (fracao - 0.5) * 2.0)
	else:
		cor = FOGO_FIM.lerp(FOGO_MEIO, fracao * 2.0)
	_escrever(i, cor, 0.86 + 0.14 * sin(t * 13.0 + _variacao[i] * 90.0))


func _escrever(i: int, cor: Color, brilho: float) -> void:
	var o := i * 4
	_buffer[o] = clampi(roundi(cor.r * brilho * 255.0), 0, 255)
	_buffer[o + 1] = clampi(roundi(cor.g * brilho * 255.0), 0, 255)
	_buffer[o + 2] = clampi(roundi(cor.b * brilho * 255.0), 0, 255)
	_buffer[o + 3] = 255
