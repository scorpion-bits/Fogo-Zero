extends SceneTree
## Ferramenta de ajuste: salva quadros do modo demonstração a cada 15 passos.
##     godot --headless --path . -s testes/quadros_demo.gd -- --imagens=/pasta

func _init() -> void:
	var config := load("res://recursos/simulacao_config.tres") as SimulacaoConfig
	var pasta := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--imagens="):
			pasta = arg.trim_prefix("--imagens=")
	var grade := Grade.de_imagens(Grade.carregar_imagem(config.mapa_terreno),
			Grade.carregar_imagem(config.mapa_secura), config.largura, config.altura)
	var sim := SimulacaoFogo.new(config, grade)
	var f := Ferramentas.new(config, sim)
	var roteiro := RoteiroDemo.new(config)
	roteiro.preparar(sim)
	var r := Renderizador.new(sim)
	while true:
		roteiro.antes_do_passo(sim, f)
		if sim.passo % 15 == 0 or sim.terminou():
			r.atualizar(0.0)
			var img := r.imagem.duplicate() as Image
			img.resize(384, 384, Image.INTERPOLATE_NEAREST)
			img.save_png(pasta.path_join("q_%03d.png" % sim.passo))
		if sim.terminou() or sim.passo > 600:
			break
		sim.avancar()
		f.processar_passo()
	print("fim no passo ", sim.passo, " sede atingida: ", sim.sede_atingida)
	quit()
