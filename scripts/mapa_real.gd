class_name MapaReal
extends Node
## Monta um mapa do jogo de um lugar real:
##   1. foto de satélite (Esri World Imagery), classificada por cor (ClassificadorFoto);
##   2. por cima, estradas, rios, lagos e construções do OpenStreetMap (Overpass API).
## Também busca lugares pelo nome (Nominatim). Tudo por HTTPRequest, então funciona no Web.
##
## Licenças: a imagem da Esri exige atribuição e, para uso comercial, uma conta/chave da Esri.
## Os dados do OpenStreetMap são ODbL (© colaboradores do OpenStreetMap).

signal lugar_encontrado(latitude: float, longitude: float, nome: String)
signal mapa_pronto(grade: Grade, foto: Image)
signal andamento(texto: String)
signal falhou(texto: String)

const URL_FOTO := "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/export?bbox=%f,%f,%f,%f&bboxSR=4326&imageSR=4326&size=%d,%d&format=jpg&f=image"
const URL_OVERPASS := "https://overpass-api.de/api/interpreter"
const URL_BUSCA := "https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=br&q=%s"
const CREDITOS := "Imagem: Esri, Maxar, Earthstar Geographics · Estradas, rios e construções: © colaboradores do OpenStreetMap"
const LADO_FOTO := 512
## Identificação do jogo nos pedidos ao OpenStreetMap (as regras de uso pedem isso).
const CABECALHO_APP := "User-Agent: FogoZero/0.2 (+https://scorpionbits.com/Fogo-Zero/)"
## Vias que viram estrada (barreira) no jogo, e as que têm 2 células de largura.
const VIAS := ["motorway", "trunk", "primary", "secondary", "tertiary", "unclassified", "residential",
		"service", "track", "motorway_link", "trunk_link", "primary_link", "secondary_link", "tertiary_link"]
const VIAS_LARGAS := ["motorway", "trunk", "primary", "secondary"]

var lado_celulas := 128
var metros_por_celula := 10.0

var _http_foto: HTTPRequest
var _http_osm: HTTPRequest
var _http_busca: HTTPRequest
var _caixa := Rect2()
var _foto: Image
var _osm: Variant = null
var _pedido_osm := PackedStringArray()
var _corpo_osm := ""
var _tentativas_osm := 0
var _ocupado := false


func _ready() -> void:
	_http_foto = _novo_http(25.0, _on_foto)
	_http_osm = _novo_http(40.0, _on_osm)
	_http_busca = _novo_http(15.0, _on_busca)


func ocupado() -> bool:
	return _ocupado


func buscar_lugar(texto: String) -> void:
	if texto.strip_edges().is_empty():
		return
	_http_busca.cancel_request()
	var erro := _http_busca.request(URL_BUSCA % texto.uri_encode(), [CABECALHO_APP])
	if erro != OK:
		falhou.emit("Não foi possível buscar o lugar (erro %d)." % erro)


## Baixa o quadrado de `lado_celulas × metros_por_celula` metros centrado no ponto.
func baixar(latitude: float, longitude: float) -> void:
	if _ocupado:
		return
	_ocupado = true
	var lado_m := lado_celulas * metros_por_celula
	var dlat := lado_m / 111320.0
	var dlon := lado_m / (111320.0 * cos(deg_to_rad(latitude)))
	# x = longitude (oeste → leste), y = latitude (sul → norte).
	_caixa = Rect2(longitude - dlon / 2.0, latitude - dlat / 2.0, dlon, dlat)
	_foto = null
	_osm = null
	andamento.emit("Baixando a foto de satélite e os dados do OpenStreetMap…")
	var url := URL_FOTO % [_caixa.position.x, _caixa.position.y, _caixa.end.x, _caixa.end.y, LADO_FOTO, LADO_FOTO]
	var erro := _http_foto.request(url)
	if erro != OK:
		_falhar("Não foi possível pedir a foto de satélite (erro %d)." % erro)
		return
	# A foto e o OpenStreetMap são baixados ao mesmo tempo; o mapa é montado quando os dois chegam.
	var b := "%f,%f,%f,%f" % [_caixa.position.y, _caixa.position.x, _caixa.end.y, _caixa.end.x]
	var consulta := "[out:json][timeout:30];(way[highway](%s);way[waterway](%s);way[natural=water](%s);way[landuse=reservoir](%s);way[building](%s););out geom;" % [b, b, b, b, b]
	var cabecalhos := ["Content-Type: application/x-www-form-urlencoded"]
	if not OS.has_feature("web"):
		# No navegador o User-Agent é o do próprio navegador (e cabeçalhos extras exigiriam CORS).
		cabecalhos.append_array(["Accept: application/json", CABECALHO_APP])
	_pedido_osm = PackedStringArray(cabecalhos)
	_corpo_osm = "data=" + consulta.uri_encode()
	_tentativas_osm = 0
	_pedir_osm()


func _pedir_osm() -> void:
	_tentativas_osm += 1
	if _http_osm.request(URL_OVERPASS, _pedido_osm, HTTPClient.METHOD_POST, _corpo_osm) != OK:
		_osm = {}
		_tentar_montar()


func _on_foto(resultado: int, codigo: int, _cab: PackedStringArray, corpo: PackedByteArray) -> void:
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo != 200:
		_http_osm.cancel_request()
		_falhar("Sem resposta do serviço de imagens de satélite (código %d)." % codigo)
		return
	var foto := Image.new()
	if foto.load_jpg_from_buffer(corpo) != OK and foto.load_png_from_buffer(corpo) != OK:
		_http_osm.cancel_request()
		_falhar("A imagem de satélite veio num formato inesperado.")
		return
	_foto = foto
	if _osm == null:
		andamento.emit("Foto recebida. Esperando estradas, rios e construções do OpenStreetMap…")
	_tentar_montar()


func _on_osm(resultado: int, codigo: int, _cab: PackedStringArray, corpo: PackedByteArray) -> void:
	var dados: Variant = null
	if resultado == HTTPRequest.RESULT_SUCCESS and codigo == 200:
		dados = JSON.parse_string(corpo.get_string_from_utf8())
	if not dados is Dictionary and _tentativas_osm < 2 and _ocupado:
		# O servidor público às vezes recusa por excesso de pedidos: tenta mais uma vez.
		andamento.emit("O OpenStreetMap está ocupado, tentando de novo…")
		get_tree().create_timer(3.0).timeout.connect(_pedir_osm)
		return
	if not dados is Dictionary:
		andamento.emit("O OpenStreetMap não respondeu (código %d): usando só a foto de satélite." % codigo)
		dados = {}
	_osm = dados
	_tentar_montar()


func _tentar_montar() -> void:
	if _ocupado and _foto != null and _osm != null:
		_montar(_osm)


func _montar(osm: Dictionary) -> void:
	var grade := ClassificadorFoto.classificar(ClassificadorFoto.reduzir(_foto, lado_celulas))
	var contagem := {"vias": 0, "rios": 0, "construcoes": 0}
	for e: Dictionary in osm.get("elements", []):
		var tags: Dictionary = e.get("tags", {})
		var pontos := _pontos(e.get("geometry", []))
		if pontos.size() < 2:
			continue
		if tags.has("building"):
			_preencher(grade, pontos, Terreno.Tipo.SEDE)
			contagem["construcoes"] += 1
		elif tags.get("natural", "") == "water" or tags.get("landuse", "") == "reservoir":
			_preencher(grade, pontos, Terreno.Tipo.AGUA)
			contagem["rios"] += 1
		elif tags.has("waterway"):
			_tracar(grade, pontos, Terreno.Tipo.AGUA, 2 if tags["waterway"] == "river" else 1)
			contagem["rios"] += 1
		elif tags.get("highway", "") in VIAS:
			_tracar(grade, pontos, Terreno.Tipo.ESTRADA, 2 if tags["highway"] in VIAS_LARGAS else 1)
			contagem["vias"] += 1
	for i in grade.largura * grade.altura:
		if grade.terreno[i] == Terreno.Tipo.AGUA:
			grade.secura[i] = 0
	grade.fixar_original()
	_ocupado = false
	andamento.emit("Mapa pronto: %d vias, %d rios ou lagos e %d construções do OpenStreetMap." % [
		contagem["vias"], contagem["rios"], contagem["construcoes"]])
	mapa_pronto.emit(grade, _foto)


## Converte a geometria (lat/lon) do Overpass em posições na grade (podem cair fora dela).
func _pontos(geometria: Array) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	for p: Dictionary in geometria:
		var x := (float(p["lon"]) - _caixa.position.x) / _caixa.size.x * lado_celulas
		var y := (_caixa.end.y - float(p["lat"])) / _caixa.size.y * lado_celulas
		pontos.append(Vector2(x, y))
	return pontos


func _tracar(grade: Grade, pontos: PackedVector2Array, tipo: int, largura: int) -> void:
	for k in range(1, pontos.size()):
		var a := Vector2i(pontos[k - 1].floor())
		var b := Vector2i(pontos[k].floor())
		if a.distance_to(b) > lado_celulas * 3:
			continue
		for c in Ferramentas.linha_sem_furos(a, b):
			for dy in largura:
				for dx in largura:
					var celula := c + Vector2i(dx, dy)
					if grade.contem(celula):
						grade.terreno[grade.indice(celula)] = tipo


func _preencher(grade: Grade, pontos: PackedVector2Array, tipo: int) -> void:
	var caixa := Rect2(pontos[0], Vector2.ZERO)
	for p in pontos:
		caixa = caixa.expand(p)
	var x0 := maxi(floori(caixa.position.x), 0)
	var y0 := maxi(floori(caixa.position.y), 0)
	var x1 := mini(ceili(caixa.end.x), lado_celulas - 1)
	var y1 := mini(ceili(caixa.end.y), lado_celulas - 1)
	var marcou := false
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pontos):
				grade.terreno[y * lado_celulas + x] = tipo
				marcou = true
	# Construções menores que uma célula ainda aparecem.
	if not marcou:
		var c := Vector2i(caixa.get_center().floor())
		if grade.contem(c):
			grade.terreno[grade.indice(c)] = tipo


func _on_busca(resultado: int, codigo: int, _cab: PackedStringArray, corpo: PackedByteArray) -> void:
	var dados: Variant = null
	if resultado == HTTPRequest.RESULT_SUCCESS and codigo == 200:
		dados = JSON.parse_string(corpo.get_string_from_utf8())
	if not dados is Array or (dados as Array).is_empty():
		falhou.emit("Lugar não encontrado. Tente outro nome ou digite as coordenadas.")
		return
	var lugar: Dictionary = dados[0]
	lugar_encontrado.emit(float(lugar["lat"]), float(lugar["lon"]), str(lugar.get("display_name", "")))


func _falhar(texto: String) -> void:
	_ocupado = false
	falhou.emit(texto)


func _novo_http(tempo_limite: float, ao_concluir: Callable) -> HTTPRequest:
	var h := HTTPRequest.new()
	h.timeout = tempo_limite
	h.request_completed.connect(ao_concluir)
	add_child(h)
	return h
