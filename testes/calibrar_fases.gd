extends SceneTree
## Mostra, para cada fase, o incêndio de referência (sem nenhuma ação do jogador) e o resultado
## de uma estratégia simples de prevenção. Uso: godot --headless --path . -s testes/calibrar_fases.gd


func _init() -> void:
	var config: SimulacaoConfig = load("res://recursos/simulacao_config.tres")
	for m in Campanha.fases():
		var nada := _jogar(m, config, false)
		var plano := _jogar(m, config, true)
		print("Fase %d %-18s | sem ação: %5.1f ha, sede %s, %3d passos | anel de aceiro: %5.1f ha, sede %s, %d estrelas, %d pts, R$ %d" % [
			m.numero, m.nome, nada["ref_ha"], "ATINGIDA" if nada["ref_sede"] else "salva",
			nada["passos"], plano["area_ha"], "ATINGIDA" if not plano["sede_salva"] else "salva",
			plano["estrelas"], plano["pontuacao"], plano["gasto"]])
	quit()


## Estratégia de teste: um anel de aceiro em volta de cada ponto de risco, enquanto houver dinheiro.
func _jogar(m: Missao, config: SimulacaoConfig, com_plano: bool) -> Dictionary:
	var p := Partida.new(m, config)
	if com_plano:
		for c in p.centros_pendentes():
			var r := m.raio_risco + 2
			var pontos: Array[Vector2i] = [c + Vector2i(-r, -r), c + Vector2i(r, -r), c + Vector2i(r, r), c + Vector2i(-r, r)]
			for k in 4:
				p.ferramentas.abrir_aceiro(Ferramentas.linha_sem_furos(pontos[k], pontos[(k + 1) % 4]))
	p.iniciar_incendio()
	while not p.terminou() and p.sim.passo < 2000:
		p.passo()
	var r := p.resultado()
	if com_plano:
		print("   focos: ", p.sim.focos, "  extras ocultos em ", p.ignicoes.slice(m.candidatos))
	r["passos"] = p.referencia.passo
	r["ref_ha"] = p.referencia.area_queimada_ha()
	r["ref_sede"] = p.referencia.sede_atingida
	r["gasto"] = p.ferramentas.gasto_aceiro
	return r
