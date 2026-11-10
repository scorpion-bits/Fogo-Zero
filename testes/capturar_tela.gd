extends SceneTree
## Gera a captura de tela do jogo em andamento (cenário manual de dia crítico, foco, aceiro e pipa).
## Renderiza numa SubViewport de 1920×1080, então o tamanho da janela não importa.
## Precisa de janela (não use --headless):
##     godot --path . -s testes/capturar_tela.gd -- --saida=capturas/01_jogo.png

var _principal: Node
var _tela: SubViewport
var _quadro := 0
var _saida := "capturas/01_jogo.png"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
	_tela = SubViewport.new()
	_tela.size = Vector2i(1920, 1080)
	_tela.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_tela)
	_principal = (load("res://cenas/principal.tscn") as PackedScene).instantiate()
	_tela.add_child(_principal)


func _process(_delta: float) -> bool:
	_quadro += 1
	if _quadro == 5:
		var hud: Hud = _principal.get_node("HUD")
		hud.call("_aplicar_dia_critico")
		_principal.call("_on_clique", Vector2i(40, 26))
		var f: Ferramentas = _principal.get("ferramentas")
		f.abrir_aceiro(Ferramentas.linha_sem_furos(Vector2i(79, 107), Vector2i(79, 70)))
		f.abrir_aceiro(Ferramentas.linha_sem_furos(Vector2i(79, 70), Vector2i(105, 70)))
		_principal.call("_escolher_ferramenta", Ferramentas.Tipo.PIPA)
	if _quadro == 300:
		var f: Ferramentas = _principal.get("ferramentas")
		f.usar_pipa(Vector2i(74, 74))
	if _quadro == 420:
		var img := _tela.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://" + _saida) if not _saida.begins_with("/") else _saida)
		print("Captura salva em ", _saida)
		return true
	return false
