class_name ClimaApi
extends Node
## Busca o clima atual de Araraquara na Open-Meteo (HTTPRequest, funciona também no export Web).
## Se a internet ou a API falharem, entrega os valores padrão do Resource ("modo offline").

signal leitura_recebida(leitura: LeituraClima)

var config: SimulacaoConfig
var _http: HTTPRequest
var _timer: Timer
var _ocupado := false


func iniciar(p_config: SimulacaoConfig) -> void:
	config = p_config
	_http = HTTPRequest.new()
	_http.timeout = config.tempo_limite_clima
	_http.request_completed.connect(_on_concluido)
	add_child(_http)
	_timer = Timer.new()
	_timer.wait_time = config.intervalo_clima
	_timer.timeout.connect(atualizar)
	add_child(_timer)
	_timer.start()
	atualizar()


func url() -> String:
	return ("https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f" +
			"&current=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m" +
			"&timezone=America/Sao_Paulo") % [config.latitude, config.longitude]


func atualizar() -> void:
	if _ocupado:
		return
	_ocupado = true
	var erro := _http.request(url())
	if erro != OK:
		_falhar("não foi possível fazer a requisição (erro %d)" % erro)


func _on_concluido(resultado: int, codigo: int, _cabecalhos: PackedStringArray, corpo: PackedByteArray) -> void:
	if resultado != HTTPRequest.RESULT_SUCCESS:
		_falhar("sem conexão com a Open-Meteo")
		return
	if codigo != 200:
		_falhar("a Open-Meteo respondeu com o código %d" % codigo)
		return
	var json: Variant = JSON.parse_string(corpo.get_string_from_utf8())
	if not json is Dictionary or not (json as Dictionary).has("current"):
		_falhar("resposta inesperada da Open-Meteo")
		return
	var atual: Dictionary = json["current"]
	var l := LeituraClima.new()
	l.temperatura = float(atual.get("temperature_2m", config.temperatura_padrao))
	l.umidade = float(atual.get("relative_humidity_2m", config.umidade_padrao))
	l.vento_kmh = float(atual.get("wind_speed_10m", config.vento_padrao_kmh))
	l.vento_direcao = float(atual.get("wind_direction_10m", config.direcao_vento_padrao))
	l.horario = formatar_horario(str(atual.get("time", "")))
	l.online = true
	l.mensagem = "Clima real de " + config.nome_local
	_ocupado = false
	leitura_recebida.emit(l)


func _falhar(motivo: String) -> void:
	_ocupado = false
	push_warning("Clima: " + motivo + ". Usando valores padrão.")
	leitura_recebida.emit(LeituraClima.offline(config, "Modo offline: " + motivo))


## "2026-11-09T22:15" -> "09/11/2026 22:15"
static func formatar_horario(iso: String) -> String:
	var partes := iso.split("T")
	if partes.size() != 2:
		return iso
	var data := partes[0].split("-")
	if data.size() != 3:
		return iso
	return "%s/%s/%s %s" % [data[2], data[1], data[0], partes[1]]
