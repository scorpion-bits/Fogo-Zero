class_name SimulacaoFogo
extends RefCounted
## Autômato celular de propagação do fogo.
##
## É lógica pura: não depende de nós nem de desenho, então pode ser testada sozinha
## (veja testes/teste_simulacao.gd). A cada passo, cada célula queimando tenta acender cada
## vizinha (vizinhança de Moore, 8 células) com a probabilidade:
##
##     p = p_base(tipo) × f_secura × f_umidade × f_vento × f_diagonal
##
## O resultado é reproduzível: mesma semente + mesmas ações = mesmo resultado.

enum Estado { INTACTA, QUEIMANDO, QUEIMADA, MOLHADA }

## Deslocamentos das 8 vizinhas (Moore), em coordenadas de tela (y cresce para baixo, norte = cima).
const DX: Array[int] = [-1, 0, 1, -1, 1, -1, 0, 1]
const DY: Array[int] = [-1, -1, -1, 0, 0, 1, 1, 1]
## Posição extra em `bloqueios` para as tentativas barradas por células molhadas.
const BLOQUEIO_MOLHADA := Terreno.QUANTIDADE

var config: SimulacaoConfig
var grade: Grade
var largura: int
var altura: int

var estado := PackedByteArray()
## Para células queimando: passos de queima restantes. Para molhadas: passos até secar.
var tempo := PackedInt32Array()
var ativos := PackedInt32Array()
var molhadas := PackedInt32Array()
var passo := 0
var rng := RandomNumberGenerator.new()
## Células que mudaram desde a última vez que alguém esvaziou a lista (usada pelo desenho).
var alteradas := PackedInt32Array()

# Clima em uso.
var temperatura := 0.0
var umidade := 0.0
var vento_kmh := 0.0
## De onde o vento vem, em graus (0 = norte, 90 = leste), como nas estações meteorológicas.
var vento_direcao := 0.0

# Estatísticas da rodada.
var focos: Array[Vector2i] = []
var queimadas_por_tipo := PackedInt32Array()
var total_por_tipo := PackedInt32Array()
var total_queimadas := 0
var soma_pos_queimadas := Vector2.ZERO
var bloqueios := PackedInt32Array()
var soma_pos_bloqueios: Array[Vector2] = []
var apagadas := 0
var pico_ativos := 0
var sede_atingida := false
var passo_sede_atingida := -1

var _p_tipo := PackedFloat32Array()
var _queima_tipo := PackedInt32Array()
var _fator_secura := PackedFloat32Array()
var _fator_direcao := PackedFloat32Array()
var _fator_umidade := 1.0


func _init(p_config: SimulacaoConfig, p_grade: Grade) -> void:
	config = p_config
	grade = p_grade
	largura = grade.largura
	altura = grade.altura
	_p_tipo.resize(Terreno.QUANTIDADE)
	_queima_tipo.resize(Terreno.QUANTIDADE)
	for t in Terreno.QUANTIDADE:
		_p_tipo[t] = config.p_base(t)
		_queima_tipo[t] = maxi(config.tempo_queima(t), 1)
	_fator_direcao.resize(8)
	definir_clima(config.temperatura_padrao, config.umidade_padrao, config.vento_padrao_kmh,
			config.direcao_vento_padrao)
	reiniciar(config.semente)


## Volta ao mapa original (sem aceiros) e zera fogo, água e estatísticas.
func reiniciar(semente: int) -> void:
	grade.restaurar_original()
	var n := largura * altura
	estado.resize(n)
	estado.fill(Estado.INTACTA)
	tempo.resize(n)
	tempo.fill(0)
	ativos = PackedInt32Array()
	molhadas = PackedInt32Array()
	alteradas = PackedInt32Array()
	passo = 0
	rng.seed = semente
	focos.clear()
	queimadas_por_tipo = PackedInt32Array()
	queimadas_por_tipo.resize(Terreno.QUANTIDADE)
	total_por_tipo = grade.contar_originais()
	total_queimadas = 0
	soma_pos_queimadas = Vector2.ZERO
	bloqueios = PackedInt32Array()
	bloqueios.resize(Terreno.QUANTIDADE + 1)
	soma_pos_bloqueios.clear()
	soma_pos_bloqueios.resize(Terreno.QUANTIDADE + 1)
	soma_pos_bloqueios.fill(Vector2.ZERO)
	apagadas = 0
	pico_ativos = 0
	sede_atingida = false
	passo_sede_atingida = -1
	_fator_secura.resize(n)
	for i in n:
		_fator_secura[i] = lerpf(config.secura_min, config.secura_max, grade.secura[i] / 255.0)


## Atualiza o clima. `direcao` é de onde o vento vem (padrão meteorológico).
func definir_clima(p_temperatura: float, p_umidade: float, p_vento_kmh: float, direcao: float) -> void:
	temperatura = p_temperatura
	umidade = clampf(p_umidade, 0.0, 100.0)
	vento_kmh = maxf(p_vento_kmh, 0.0)
	vento_direcao = fposmod(direcao, 360.0)
	_fator_umidade = clampf(pow(1.0 - umidade / 100.0, config.k_umidade), config.f_umidade_min, 1.0)
	var para_onde := vetor_vento()
	for k in 8:
		var d := Vector2(DX[k], DY[k]).normalized()
		var f := exp(config.c_vento * vento_kmh * para_onde.dot(d))
		if DX[k] != 0 and DY[k] != 0:
			f *= config.fator_diagonal
		_fator_direcao[k] = f


## Vetor unitário para onde o vento sopra, em coordenadas de tela.
func vetor_vento() -> Vector2:
	var rumo := deg_to_rad(vento_direcao + 180.0)
	return Vector2(sin(rumo), -cos(rumo))


## Probabilidade de a célula `j` pegar fogo vinda de uma vizinha na direção `k` (0..7).
func probabilidade(j: int, k: int) -> float:
	var p := _p_tipo[grade.terreno[j]] * _fator_secura[j] * _fator_umidade * _fator_direcao[k]
	if estado[j] == Estado.MOLHADA:
		p *= config.fator_molhada
	return minf(p, 1.0)


func fator_umidade() -> float:
	return _fator_umidade


func avancar() -> void:
	passo += 1
	var novos := PackedInt32Array()
	for i in ativos:
		var x := i % largura
		@warning_ignore("integer_division")
		var y := i / largura
		for k in 8:
			var nx := x + DX[k]
			var ny := y + DY[k]
			if nx < 0 or ny < 0 or nx >= largura or ny >= altura:
				continue
			var j := ny * largura + nx
			var e := estado[j]
			if e != Estado.INTACTA and e != Estado.MOLHADA:
				continue
			var t := grade.terreno[j]
			if _p_tipo[t] <= 0.0:
				_registrar_bloqueio(t, nx, ny)
				continue
			if rng.randf() < probabilidade(j, k):
				_acender(j, t)
				novos.append(j)
			elif e == Estado.MOLHADA:
				_registrar_bloqueio(BLOQUEIO_MOLHADA, nx, ny)

	var restantes := PackedInt32Array()
	for i in ativos:
		tempo[i] -= 1
		if tempo[i] <= 0:
			estado[i] = Estado.QUEIMADA
			alteradas.append(i)
		else:
			restantes.append(i)
	restantes.append_array(novos)
	ativos = restantes
	pico_ativos = maxi(pico_ativos, ativos.size())

	var ainda_molhadas := PackedInt32Array()
	for i in molhadas:
		if estado[i] != Estado.MOLHADA:
			continue
		tempo[i] -= 1
		if tempo[i] <= 0:
			estado[i] = Estado.INTACTA
			alteradas.append(i)
		else:
			ainda_molhadas.append(i)
	molhadas = ainda_molhadas


## Começa um foco na célula. Retorna false se ela não puder queimar.
func iniciar_foco(celula: Vector2i) -> bool:
	if not grade.contem(celula):
		return false
	var j := grade.indice(celula)
	var t := grade.terreno[j]
	if estado[j] != Estado.INTACTA or _p_tipo[t] <= 0.0:
		return false
	_acender(j, t)
	ativos.append(j)
	focos.append(celula)
	return true


## Transforma a célula em aceiro (barreira). Retorna false se não for possível.
func abrir_aceiro(celula: Vector2i) -> bool:
	if not grade.contem(celula):
		return false
	var j := grade.indice(celula)
	var t := grade.terreno[j]
	if estado[j] != Estado.INTACTA and estado[j] != Estado.MOLHADA:
		return false
	if t == Terreno.Tipo.ESTRADA or t == Terreno.Tipo.AGUA or t == Terreno.Tipo.ACEIRO or t == Terreno.Tipo.SEDE:
		return false
	grade.terreno[j] = Terreno.Tipo.ACEIRO
	alteradas.append(j)
	return true


## Molha um círculo: apaga as células queimando e deixa as intactas molhadas por
## `passos` passos. Retorna quantas células em chamas foram apagadas.
func molhar_area(centro: Vector2i, raio: int, passos: int) -> int:
	var apagadas_agora := 0
	for j in celulas_no_raio(centro, raio):
		var e := estado[j]
		if e == Estado.QUEIMANDO:
			estado[j] = Estado.QUEIMADA
			tempo[j] = 0
			apagadas_agora += 1
			alteradas.append(j)
		elif _p_tipo[grade.terreno[j]] > 0.0 and (e == Estado.INTACTA or e == Estado.MOLHADA):
			if e == Estado.INTACTA:
				molhadas.append(j)
			estado[j] = Estado.MOLHADA
			tempo[j] = passos
			alteradas.append(j)
	if apagadas_agora > 0:
		var restantes := PackedInt32Array()
		for i in ativos:
			if estado[i] == Estado.QUEIMANDO:
				restantes.append(i)
		ativos = restantes
	apagadas += apagadas_agora
	return apagadas_agora


func celulas_no_raio(centro: Vector2i, raio: int) -> PackedInt32Array:
	var lista := PackedInt32Array()
	for dy in range(-raio, raio + 1):
		for dx in range(-raio, raio + 1):
			if dx * dx + dy * dy > raio * raio + raio:
				continue
			var c := centro + Vector2i(dx, dy)
			if grade.contem(c):
				lista.append(grade.indice(c))
	return lista


func ha_fogo() -> bool:
	return not ativos.is_empty()


## A rodada termina quando o fogo acaba ou quando ele chega à sede (derrota).
func terminou() -> bool:
	return not focos.is_empty() and (ativos.is_empty() or sede_atingida)


func area_celula_ha() -> float:
	return config.metros_por_celula * config.metros_por_celula / 10000.0


func area_queimada_ha() -> float:
	return total_queimadas * area_celula_ha()


## Fração (0..1) das células de vegetação que queimaram.
func fracao_vegetacao_queimada() -> float:
	var total := 0
	var queimadas := 0
	for t in [Terreno.Tipo.CANA, Terreno.Tipo.PASTO, Terreno.Tipo.MATA]:
		total += total_por_tipo[t]
		queimadas += queimadas_por_tipo[t]
	return float(queimadas) / total if total > 0 else 0.0


## Tempo de queima total de um tipo (usado no desenho para a cor da chama).
func tempo_queima_tipo(tipo: int) -> int:
	return _queima_tipo[tipo]


func _acender(j: int, t: int) -> void:
	estado[j] = Estado.QUEIMANDO
	tempo[j] = _queima_tipo[t]
	queimadas_por_tipo[t] += 1
	total_queimadas += 1
	soma_pos_queimadas += Vector2(grade.posicao(j))
	alteradas.append(j)
	if t == Terreno.Tipo.SEDE and not sede_atingida:
		sede_atingida = true
		passo_sede_atingida = passo


func _registrar_bloqueio(tipo: int, x: int, y: int) -> void:
	bloqueios[tipo] += 1
	soma_pos_bloqueios[tipo] += Vector2(x, y)
