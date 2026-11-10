extends SceneTree
## Testes da simulação, sem interface. Rode com:
##     godot --headless --path . -s testes/teste_simulacao.gd
## Para salvar imagens do resultado do modo demonstração:
##     godot --headless --path . -s testes/teste_simulacao.gd -- --imagens=/caminho/pasta

var _falhas := 0
var _config: SimulacaoConfig


func _init() -> void:
	_config = load("res://recursos/simulacao_config.tres") as SimulacaoConfig
	_teste_umidade()
	_teste_vento()
	_teste_barreiras()
	_teste_reproducao()
	_teste_ferramentas()
	_teste_mapa_exemplo()
	_teste_gerador()
	_teste_demo()
	_teste_missoes()
	_teste_classificador()
	_teste_desempenho()
	print("")
	if _falhas == 0:
		print("TODOS OS TESTES PASSARAM")
	else:
		print("%d TESTE(S) FALHARAM" % _falhas)
	quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, descricao: String) -> void:
	print(("  [ok]    " if condicao else "  [FALHA] ") + descricao)
	if not condicao:
		_falhas += 1


func _grade_uniforme(tipo: int, lado: int = 96) -> Grade:
	var g := Grade.new(lado, lado)
	g.terreno.fill(tipo)
	g.fixar_original()
	return g


## Roda até o fogo acabar (ou `max_passos`) e devolve a simulação.
func _rodar(grade: Grade, umidade: float, vento: float, direcao: float, semente: int,
		max_passos: int = 400) -> SimulacaoFogo:
	var sim := SimulacaoFogo.new(_config, grade)
	sim.definir_clima(30.0, umidade, vento, direcao)
	sim.reiniciar(semente)
	@warning_ignore("integer_division")
	sim.iniciar_foco(Vector2i(grade.largura / 2, grade.altura / 2))
	while sim.ha_fogo() and sim.passo < max_passos:
		sim.avancar()
	return sim


func _teste_umidade() -> void:
	print("Umidade:")
	var medias := {}
	for ur in [15.0, 30.0, 50.0, 75.0, 85.0]:
		var soma := 0
		for s in 10:
			soma += _rodar(_grade_uniforme(Terreno.Tipo.CANA), ur, 8.0, 90.0, 100 + s).total_queimadas
		medias[ur] = soma / 10.0
		print("    UR %2d%% -> %.0f células queimadas (média de 10)" % [ur, medias[ur]])
	_checar(medias[75.0] < 60, "com UR > 70% o fogo quase não se espalha")
	_checar(medias[15.0] > 3000, "com UR < 20% o fogo se espalha muito")


func _teste_vento() -> void:
	print("Vento:")
	# Vento de oeste (270°) a 30 km/h: o fogo deve ir para leste.
	var sim := _rodar(_grade_uniforme(Terreno.Tipo.CANA, 128), 35.0, 30.0, 270.0, 7, 45)
	var centro := sim.soma_pos_queimadas / sim.total_queimadas
	print("    centro da área queimada: %s (foco em 64, 64)" % centro)
	_checar(centro.x - 64.0 > 8.0, "vento de oeste empurra o fogo para leste")
	_checar(absf(centro.y - 64.0) < 4.0, "sem desvio para norte/sul")
	var a_favor := 0
	var contra := 0
	for i in sim.estado.size():
		if sim.estado[i] == SimulacaoFogo.Estado.INTACTA:
			continue
		var x := i % 128
		if x > 64:
			a_favor += 1
		elif x < 64:
			contra += 1
	print("    a favor do vento: %d, contra: %d" % [a_favor, contra])
	_checar(a_favor > contra * 3, "avança bem mais a favor do vento")


func _teste_barreiras() -> void:
	print("Barreiras:")
	for tipo in [Terreno.Tipo.ESTRADA, Terreno.Tipo.AGUA, Terreno.Tipo.ACEIRO]:
		var g := _grade_uniforme(Terreno.Tipo.PASTO)
		for y in g.altura:
			g.terreno[y * g.largura + 60] = tipo
		g.fixar_original()
		var sim := _rodar(g, 10.0, 40.0, 270.0, 3)
		var passou := 0
		for y in g.altura:
			for x in range(61, g.largura):
				if sim.estado[y * g.largura + x] != SimulacaoFogo.Estado.INTACTA:
					passou += 1
		_checar(passou == 0, "%s bloqueia o fogo (UR 10%%, vento 40 km/h)" % Terreno.nomes[tipo])
	# Aceiro desenhado na diagonal também precisa segurar.
	var g2 := _grade_uniforme(Terreno.Tipo.PASTO)
	var sim2 := SimulacaoFogo.new(_config, g2)
	for c in Ferramentas.linha_sem_furos(Vector2i(0, 95), Vector2i(95, 0)):
		sim2.abrir_aceiro(c)
	sim2.definir_clima(30.0, 10.0, 40.0, 315.0)
	sim2.iniciar_foco(Vector2i(10, 10))
	while sim2.ha_fogo():
		sim2.avancar()
	var do_outro_lado := 0
	for y in 96:
		for x in 96:
			if x + y > 96 and sim2.estado[y * 96 + x] != SimulacaoFogo.Estado.INTACTA:
				do_outro_lado += 1
	_checar(do_outro_lado == 0, "aceiro diagonal (sem furos) bloqueia o fogo")


func _teste_reproducao() -> void:
	print("Reprodução:")
	var a := _rodar(_grade_uniforme(Terreno.Tipo.CANA), 25.0, 20.0, 315.0, 99)
	var b := _rodar(_grade_uniforme(Terreno.Tipo.CANA), 25.0, 20.0, 315.0, 99)
	var c := _rodar(_grade_uniforme(Terreno.Tipo.CANA), 25.0, 20.0, 315.0, 98)
	_checar(a.estado == b.estado and a.passo == b.passo, "mesma semente = mesmo resultado")
	_checar(a.estado != c.estado, "semente diferente = resultado diferente")


func _teste_ferramentas() -> void:
	print("Ferramentas:")
	var g := _grade_uniforme(Terreno.Tipo.CANA)
	var sim := SimulacaoFogo.new(_config, g)
	var f := Ferramentas.new(_config, sim)
	sim.definir_clima(30.0, 20.0, 10.0, 90.0)
	sim.iniciar_foco(Vector2i(48, 48))
	for i in 6:
		sim.avancar()
	var antes := sim.ativos.size()
	_checar(f.usar_pipa(Vector2i(48, 48)), "caminhão-pipa funciona")
	_checar(sim.ativos.size() < antes, "a água apaga células queimando (%d -> %d)" % [antes, sim.ativos.size()])
	for i in _config.cargas_pipa:
		f.usar_pipa(Vector2i(10, 10))
	_checar(f.cargas_pipa == 0 and not f.usar_pipa(Vector2i(5, 5)), "caminhão-pipa tem cargas limitadas")
	var linha: Array[Vector2i] = []
	for x in 96:
		for y in 4:
			linha.append(Vector2i(x, 80 + y))
	var abertas := f.abrir_aceiro(linha)
	_checar(abertas == _config.orcamento / _config.custo_aceiro_celula and f.orcamento < _config.custo_aceiro_celula,
			"aceiro gasta orçamento e para quando ele acaba (%d células)" % abertas)
	_checar(f.chamar_brigada(Vector2i(60, 60)), "brigada pode ser chamada")
	_checar(not f.chamar_brigada(Vector2i(60, 60)), "brigada tem uso limitado")
	sim.iniciar_foco(Vector2i(60, 60))
	var chegou := [false]
	f.brigada_chegou.connect(func(_c: Vector2i, _n: int) -> void: chegou[0] = true)
	for i in _config.atraso_brigada:
		sim.avancar()
		f.processar_passo()
	_checar(chegou[0], "brigada chega depois de %d passos" % _config.atraso_brigada)


func _teste_mapa_exemplo() -> void:
	print("Mapa de exemplo:")
	var g := _carregar_exemplo()
	_checar(g != null, "carrega exemplo_terreno.png e exemplo_secura.png")
	if g == null:
		return
	var contagem := g.contar_originais()
	var partes := PackedStringArray()
	for t in Terreno.TIPOS_DO_MAPA:
		partes.append("%s=%d" % [Terreno.nomes[t], contagem[t]])
	print("    " + ", ".join(partes))
	_checar(contagem[Terreno.Tipo.SEDE] > 0 and contagem[Terreno.Tipo.AGUA] > 0, "tem sede e água")
	# Mapa gerado pelo script Python a partir do GeoTIFF sintético (se já foi gerado).
	var caminho := ProjectSettings.globalize_path("res://mapas/drone_teste_terreno.png")
	if FileAccess.file_exists(caminho):
		var img_t := Grade.carregar_imagem(caminho)
		var img_s := Grade.carregar_imagem(caminho.replace("terreno", "secura"))
		var g2 := Grade.de_imagens(img_t, img_s, _config.largura, _config.altura)
		_checar(g2.terreno == g.terreno, "mapa do pipeline Python (GeoTIFF sintético) carrega igual ao exemplo")


func _teste_gerador() -> void:
	print("Gerador procedural:")
	var g := GeradorMapa.gerar(128, 128, 5)
	var contagem := g.contar_originais()
	_checar(contagem[Terreno.Tipo.SEDE] > 0 and contagem[Terreno.Tipo.CANA] > 1000, "gera mapa com sede e cana")
	var g2 := GeradorMapa.gerar(128, 128, 5)
	_checar(g.terreno == g2.terreno, "mesma semente gera o mesmo mapa")


func _teste_demo() -> void:
	print("Modo demonstração:")
	var resultados: Array[PackedByteArray] = []
	for rodada in 2:
		var sim := SimulacaoFogo.new(_config, _carregar_exemplo())
		var f := Ferramentas.new(_config, sim)
		var roteiro := RoteiroDemo.new(_config)
		roteiro.preparar(sim)
		while true:
			roteiro.antes_do_passo(sim, f)
			if sim.terminou() or sim.passo > 600:
				break
			sim.avancar()
			f.processar_passo()
		resultados.append(sim.estado)
		if rodada == 0:
			var segundos := sim.passo / _config.passos_por_segundo_demo
			print("    terminou no passo %d (~%.0f s), %.1f ha queimados, pico de %d células em chamas" %
					[sim.passo, segundos, sim.area_queimada_ha(), sim.pico_ativos])
			print("    aceiro: %d células, pipa: %d, brigada: %d" % [f.celulas_aceiro, f.pipas_usadas, f.brigadas_usadas])
			for linha in Narrador.o_que_aconteceu(sim, f):
				print("    > " + linha)
			_checar(not sim.sede_atingida, "a sede é salva")
			_checar(segundos > 20.0 and segundos < 40.0, "dura entre 20 e 40 s")
			_salvar_imagem(sim, "demo_final.png")
	_checar(resultados[0] == resultados[1], "demonstração é reproduzível")


func _teste_missoes() -> void:
	print("Missões e pontuação")
	var fases := Campanha.fases()
	_checar(fases.size() == 6, "a campanha tem 6 fases")
	# Sem nenhuma ação, o jogador e a referência são o mesmo incêndio: nada foi evitado.
	var p := Partida.new(fases[2], _config)
	_checar(p.etapa == Partida.Etapa.PREPARACAO and p.centros_pendentes().size() == fases[2].candidatos,
			"começa na preparação, com as zonas de risco à mostra")
	_checar(not p.ferramentas.usar_pipa(Vector2i(60, 60)), "caminhão-pipa não funciona na preparação")
	p.iniciar_incendio()
	while not p.terminou() and p.sim.passo < 2000:
		p.passo()
	var r := p.resultado()
	_checar(r["evitada"] == 0.0 and r["estrelas"] <= 1, "sem ação: nada evitado (no máximo 1 estrela)")
	# Aceiro em volta de cada zona isola o fogo.
	var m := fases[0]
	var p2 := Partida.new(m, _config)
	_cercar_zonas(p2)
	p2.iniciar_incendio()
	_checar(p2.ferramentas.custo_aceiro() == 2 * _config.custo_aceiro_celula, "aceiro custa o dobro durante o incêndio")
	while not p2.terminou() and p2.sim.passo < 2000:
		p2.passo()
	var r2 := p2.resultado()
	_checar(r2["sede_salva"] and r2["estrelas"] == 3, "aceiros em volta das zonas de risco: 3 estrelas (evitou %d%%)" % roundi(100 * r2["evitada"]))
	# Foco surpresa (fora das zonas mostradas) e mudança de vento acontecem nos passos combinados.
	var m4 := fases[3]
	var p4 := Partida.new(m4, _config)
	var surpresa := p4.ignicoes[m4.candidatos]
	var fora := true
	for c in p4.centros_pendentes():
		fora = fora and Vector2(surpresa - c).length() > m4.raio_risco
	_checar(fora, "o foco surpresa fica fora das zonas mostradas")
	_cercar_zonas(p4)
	p4.iniciar_incendio()
	var mensagens := PackedStringArray()
	while not p4.terminou() and p4.sim.passo < 2000:
		mensagens.append_array(p4.passo())
	var ultimo: Vector2i = p4.sim.focos[p4.sim.focos.size() - 1]
	_checar(p4.sim.focos.size() == 2 and Vector2(ultimo - surpresa).length() < 2.0,
			"fase 4: o foco surpresa acende no lugar escondido (%d focos)" % p4.sim.focos.size())
	_checar(mensagens.size() == 2, "avisa o foco novo e a mudança de vento")
	# Cada tentativa sorteia o fogo de novo, dentro das mesmas zonas.
	var a := Partida.new(m4, _config, 1)
	var b := Partida.new(m4, _config, 1)
	_checar(a.ignicoes == b.ignicoes, "mesmo sorteio = mesmos focos")
	var zonas_iguais := true
	var diferentes := 0
	var primeiras := {}
	for v in range(1, 21):
		var t := Partida.new(m4, _config, v)
		var zonas := t.centros_pendentes()
		zonas.sort()
		var zonas_a := a.centros_pendentes()
		zonas_a.sort()
		zonas_iguais = zonas_iguais and zonas == zonas_a
		diferentes += 1 if t.ignicoes != a.ignicoes else 0
		primeiras[t.centros[0]] = true
	_checar(zonas_iguais, "as zonas de risco mostradas não mudam entre as tentativas")
	_checar(diferentes >= 18 and primeiras.size() == m4.candidatos,
			"em 20 tentativas o fogo começa em pontos diferentes e em todas as %d zonas" % m4.candidatos)


## Abre um anel de aceiro em volta de cada zona de risco mostrada.
func _cercar_zonas(p: Partida) -> void:
	for c in p.centros_pendentes():
		var raio := p.missao.raio_risco + 2
		var cantos: Array[Vector2i] = [c + Vector2i(-raio, -raio), c + Vector2i(raio, -raio), c + Vector2i(raio, raio), c + Vector2i(-raio, raio)]
		for k in 4:
			p.ferramentas.abrir_aceiro(Ferramentas.linha_sem_furos(cantos[k], cantos[(k + 1) % 4]))


func _teste_classificador() -> void:
	print("Classificação de imagens")
	var paleta := Grade.carregar_imagem(_config.mapa_terreno)
	_checar(ClassificadorFoto.eh_paleta(paleta), "reconhece um mapa na paleta do jogo")
	var foto := Image.load_from_file(ProjectSettings.globalize_path("res://dados/teste_sintetico_rgb.png"))
	if foto == null:
		return
	_checar(not ClassificadorFoto.eh_paleta(foto), "reconhece uma foto comum")
	var g := ClassificadorFoto.classificar(ClassificadorFoto.reduzir(foto, 128))
	var exemplo := _carregar_exemplo()
	var iguais := 0
	var vegetacao := 0
	for i in g.terreno.size():
		var t := exemplo.terreno[i]
		if t == Terreno.Tipo.CANA or t == Terreno.Tipo.PASTO or t == Terreno.Tipo.MATA:
			vegetacao += 1
			if g.terreno[i] == t:
				iguais += 1
	var acerto := 100.0 * iguais / vegetacao
	_checar(acerto > 70.0, "foto sintética: %d%% da vegetação classificada certo" % roundi(acerto))


func _teste_desempenho() -> void:
	print("Desempenho:")
	var sim := SimulacaoFogo.new(_config, _grade_uniforme(Terreno.Tipo.PASTO, 128))
	sim.definir_clima(35.0, 10.0, 20.0, 0.0)
	for c in [Vector2i(20, 20), Vector2i(100, 30), Vector2i(64, 100)]:
		sim.iniciar_foco(c)
	var r := Renderizador.new(sim)
	var inicio := Time.get_ticks_usec()
	var passos := 0
	while sim.ha_fogo() and passos < 150:
		sim.avancar()
		r.atualizar(0.1 * passos)
		passos += 1
	var ms := (Time.get_ticks_usec() - inicio) / 1000.0 / passos
	print("    %.2f ms por passo + desenho (pico de %d células em chamas)" % [ms, sim.pico_ativos])
	_checar(ms < 8.0, "passo + desenho cabem num quadro de 60 fps")


func _carregar_exemplo() -> Grade:
	var img_t := Grade.carregar_imagem(_config.mapa_terreno)
	var img_s := Grade.carregar_imagem(_config.mapa_secura)
	if img_t == null:
		return null
	return Grade.de_imagens(img_t, img_s, _config.largura, _config.altura)


func _salvar_imagem(sim: SimulacaoFogo, nome: String) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--imagens="):
			var r := Renderizador.new(sim)
			r.atualizar(0.0)
			var img := r.imagem_plana()
			img.resize(512, 512, Image.INTERPOLATE_NEAREST)
			img.save_png(arg.trim_prefix("--imagens=").path_join(nome))
