extends SceneTree
## Gera as capturas de tela das telas do jogo (menu, fases, preparação, incêndio, resultado e
## modo personalizado). Renderiza numa SubViewport de 1920×1080, então o tamanho da janela não
## importa. Precisa de janela (não use --headless):
##     godot --path . -s testes/capturar_tela.gd -- --pasta=capturas

var _principal: Node
var _tela: SubViewport
var _quadro := 0
var _pasta := "capturas"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pasta="):
			_pasta = arg.trim_prefix("--pasta=")
	Progresso.apagar()
	Progresso.registrar("fase1", 3, 1707)
	Progresso.registrar("fase2", 2, 1210)
	_tela = SubViewport.new()
	_tela.size = Vector2i(1920, 1080)
	_tela.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_tela)
	_principal = (load("res://cenas/principal.tscn") as PackedScene).instantiate()
	_tela.add_child(_principal)


func _process(_delta: float) -> bool:
	_quadro += 1
	match _quadro:
		20: _salvar("01_menu.png")
		21: _principal.call("mostrar_fases")
		40: _salvar("02_fases.png")
		41:
			_principal.call("iniciar_missao", Campanha.fases()[2])
			var f: Ferramentas = _principal.get("ferramentas")
			f.abrir_aceiro(Ferramentas.linha_sem_furos(Vector2i(60, 40), Vector2i(60, 75)))
			f.abrir_aceiro(Ferramentas.linha_sem_furos(Vector2i(60, 40), Vector2i(105, 40)))
		70: _salvar("03_preparacao.png")
		71: _principal.call("_comecar_incendio")
		260:
			var f: Ferramentas = _principal.get("ferramentas")
			var partida: Partida = _principal.get("partida")
			if not partida.sim.ativos.is_empty():
				f.usar_pipa(partida.sim.grade.posicao(partida.sim.ativos[0]))
		300: _salvar("04_incendio.png")
		301: _principal.set("velocidade", 4.0)
		1500:
			Progresso.apagar()
			print("A partida não terminou a tempo.")
			return true
	if _quadro > 301 and _quadro < 1500 and (_principal.get_node("Resultado") as Control).visible:
		_salvar("05_resultado.png")
		_principal.call("_mostrar_tela", 2)
		_quadro = 1600
	if _quadro == 1620:
		_salvar("06_personalizado.png")
		Progresso.apagar()
		return true
	return false


func _salvar(nome: String) -> void:
	var caminho := _pasta.path_join(nome)
	if not caminho.begins_with("/"):
		caminho = ProjectSettings.globalize_path("res://" + caminho)
	_tela.get_texture().get_image().save_png(caminho)
	print("Captura salva em ", caminho)
