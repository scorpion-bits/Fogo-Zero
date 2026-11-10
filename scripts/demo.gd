class_name RoteiroDemo
extends RefCounted
## Roteiro do modo demonstração (vídeo do pitch), feito para o mapa de exemplo.
## Tudo acontece em passos fixos da simulação, com semente e clima fixos (do Resource de
## configuração), então o vídeo sai sempre igual.

const FOCO := Vector2i(44, 28)
## O aceiro é aberto aos poucos, de ponto a ponto, a partir de PASSO_ACEIRO.
const ACEIRO: Array[Vector2i] = [Vector2i(79, 107), Vector2i(79, 69), Vector2i(127, 69)]
const PASSO_ACEIRO := 6
const ACEIRO_POR_PASSO := 4
const PASSO_PIPA := 50
const PIPAS: Array[Vector2i] = [Vector2i(75, 73), Vector2i(74, 85)]
const PASSO_BRIGADA := 55
const BRIGADA := Vector2i(101, 64)

var config: SimulacaoConfig
var legenda := ""
var _aceiro: Array[Vector2i] = []
var _aceiro_aberto := 0


func _init(p_config: SimulacaoConfig) -> void:
	config = p_config
	for k in range(1, ACEIRO.size()):
		var trecho := Ferramentas.linha_sem_furos(ACEIRO[k - 1], ACEIRO[k])
		if k > 1:
			trecho.remove_at(0)
		_aceiro.append_array(trecho)


## Clima de "dia crítico" e semente fixa.
func preparar(sim: SimulacaoFogo) -> void:
	sim.definir_clima(config.temperatura_demo, config.umidade_demo, config.vento_demo_kmh,
			config.direcao_vento_demo)
	sim.reiniciar(config.semente_demo)


## Chame antes de cada passo da simulação (inclusive antes do primeiro).
func antes_do_passo(sim: SimulacaoFogo, f: Ferramentas) -> void:
	var p := sim.passo
	if p == 0:
		f.iniciar_foco(FOCO)
		legenda = "Dia crítico: umidade de %d%% e vento de %d km/h vindo do %s. Um foco começa no canavial." % [
			roundi(sim.umidade), roundi(sim.vento_kmh), Narrador.nome_direcao_graus(sim.vento_direcao)]
	if p >= PASSO_ACEIRO and _aceiro_aberto < _aceiro.size():
		if p == PASSO_ACEIRO:
			legenda = "A equipe abre um aceiro para proteger a sede."
		var fim := mini(_aceiro_aberto + ACEIRO_POR_PASSO, _aceiro.size())
		f.abrir_aceiro(_aceiro.slice(_aceiro_aberto, fim))
		_aceiro_aberto = fim
	if p == PASSO_BRIGADA:
		f.chamar_brigada(BRIGADA)
		legenda = "Brigada acionada pelo 193: ela chega em %d passos." % config.atraso_brigada
	if p == PASSO_BRIGADA + config.atraso_brigada:
		legenda = "A brigada chega e corta a frente leste, entre a estrada e o aceiro."
	if p == PASSO_PIPA:
		for c in PIPAS:
			f.usar_pipa(c)
		legenda = "O caminhão-pipa molha a frente que avança para o aceiro."


## Legenda final, quando a rodada termina.
func ao_terminar(sim: SimulacaoFogo) -> void:
	if sim.sede_atingida:
		legenda = "O fogo chegou à sede."
	else:
		legenda = "Sede protegida! O fogo parou na estrada, no aceiro, na água e na ação da brigada."
