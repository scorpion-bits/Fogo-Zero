extends SceneTree
## Salva os sons gerados por scripts/sons.gd como WAV, para ouvir e conferir.
## Uso: godot --headless --path . -s testes/salvar_sons.gd -- --pasta=/tmp/sons

var _sons: Sons
var _pasta := "/tmp"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pasta="):
			_pasta = arg.trim_prefix("--pasta=")
	_sons = Sons.new()
	root.add_child(_sons)


func _process(_delta: float) -> bool:
	var lista: Dictionary = _sons.get("_sons")
	for nome: String in lista:
		(lista[nome] as AudioStreamWAV).save_to_wav(_pasta.path_join(nome + ".wav"))
	var fogo: AudioStreamPlayer = _sons.get("_fogo")
	var vento: AudioStreamPlayer = _sons.get("_vento")
	(fogo.stream as AudioStreamWAV).save_to_wav(_pasta.path_join("laco_fogo.wav"))
	(vento.stream as AudioStreamWAV).save_to_wav(_pasta.path_join("laco_vento.wav"))
	print("Sons salvos em ", _pasta)
	return true
