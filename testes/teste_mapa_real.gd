extends SceneTree
## Baixa um mapa real (satélite + OpenStreetMap) e salva a foto e o mapa do jogo, para conferir.
## Uso: godot --headless --path . -s testes/teste_mapa_real.gd -- --lat=-21.8602 --lon=-48.2558 --pasta=/tmp

var _pasta := "/tmp"
var _mapa: MapaReal


func _initialize() -> void:
	var lat := -21.8602
	var lon := -48.2558
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lat="):
			lat = arg.trim_prefix("--lat=").to_float()
		elif arg.begins_with("--lon="):
			lon = arg.trim_prefix("--lon=").to_float()
		elif arg.begins_with("--pasta="):
			_pasta = arg.trim_prefix("--pasta=")
	_mapa = MapaReal.new()
	root.add_child(_mapa)
	_mapa.andamento.connect(func(t: String) -> void: print(t))
	_mapa.falhou.connect(func(t: String) -> void:
		print("FALHOU: ", t)
		quit(1))
	_mapa.mapa_pronto.connect(_pronto)
	_mapa.baixar.call_deferred(lat, lon)


func _pronto(grade: Grade, foto: Image) -> void:
	foto.save_png(_pasta.path_join("mapa_real_foto.png"))
	var img := grade.para_imagem_terreno()
	img.resize(512, 512, Image.INTERPOLATE_NEAREST)
	img.save_png(_pasta.path_join("mapa_real_terreno.png"))
	var contagem := grade.contar_originais()
	for t in Terreno.TIPOS_DO_MAPA:
		print("  %-15s %5.1f%%" % [Terreno.nomes[t], 100.0 * contagem[t] / (grade.largura * grade.altura)])
	quit(0)
