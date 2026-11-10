class_name Risco
## Índice de risco de fogo SIMPLIFICADO e NÃO OFICIAL, feito só para o jogo.
## Combina umidade, temperatura e vento num valor de 0 a 1 (pesos no Resource de configuração).

enum Classe { BAIXO, MEDIO, ALTO, CRITICO }

static var nomes: PackedStringArray = ["Baixo", "Médio", "Alto", "Crítico"]
static var cores: Array[Color] = [
	Color("#4CAF50"), Color("#E6C229"), Color("#F28C28"), Color("#D7263D"),
]


static func indice(config: SimulacaoConfig, temperatura: float, umidade: float, vento_kmh: float) -> float:
	var u := clampf(1.0 - umidade / 100.0, 0.0, 1.0)
	var t := clampf((temperatura - config.risco_temp_min) / (config.risco_temp_max - config.risco_temp_min), 0.0, 1.0)
	var v := clampf(vento_kmh / config.risco_vento_max, 0.0, 1.0)
	return config.risco_peso_umidade * u + config.risco_peso_temperatura * t + config.risco_peso_vento * v


static func classe(config: SimulacaoConfig, valor: float) -> Classe:
	if valor >= config.risco_limiar_critico:
		return Classe.CRITICO
	if valor >= config.risco_limiar_alto:
		return Classe.ALTO
	if valor >= config.risco_limiar_medio:
		return Classe.MEDIO
	return Classe.BAIXO
