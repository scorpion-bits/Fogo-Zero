class_name Veiculos
extends RefCounted
## Parte visual da brigada e do caminhão-pipa: a viatura da brigada sai da borda do mapa e vem pelas
## estradas (e aceiros) até o ponto chamado, chegando no passo em que a simulação faz ela agir; o
## caminhão-pipa aparece no ponto jogando água. Não muda a simulação, só desenha.

const DURACAO_AGUA := 1.6

var sim: SimulacaoFogo
var _rotas := {}
var _efeitos: Array[Dictionary] = []


func _init(p_sim: SimulacaoFogo) -> void:
	sim = p_sim


## Esguicho de água (caminhão-pipa ou chegada da brigada) com o raio em células.
func agua(centro: Vector2i, raio: int, tempo: float, com_caminhao: bool) -> void:
	_efeitos.append({"centro": centro, "raio": raio, "inicio": tempo, "caminhao": com_caminhao})


## Rota (em células) da borda do mapa até `alvo`, pelas estradas e aceiros quando houver.
func rota(alvo: Vector2i) -> PackedVector2Array:
	var g := sim.grade
	var l := g.largura
	var a := g.altura
	var pai := PackedInt32Array()
	pai.resize(l * a)
	pai.fill(-2)
	var fila := PackedInt32Array()
	# Começa por todas as células de estrada na borda do mapa.
	for i in l * a:
		var p := g.posicao(i)
		if (p.x == 0 or p.y == 0 or p.x == l - 1 or p.y == a - 1) and _transitavel(g.terreno[i]):
			pai[i] = -1
			fila.append(i)
	var melhor := -1
	var melhor_dist := INF
	var k := 0
	while k < fila.size():
		var i := fila[k]
		k += 1
		var d := Vector2(g.posicao(i)).distance_squared_to(Vector2(alvo))
		if d < melhor_dist:
			melhor_dist = d
			melhor = i
		var p := g.posicao(i)
		for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + v
			if g.contem(q):
				var j := g.indice(q)
				if pai[j] == -2 and _transitavel(g.terreno[j]):
					pai[j] = i
					fila.append(j)
	var pontos := PackedVector2Array()
	if melhor < 0:
		# Sem estrada: vem em linha reta da borda mais próxima.
		var borda := Vector2(alvo)
		var distancias := [alvo.x, l - 1 - alvo.x, alvo.y, a - 1 - alvo.y]
		match distancias.find(distancias.min()):
			0: borda.x = -2
			1: borda.x = l + 1
			2: borda.y = -2
			3: borda.y = a + 1
		pontos.append(borda + Vector2(0.5, 0.5))
	else:
		var caminho := PackedVector2Array()
		var i := melhor
		while i >= 0:
			caminho.append(Vector2(g.posicao(i)) + Vector2(0.5, 0.5))
			i = pai[i]
		caminho.reverse()
		# Entra um pouco de fora do mapa.
		var primeiro := caminho[0]
		var fora := primeiro
		if primeiro.x < 1: fora.x = -2
		elif primeiro.x > l - 1: fora.x = l + 2
		elif primeiro.y < 1: fora.y = -2
		else: fora.y = a + 2
		pontos.append(fora)
		pontos.append_array(caminho)
	pontos.append(Vector2(alvo) + Vector2(0.5, 0.5))
	return pontos


func _transitavel(tipo: int) -> bool:
	return tipo == Terreno.Tipo.ESTRADA or tipo == Terreno.Tipo.ACEIRO


## Desenha tudo. `progresso_passo` (0..1) suaviza o movimento entre um passo e outro.
func desenhar(alvo: MapaView, f: Ferramentas, tempo: float, progresso_passo: float) -> void:
	var cel := alvo.tamanho_celula()
	var origem := alvo.area_mapa().position
	# Viaturas da brigada a caminho.
	if f.chamadas_pendentes.is_empty():
		_rotas.clear()
	for chamada in f.chamadas_pendentes:
		var chave := chamada.get_instance_id()
		if not _rotas.has(chave):
			_rotas[chave] = rota(chamada.centro)
		var pontos: PackedVector2Array = _rotas[chave]
		var inicio := chamada.passo_chegada - f.config.atraso_brigada
		var t := clampf((sim.passo - inicio + progresso_passo) / float(f.config.atraso_brigada), 0.0, 1.0)
		var pos_dir := _ao_longo(pontos, t)
		# Trajeto que falta, tracejado.
		var restante := PackedVector2Array([pos_dir[0]])
		var andado := t * _comprimento(pontos)
		var soma := 0.0
		for k in range(1, pontos.size()):
			soma += pontos[k - 1].distance_to(pontos[k])
			if soma > andado:
				restante.append(pontos[k])
		for k in range(1, restante.size()):
			alvo.draw_dashed_line(origem + restante[k - 1] * cel, origem + restante[k] * cel,
					Color(1, 0.35, 0.3, 0.7), 2.0, 6.0)
		_viatura(alvo, origem + pos_dir[0] * cel, pos_dir[1], cel, tempo, Color("#D7261E"), true)
	# Esguichos de água.
	var vivos: Array[Dictionary] = []
	for e in _efeitos:
		var idade: float = tempo - e["inicio"]
		if idade > DURACAO_AGUA:
			continue
		vivos.append(e)
		var celula_centro: Vector2i = e["centro"]
		var centro := origem + (Vector2(celula_centro) + Vector2(0.5, 0.5)) * cel
		var raio_max: float = (e["raio"] + 0.5) * cel
		var t := idade / DURACAO_AGUA
		for anel in 3:
			var r := raio_max * clampf(t * 1.4 - anel * 0.18, 0.0, 1.0)
			if r > 0.0:
				alvo.draw_arc(centro, r, 0.0, TAU, 48, Color(0.75, 0.9, 1.0, 0.8 * (1.0 - t)), 2.5, true)
		for gota in 18:
			var ang := gota * TAU / 18.0 + celula_centro.x
			var dist := raio_max * fmod(t * 1.3 + gota * 0.137, 1.0)
			alvo.draw_circle(centro + Vector2.from_angle(ang) * dist, 2.2, Color(0.8, 0.93, 1.0, 0.9 * (1.0 - t)))
		if e["caminhao"]:
			_viatura(alvo, centro + Vector2(0, raio_max + cel * 1.5), 0.0, cel, tempo, Color("#2F6FB3"), false)
	_efeitos = vivos


func ha_efeitos() -> bool:
	return not _efeitos.is_empty()


func _viatura(alvo: CanvasItem, pos: Vector2, angulo: float, cel: float, tempo: float, cor: Color, sirene: bool) -> void:
	var tamanho := Vector2(maxf(cel * 3.6, 26.0), maxf(cel * 1.9, 14.0))
	alvo.draw_set_transform(pos, angulo)
	alvo.draw_rect(Rect2(-tamanho / 2.0 + Vector2(1.5, 1.5), tamanho), Color(0, 0, 0, 0.45))
	alvo.draw_rect(Rect2(-tamanho / 2.0, tamanho), cor)
	# Cabine na frente.
	alvo.draw_rect(Rect2(Vector2(tamanho.x * 0.18, -tamanho.y / 2.0), Vector2(tamanho.x * 0.32, tamanho.y)), cor.lightened(0.25))
	if sirene:
		var pisca := int(tempo * 6.0) % 2 == 0
		alvo.draw_circle(Vector2(tamanho.x * 0.12, -tamanho.y * 0.25), tamanho.y * 0.2, Color("#3FA9FF") if pisca else Color("#FF3B30"))
		alvo.draw_circle(Vector2(tamanho.x * 0.12, tamanho.y * 0.25), tamanho.y * 0.2, Color("#FF3B30") if pisca else Color("#3FA9FF"))
	else:
		alvo.draw_rect(Rect2(Vector2(-tamanho.x * 0.42, -tamanho.y * 0.3), Vector2(tamanho.x * 0.5, tamanho.y * 0.6)), Color(0.85, 0.92, 1.0))
	alvo.draw_set_transform(Vector2.ZERO)


## Posição e ângulo ao longo da rota, com `t` de 0 a 1.
func _ao_longo(pontos: PackedVector2Array, t: float) -> Array:
	var total := _comprimento(pontos)
	var alvo_dist := t * total
	var soma := 0.0
	for k in range(1, pontos.size()):
		var trecho := pontos[k - 1].distance_to(pontos[k])
		if soma + trecho >= alvo_dist and trecho > 0.0:
			var u := (alvo_dist - soma) / trecho
			return [pontos[k - 1].lerp(pontos[k], u), (pontos[k] - pontos[k - 1]).angle()]
		soma += trecho
	return [pontos[pontos.size() - 1], 0.0]


func _comprimento(pontos: PackedVector2Array) -> float:
	var total := 0.0
	for k in range(1, pontos.size()):
		total += pontos[k - 1].distance_to(pontos[k])
	return total
