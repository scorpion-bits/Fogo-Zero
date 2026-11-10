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

## Pontuação e estrelas (veja avaliar()).
const PONTOS_AREA := 1000
const PONTOS_SEDE := 500
const LIMIAR_UMA_ESTRELA_SEM_SEDE := 0.3
const LIMIAR_DUAS_ESTRELAS := 0.5
const LIMIAR_TRES_ESTRELAS := 0.8
## Abaixo disto (células), o incêndio de referência é pequeno demais para medir o que foi evitado.
const MIN_CELULAS_REFERENCIA := 40

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
		linhas.append("O fogo não conseguiu começar: os aceiros isolaram os pontos de risco. Prevenção é isso!")
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


## Nota da missão, comparando com a simulação de referência (o mesmo incêndio sem nenhuma ação).
## `ref_queimadas` < 0 quando não há referência (modo livre).
static func avaliar(sim: SimulacaoFogo, f: Ferramentas, ref_queimadas: int, ref_sede: bool,
		tem_sede: bool) -> Dictionary:
	var sede_salva := not sim.sede_atingida
	var evitada := 1.0
	var significativa := ref_queimadas >= MIN_CELULAS_REFERENCIA
	if ref_queimadas > 0:
		evitada = clampf(1.0 - float(sim.total_queimadas) / ref_queimadas, 0.0, 1.0)
	# Com a sede atingida a partida para antes do fogo acabar: não dá para medir o que foi evitado.
	if sim.sede_atingida and tem_sede:
		evitada = 0.0
		significativa = false
	var pontos_area := roundi(PONTOS_AREA * evitada)
	if not significativa and not sim.sede_atingida:
		pontos_area = roundi(PONTOS_AREA * (1.0 - sim.fracao_vegetacao_queimada()))
	var pontos_sede := PONTOS_SEDE if sede_salva and tem_sede else 0
	var pontos_recursos := 0 if sim.sede_atingida else roundi(f.orcamento / 10.0) + f.cargas_pipa * 30 + f.chamadas_brigada * 60
	var estrelas := 0
	if ref_queimadas >= 0 and (sede_salva or not tem_sede):
		if not significativa:
			estrelas = 3
		else:
			estrelas = 1 if tem_sede else (1 if evitada >= LIMIAR_UMA_ESTRELA_SEM_SEDE else 0)
			if evitada >= LIMIAR_DUAS_ESTRELAS:
				estrelas = 2
			if evitada >= LIMIAR_TRES_ESTRELAS:
				estrelas = 3
	var linhas := PackedStringArray()
	if ref_queimadas >= 0:
		var ha_ref := ref_queimadas * sim.area_celula_ha()
		linhas.append("Sem nenhuma ação, este incêndio queimaria %s ha%s." % [formatar_ha(ha_ref),
				" e atingiria a sede" if ref_sede and tem_sede else ""])
		if sim.sede_atingida and tem_sede:
			linhas.append("O fogo chegou à sede no passo %d e a missão terminou." % sim.passo_sede_atingida)
		elif significativa:
			linhas.append("Você evitou %d%% dessa área." % roundi(100.0 * evitada))
	return {
		"estrelas": estrelas,
		"evitada": evitada,
		"tem_referencia": ref_queimadas >= 0,
		"comparacao": linhas,
		"pontuacao": pontos_area + pontos_sede + pontos_recursos,
		"pontos_detalhe": PackedStringArray([
			"Área preservada: %d" % pontos_area,
			"Sede salva: %d" % pontos_sede,
			"Recursos poupados: %d" % pontos_recursos,
		]),
	}


static func resumo(sim: SimulacaoFogo, f: Ferramentas) -> Dictionary:
	var por_tipo: Array[String] = []
	for tipo in [Terreno.Tipo.CANA, Terreno.Tipo.PASTO, Terreno.Tipo.MATA]:
		if sim.total_por_tipo[tipo] == 0:
			continue
		var pct := 100.0 * sim.queimadas_por_tipo[tipo] / sim.total_por_tipo[tipo]
		por_tipo.append("%s: %s%% (%s ha)" % [Terreno.nomes[tipo], ("%.1f" % pct).replace(".", ","),
				formatar_ha(sim.queimadas_por_tipo[tipo] * sim.area_celula_ha())])
	var recursos: Array[String] = [
		"Aceiro: %d células (R$ %s)" % [f.celulas_aceiro, Hud.formatar_inteiro(f.gasto_aceiro)],
		"Caminhão-pipa: %d de %d cargas" % [f.pipas_usadas, f.config.cargas_pipa],
		"Brigada (193): %d de %d chamadas" % [f.brigadas_usadas, f.config.chamadas_brigada],
	]
	return {
		"sede_salva": not sim.sede_atingida,
		"area_ha": sim.area_queimada_ha(),
		"por_tipo": por_tipo,
		"recursos": recursos,
		"o_que_aconteceu": o_que_aconteceu(sim, f),
		"dica": dicas[absi(sim.passo + sim.total_queimadas) % dicas.size()],
	}
