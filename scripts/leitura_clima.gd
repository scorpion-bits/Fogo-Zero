class_name LeituraClima
extends RefCounted
## Uma leitura de clima (da Open-Meteo ou os valores padrão do modo offline).

var temperatura := 0.0
var umidade := 0.0
var vento_kmh := 0.0
## De onde o vento vem, em graus (0 = norte, 90 = leste).
var vento_direcao := 0.0
## Horário da leitura, já formatado (ex.: "09/11/2026 22:15").
var horario := ""
var online := false
var mensagem := ""


static func offline(config: SimulacaoConfig, p_mensagem: String) -> LeituraClima:
	var l := LeituraClima.new()
	l.temperatura = config.temperatura_padrao
	l.umidade = config.umidade_padrao
	l.vento_kmh = config.vento_padrao_kmh
	l.vento_direcao = config.direcao_vento_padrao
	l.mensagem = p_mensagem
	return l
