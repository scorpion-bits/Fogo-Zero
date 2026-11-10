extends SceneTree
## Grava o modo demonstração quadro a quadro numa SubViewport de 1920×1080 (fora da tela, então o
## tamanho da janela e o mouse não interferem). Use pelo script ferramentas/gravar_demo.sh.
##     godot --path . --fixed-fps 60 -s testes/gravar_demo.gd -- --demo --quadros=/pasta

const QUADROS_NO_RESULTADO := 300

var _tela: SubViewport
var _principal: Node
var _resultado: Control
var _pasta := ""
var _quadro := 0
var _quadros_resultado := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quadros="):
			_pasta = arg.trim_prefix("--quadros=")
	if _pasta.is_empty():
		push_error("Informe --quadros=/pasta")
		quit(1)
		return
	_tela = SubViewport.new()
	_tela.size = Vector2i(1920, 1080)
	_tela.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_tela.gui_disable_input = true
	root.add_child(_tela)
	_principal = (load("res://cenas/principal.tscn") as PackedScene).instantiate()
	_tela.add_child(_principal)
	_resultado = _principal.get_node("Resultado")


func _process(_delta: float) -> bool:
	_quadro += 1
	if _quadro < 3:
		return false
	var img := _tela.get_texture().get_image()
	img.save_jpg(_pasta.path_join("q%05d.jpg" % (_quadro - 3)), 0.92)
	if _resultado.visible:
		_quadros_resultado += 1
		if _quadros_resultado >= QUADROS_NO_RESULTADO:
			print("Gravação terminou com %d quadros." % (_quadro - 2))
			return true
	return _quadro > 60 * 90
