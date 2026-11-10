extends SceneTree
## Mostra, para cada fase, o incêndio de referência (sem nenhuma ação do jogador) e o resultado
## de uma estratégia simples de prevenção, em vários sorteios (cada tentativa do jogador usa um).
## Uso: godot --headless --path . -s testes/calibrar_fases.gd -- --sorteios=40

const ATRASO_REACAO := 6

var _sorteios := 40


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sorteios="):
			_sorteios = int(arg.trim_prefix("--sorteios="))
	var config: SimulacaoConfig = load("res://recursos/simulacao_config.tres")
	print("Em %d sorteios por fase: incêndio sem ação (mín · média · máx) e a estratégia do anel de aceiro." % _sorteios)
	for m in Campanha.fases():
		var ha := PackedFloat32Array()
		var ameacam := 0
		var estrelas := PackedInt32Array([0, 0, 0, 0])
		var soma_estrelas := 0
		for v in range(1, _sorteios + 1):
			var r := _jogar(m, config, v)
			ha.append(r["ref_ha"])
			ameacam += 1 if r["ref_sede"] else 0
			estrelas[r["estrelas"]] += 1
			soma_estrelas += r["estrelas"]
		var media := 0.0
		for h in ha:
			media += h / ha.size()
		ha.sort()
		print("Fase %d %-16s | sem ação: %5.1f · %5.1f · %5.1f ha, ameaça a sede em %3d%% | anel: sede salva em %3d%%, média %.1f estrelas (0★ %d · 1★ %d · 2★ %d · 3★ %d)" % [
			m.numero, m.nome, ha[0], media, ha[ha.size() - 1], roundi(100.0 * ameacam / _sorteios), roundi(100.0 * (_sorteios - estrelas[0]) / _sorteios),
			float(soma_estrelas) / _sorteios, estrelas[0], estrelas[1], estrelas[2], estrelas[3]])
	quit()


## Estratégia de teste: um anel de aceiro em volta de cada zona de risco, enquanto houver dinheiro,
## começando pelas mais próximas da sede, e o caminhão-pipa em cima de cada foco surpresa.
func _jogar(m: Missao, config: SimulacaoConfig, variacao: int) -> Dictionary:
	var p := Partida.new(m, config, variacao)
	# O jogador não sabe a ordem em que as zonas acendem: cerca primeiro as mais próximas da sede.
	var sede := Missao.centro_sede(p.grade)
	var zonas := p.centros_pendentes()
	zonas.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a - sede).length_squared() < Vector2(b - sede).length_squared())
	for c in zonas:
		var r := m.raio_risco + 2
		var pontos: Array[Vector2i] = [c + Vector2i(-r, -r), c + Vector2i(r, -r), c + Vector2i(r, r), c + Vector2i(-r, r)]
		for k in 4:
			p.ferramentas.abrir_aceiro(Ferramentas.linha_sem_furos(pontos[k], pontos[(k + 1) % 4]))
	p.iniciar_incendio()
	while not p.terminou() and p.sim.passo < 2000:
		p.passo()
		# Reage ao foco surpresa com o caminhão-pipa, um segundo (6 passos) depois de ele aparecer.
		for k in m.focos_extras.size():
			if p.sim.passo == m.focos_extras[k] + ATRASO_REACAO and m.candidatos + k < p.ignicoes.size():
				p.ferramentas.usar_pipa(p.ignicoes[m.candidatos + k])
	var r := p.resultado()
	r["ref_ha"] = p.referencia.area_queimada_ha()
	r["ref_sede"] = p.referencia.sede_atingida
	return r
