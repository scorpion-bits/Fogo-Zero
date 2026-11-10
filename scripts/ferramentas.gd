class_name Ferramentas
extends RefCounted
## Recursos do jogador e as ações que ele aplica na simulação:
## iniciar foco, abrir aceiro, caminhão-pipa e chamar a brigada (193).

enum Tipo { FOCO, ACEIRO, PIPA, BRIGADA }

signal brigada_chegou(centro: Vector2i, apagadas: int)
signal pipa_usada(centro: Vector2i, apagadas: int)
signal brigada_chamada(centro: Vector2i)

## Uma chamada à brigada que ainda não chegou.
class Chamada:
	var centro: Vector2i
	var passo_chegada: int

var config: SimulacaoConfig
var sim: SimulacaoFogo

var orcamento := 0
var cargas_pipa := 0
var chamadas_brigada := 0
var celulas_aceiro := 0
var pipas_usadas := 0
var brigadas_usadas := 0
var apagadas_pipa := 0
var apagadas_brigada := 0
var chamadas_pendentes: Array[Chamada] = []
var gasto_aceiro := 0
## Na preparação (antes do fogo) só dá para abrir aceiro: caminhão e brigada ficam de prontidão.
var em_preparacao := false
## Aceiro aberto durante o incêndio custa mais (é trabalho de emergência).
var multiplicador_aceiro := 1


func _init(p_config: SimulacaoConfig, p_sim: SimulacaoFogo) -> void:
	config = p_config
	sim = p_sim
	reiniciar()


func reiniciar() -> void:
	orcamento = config.orcamento
	cargas_pipa = config.cargas_pipa
	chamadas_brigada = config.chamadas_brigada
	celulas_aceiro = 0
	pipas_usadas = 0
	brigadas_usadas = 0
	apagadas_pipa = 0
	apagadas_brigada = 0
	gasto_aceiro = 0
	multiplicador_aceiro = 1
	chamadas_pendentes.clear()


func iniciar_foco(celula: Vector2i) -> bool:
	return sim.iniciar_foco(celula)


## Abre aceiro nas células da lista enquanto houver orçamento. Retorna quantas viraram aceiro.
func abrir_aceiro(celulas: Array[Vector2i]) -> int:
	var abertas := 0
	var custo := custo_aceiro()
	for c in celulas:
		if orcamento < custo:
			break
		if sim.abrir_aceiro(c):
			orcamento -= custo
			gasto_aceiro += custo
			celulas_aceiro += 1
			abertas += 1
	return abertas


func custo_aceiro() -> int:
	return config.custo_aceiro_celula * multiplicador_aceiro


func usar_pipa(celula: Vector2i) -> bool:
	if em_preparacao or cargas_pipa <= 0 or not sim.grade.contem(celula):
		return false
	cargas_pipa -= 1
	pipas_usadas += 1
	var n := sim.molhar_area(celula, config.raio_pipa, config.passos_molhada)
	apagadas_pipa += n
	pipa_usada.emit(celula, n)
	return true


func chamar_brigada(celula: Vector2i) -> bool:
	if em_preparacao or chamadas_brigada <= 0 or not sim.grade.contem(celula):
		return false
	chamadas_brigada -= 1
	brigadas_usadas += 1
	var chamada := Chamada.new()
	chamada.centro = celula
	chamada.passo_chegada = sim.passo + config.atraso_brigada
	chamadas_pendentes.append(chamada)
	brigada_chamada.emit(celula)
	return true


## Chame depois de cada passo da simulação: faz a brigada agir quando ela chega.
func processar_passo() -> void:
	for chamada in chamadas_pendentes.duplicate():
		if sim.passo >= chamada.passo_chegada:
			chamadas_pendentes.erase(chamada)
			var n := sim.molhar_area(chamada.centro, config.raio_brigada, config.passos_molhada)
			apagadas_brigada += n
			brigada_chegou.emit(chamada.centro, n)


func pode_usar(tipo: Tipo) -> bool:
	match tipo:
		Tipo.ACEIRO: return orcamento >= custo_aceiro()
		Tipo.PIPA: return cargas_pipa > 0 and not em_preparacao
		Tipo.BRIGADA: return chamadas_brigada > 0 and not em_preparacao
	return true


## Linha entre duas células sem "furos" diagonais (4-conectada). Uma linha só com passos
## diagonais deixaria o fogo passar, porque a vizinhança é de 8 células.
static func linha_sem_furos(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var pontos: Array[Vector2i] = [a]
	var atual := a
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var erro := dx + dy
	while atual != b:
		var e2 := 2 * erro
		var passo_x := e2 >= dy
		var passo_y := e2 <= dx
		if passo_x:
			erro += dy
			atual.x += sx
		if passo_y:
			erro += dx
			if passo_x:
				# Passo diagonal: inclui a célula do canto para fechar o furo.
				pontos.append(atual)
			atual.y += sy
		pontos.append(atual)
	return pontos
