class_name Narrador
## Gera o resumo da rodada: pontuação, área queimada, "O que aconteceu?" e a dica de prevenção.

static var direcoes: PackedStringArray = [
	"norte", "nordeste", "leste", "sudeste", "sul", "sudoeste", "oeste", "noroeste",
]

static var dicas: PackedStringArray = [
	"Não queime lixo, palha ou restos de vegetação: muitas queimadas começam assim.",
	"Não jogue bitucas de cigarro pela janela do carro, principalmente na beira de estradas.",
	"Mantenha os aceiros limpos e largos antes da época seca (de junho a outubro).",
	"Soltar balões é crime e pode causar grandes incêndios.",
	"Com umidade abaixo de 30%, evite qualquer atividade com fogo ou faíscas perto da vegetação.",
	"Não tente combater sozinho um incêndio grande: afaste-se e chame ajuda.",
]

const CONTATOS := "Viu fogo? Ligue 193 (Corpo de Bombeiros) ou 199 (Defesa Civil)."


## Nome da direção (norte, nordeste...) de um vetor em coordenadas de tela (y para baixo).
static func nome_direcao(v: Vector2) -> String:
	var rumo := fposmod(rad_to_deg(atan2(v.x, -v.y)), 360.0)
	return direcoes[roundi(rumo / 45.0) % 8]


## Nome da direção de um ângulo meteorológico (de onde o vento vem).
static func nome_direcao_graus(graus: float) -> String:
	return direcoes[roundi(fposmod(graus, 360.0) / 45.0) % 8]


static func formatar_ha(valor: float) -> String:
	return ("%.1f" % valor).replace(".", ",")


static func o_que_aconteceu(sim: SimulacaoFogo, f: Ferramentas) -> PackedStringArray:
	var linhas := PackedStringArray()
	if sim.focos.is_empty():
		return linhas
	var ur := roundi(sim.umidade)
	var vento := roundi(sim.vento_kmh)
	var origem := Vector2.ZERO
	for c in sim.focos:
		origem += Vector2(c)
	origem /= sim.focos.size()
	var centro := sim.soma_pos_queimadas / maxi(sim.total_queimadas, 1)
	var ritmo := float(sim.total_queimadas) / maxi(sim.passo, 1)
	var como := "devagar"
	if ritmo > 25.0:
		como = "rápido"
	elif ritmo > 8.0:
		como = "num ritmo moderado"
	var area := formatar_ha(sim.area_queimada_ha())

	if sim.total_queimadas <= sim.focos.size() * 4:
		linhas.append("Com umidade de %d%%, a vegetação mal pegou fogo e o foco se apagou sozinho." % ur)
	elif vento >= 8 and (centro - origem).length() > 2.0:
		linhas.append("Com umidade de %d%% e vento de %d km/h vindo do %s, o fogo avançou %s para o %s e queimou %s ha." %
				[ur, vento, nome_direcao_graus(sim.vento_direcao), como, nome_direcao(centro - origem), area])
	else:
		linhas.append("Com umidade de %d%% e vento fraco (%d km/h), o fogo se espalhou %s para todos os lados e queimou %s ha." %
				[ur, vento, como, area])

	var barreiras := {
		Terreno.Tipo.ESTRADA: "A estrada",
		Terreno.Tipo.AGUA: "A água do córrego",
		Terreno.Tipo.ACEIRO: "O aceiro",
		SimulacaoFogo.BLOQUEIO_MOLHADA: "A faixa molhada pelo caminhão-pipa e pela brigada",
	}
	# O aceiro do jogador vem primeiro (é a lição principal); senão, a barreira que mais segurou.
	var escolhida := -1
	if sim.bloqueios[Terreno.Tipo.ACEIRO] > 0:
		escolhida = Terreno.Tipo.ACEIRO
	else:
		for tipo: int in barreiras:
			if sim.bloqueios[tipo] > 0 and (escolhida < 0 or sim.bloqueios[tipo] > sim.bloqueios[escolhida]):
				escolhida = tipo
	if escolhida >= 0:
		var pos: Vector2 = sim.soma_pos_bloqueios[escolhida] / sim.bloqueios[escolhida]
		linhas.append("%s segurou a frente %s." % [barreiras[escolhida], nome_direcao(pos - origem)])
	elif sim.ativos.is_empty():
		linhas.append("Nenhuma barreira foi usada: o fogo só parou quando acabou a vegetação ao alcance.")

	if sim.sede_atingida:
		linhas.append("O fogo chegou à sede no passo %d. Um aceiro aberto mais cedo entre o fogo e a sede poderia ter evitado isso." %
				sim.passo_sede_atingida)
	elif f.celulas_aceiro + f.pipas_usadas + f.brigadas_usadas > 0:
		linhas.append("A sede foi protegida.")
	else:
		linhas.append("A sede escapou, mas sem nenhuma ação de prevenção: foi sorte.")
	return linhas


static func pontuacao(sim: SimulacaoFogo, f: Ferramentas) -> int:
	var pontos := 1000.0 * (1.0 - sim.fracao_vegetacao_queimada())
	if not sim.sede_atingida:
		pontos += 500.0
	pontos += f.orcamento / 5.0 + f.cargas_pipa * 50 + f.chamadas_brigada * 100
	return roundi(pontos)


static func resumo(sim: SimulacaoFogo, f: Ferramentas) -> Dictionary:
	var por_tipo: Array[String] = []
	for tipo in [Terreno.Tipo.CANA, Terreno.Tipo.PASTO, Terreno.Tipo.MATA]:
		if sim.total_por_tipo[tipo] == 0:
			continue
		var pct := 100.0 * sim.queimadas_por_tipo[tipo] / sim.total_por_tipo[tipo]
		por_tipo.append("%s: %s%% (%s ha)" % [Terreno.nomes[tipo], ("%.1f" % pct).replace(".", ","),
				formatar_ha(sim.queimadas_por_tipo[tipo] * sim.area_celula_ha())])
	var recursos: Array[String] = [
		"Aceiro: %d células (R$ %d)" % [f.celulas_aceiro, f.celulas_aceiro * f.config.custo_aceiro_celula],
		"Caminhão-pipa: %d de %d cargas" % [f.pipas_usadas, f.config.cargas_pipa],
		"Brigada (193): %d de %d chamadas" % [f.brigadas_usadas, f.config.chamadas_brigada],
	]
	return {
		"sede_salva": not sim.sede_atingida,
		"area_ha": sim.area_queimada_ha(),
		"por_tipo": por_tipo,
		"recursos": recursos,
		"pontuacao": pontuacao(sim, f),
		"o_que_aconteceu": o_que_aconteceu(sim, f),
		"dica": dicas[absi(sim.passo + sim.total_queimadas) % dicas.size()],
	}
