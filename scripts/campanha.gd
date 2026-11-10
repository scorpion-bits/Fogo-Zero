class_name Campanha
## As fases da campanha, da mais fácil para a mais difícil. Para criar ou ajustar uma fase,
## edite a lista abaixo (cada fase é uma Missao). O progresso fica em progresso.gd.


static func fases() -> Array[Missao]:
	var lista: Array[Missao] = []

	var m := Missao.new()
	m.id = "fase1"
	m.nome = "Primeiro aceiro"
	m.descricao = "Um dia quente e seco na fazenda. Fagulhas podem acender a palha nas zonas de risco. Abra aceiros entre elas e a sede antes de começar."
	m.causa = "Fagulhas e bitucas"
	m.dica = "Aceiro bom é aceiro aberto antes do fogo: durante o incêndio ele custa o dobro."
	m.mapa = Missao.Mapa.EXEMPLO
	m.semente = 101
	m.temperatura = 31.0
	m.umidade = 32.0
	m.vento_kmh = 10.0
	m.vento_direcao = 45.0
	m.candidatos = 2
	m.focos_iniciais = 1
	m.ameaca = 0.4
	m.orcamento = 1500
	m.cargas_pipa = 3
	m.chamadas_brigada = 1
	lista.append(m)

	m = Missao.new()
	m.id = "fase2"
	m.nome = "Queima de lixo"
	m.descricao = "Um vizinho costuma queimar lixo e restos de poda. Com o pasto seco, uma faísca basta. O vento sopra do nordeste."
	m.causa = "Queima de lixo"
	m.dica = "Pasto seco queima rápido, mas por pouco tempo. Use o caminhão-pipa na frente do fogo, não atrás dele."
	m.mapa = Missao.Mapa.GERADO
	m.semente_mapa = 31
	m.semente = 202
	m.temperatura = 33.0
	m.umidade = 25.0
	m.vento_kmh = 16.0
	m.vento_direcao = 45.0
	m.candidatos = 3
	m.focos_iniciais = 1
	m.ameaca = 0.6
	m.orcamento = 1300
	m.cargas_pipa = 3
	m.chamadas_brigada = 1
	lista.append(m)

	m = Missao.new()
	m.id = "fase3"
	m.nome = "Tarde de agosto"
	m.descricao = "36 °C, umidade de 15% e vento forte do noroeste: o tipo de dia em que a região mais queima. O fogo vai correr na direção da sede."
	m.causa = "Fagulhas da rodovia"
	m.dica = "Com vento forte, proteja o lado da sede que fica a favor do vento. A brigada demora: chame cedo."
	m.mapa = Missao.Mapa.EXEMPLO
	m.semente = 303
	m.temperatura = 36.0
	m.umidade = 15.0
	m.vento_kmh = 28.0
	m.vento_direcao = 315.0
	m.candidatos = 3
	m.focos_iniciais = 1
	m.ameaca = 0.8
	m.raio_risco = 11
	m.orcamento = 1200
	m.cargas_pipa = 3
	m.chamadas_brigada = 1
	lista.append(m)

	m = Missao.new()
	m.id = "fase4"
	m.nome = "Vento virando"
	m.descricao = "O vento começa do leste, mas a previsão diz que vai virar para o sul no meio da tarde. Um aceiro que protege um lado pode não bastar."
	m.causa = "Restos de queimada"
	m.dica = "Quando o vento vira, a frente do fogo muda. Deixe parte do orçamento para reagir."
	m.mapa = Missao.Mapa.GERADO
	m.semente_mapa = 57
	m.semente = 404
	m.temperatura = 34.0
	m.umidade = 20.0
	m.vento_kmh = 18.0
	m.vento_direcao = 90.0
	m.passo_mudanca_vento = 35
	m.nova_direcao = 180.0
	m.novo_vento_kmh = 24.0
	m.candidatos = 3
	m.focos_iniciais = 1
	m.focos_extras = [40]
	m.ameaca = 0.5
	m.raio_risco = 11
	m.orcamento = 1400
	m.cargas_pipa = 3
	m.chamadas_brigada = 1
	lista.append(m)

	m = Missao.new()
	m.id = "fase5"
	m.nome = "Noite de balões"
	m.descricao = "Balões soltos numa festa caem em pontos diferentes da fazenda. Mais de um foco ao mesmo tempo, e outro pode surgir depois."
	m.causa = "Balões"
	m.dica = "Soltar balão é crime. Com vários focos, ataque primeiro o que ameaça a sede."
	m.mapa = Missao.Mapa.GERADO
	m.semente_mapa = 64
	m.semente = 505
	m.temperatura = 32.0
	m.umidade = 18.0
	m.vento_kmh = 20.0
	m.vento_direcao = 270.0
	m.candidatos = 4
	m.focos_iniciais = 2
	m.focos_extras = [30]
	m.ameaca = 0.8
	m.orcamento = 1000
	m.cargas_pipa = 3
	m.chamadas_brigada = 1
	m.atraso_brigada = 30
	lista.append(m)

	m = Missao.new()
	m.id = "fase6"
	m.nome = "Seca histórica"
	m.descricao = "Umidade de 12%, vento de 32 km/h e recursos curtos. Dois focos de início, um terceiro depois e a brigada atrasada. Só um bom planejamento salva a sede."
	m.causa = "Vários (rodovia, lixo, balão)"
	m.dica = "Em dias assim, prevenção não é opcional: aceiros largos e limpos antes da seca."
	m.mapa = Missao.Mapa.EXEMPLO
	m.semente = 606
	m.temperatura = 38.0
	m.umidade = 12.0
	m.vento_kmh = 32.0
	m.vento_direcao = 300.0
	m.candidatos = 4
	m.focos_iniciais = 2
	m.focos_extras = [25]
	m.ameaca = 0.85
	m.orcamento = 1150
	m.cargas_pipa = 2
	m.chamadas_brigada = 1
	m.atraso_brigada = 35
	lista.append(m)

	for i in lista.size():
		lista[i].numero = i + 1
	return lista
