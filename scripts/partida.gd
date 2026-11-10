class_name Partida
extends RefCounted
## Uma partida de uma missão: a simulação do jogador, os recursos, os eventos do incêndio e a
## "simulação de referência", que roda em paralelo sem nenhuma ação do jogador para medir quanto
## ele evitou. É lógica pura (sem nós), usada pela cena principal e pelos testes.

enum Etapa { PREPARACAO, INCENDIO, FIM }

## Limite de segurança de passos da simulação de referência.
const MAX_PASSOS_REFERENCIA := 3000

var missao: Missao
var config: SimulacaoConfig
var grade: Grade
var sim: SimulacaoFogo
var ferramentas: Ferramentas
var etapa := Etapa.PREPARACAO
## Centros dos pontos de risco e as células onde o fogo começa, na ordem de ignição.
var centros: Array[Vector2i] = []
var ignicoes: Array[Vector2i] = []
## Quantos pontos de risco já pegaram fogo (ou deveriam ter pegado).
var acesos := 0

var referencia: SimulacaoFogo
var referencia_pronta := false
var _acesos_referencia := 0


func _init(p_missao: Missao, config_base: SimulacaoConfig) -> void:
	missao = p_missao
	config = missao.configurar(config_base)
	grade = missao.criar_grade(config)
	sim = SimulacaoFogo.new(config, grade)
	sim.reiniciar(missao.semente)
	ferramentas = Ferramentas.new(config, sim)
	sim.definir_clima(missao.temperatura, missao.umidade, missao.vento_kmh, missao.vento_direcao)
	if missao.foco_livre:
		etapa = Etapa.INCENDIO
	else:
		var sorteio := missao.sortear_focos(grade, sim.vetor_vento())
		centros.assign(sorteio["centros"])
		ignicoes.assign(sorteio["ignicoes"])
	ferramentas.em_preparacao = etapa == Etapa.PREPARACAO


## O clima só pode mudar antes do fogo começar (depois ele fica fixo, para a comparação ser justa).
func definir_clima(temperatura: float, umidade: float, vento: float, direcao: float) -> void:
	if etapa == Etapa.PREPARACAO or (missao.foco_livre and sim.focos.is_empty()):
		sim.definir_clima(temperatura, umidade, vento, direcao)


## Fim da preparação: o fogo começa nos primeiros pontos de risco.
func iniciar_incendio() -> void:
	if etapa != Etapa.PREPARACAO:
		return
	etapa = Etapa.INCENDIO
	ferramentas.em_preparacao = false
	ferramentas.multiplicador_aceiro = 2
	referencia = SimulacaoFogo.new(config, grade.copiar_original())
	referencia.reiniciar(missao.semente)
	referencia.definir_clima(sim.temperatura, sim.umidade, sim.vento_kmh, sim.vento_direcao)
	acesos = _acender_proximos(sim, 0, missao.focos_iniciais)
	_acesos_referencia = _acender_proximos(referencia, 0, missao.focos_iniciais)


## Avança um passo. Devolve mensagens de eventos para o jogador ("Novo foco!", "O vento virou!").
func passo() -> PackedStringArray:
	var mensagens := PackedStringArray()
	if etapa != Etapa.INCENDIO:
		return mensagens
	if not missao.foco_livre:
		var antes := acesos
		acesos = _eventos(sim, acesos)
		if acesos > antes:
			mensagens.append("Novo foco de incêndio num lugar inesperado!")
		if sim.passo == missao.passo_mudanca_vento:
			mensagens.append("O vento mudou: agora vem do %s a %d km/h." % [
				Narrador.nome_direcao_graus(missao.nova_direcao), roundi(missao.novo_vento_kmh)])
	sim.avancar()
	ferramentas.processar_passo()
	if terminou():
		etapa = Etapa.FIM
	return mensagens


func terminou() -> bool:
	if etapa == Etapa.FIM:
		return true
	if etapa != Etapa.INCENDIO:
		return false
	if missao.foco_livre:
		return sim.terminou()
	return sim.sede_atingida or (sim.ativos.is_empty() and sim.passo > missao.ultimo_evento())


## Há algo acontecendo (fogo ou eventos pendentes)? Sem isso, a cena não precisa avançar passos.
func ativa() -> bool:
	return etapa == Etapa.INCENDIO and (sim.ha_fogo() or not missao.foco_livre)


## Avança a simulação de referência em até `max_passos` passos. Ela não para na sede:
## mede o estrago completo de não fazer nada.
func avancar_referencia(max_passos: int) -> void:
	if referencia == null or referencia_pronta:
		return
	for i in max_passos:
		if (referencia.ativos.is_empty() and referencia.passo > missao.ultimo_evento()) \
				or referencia.passo >= MAX_PASSOS_REFERENCIA:
			referencia_pronta = true
			return
		_acesos_referencia = _eventos(referencia, _acesos_referencia)
		referencia.avancar()


## Zonas de risco mostradas que ainda não pegaram fogo (desenhadas no mapa).
func centros_pendentes() -> Array[Vector2i]:
	var lista: Array[Vector2i] = []
	for i in range(acesos, mini(missao.candidatos, centros.size())):
		lista.append(centros[i])
	return lista


func resultado() -> Dictionary:
	avancar_referencia(MAX_PASSOS_REFERENCIA)
	var dados := Narrador.resumo(sim, ferramentas)
	var ref_queimadas := referencia.total_queimadas if referencia != null else -1
	var ref_sede := referencia.sede_atingida if referencia != null else false
	dados.merge(Narrador.avaliar(sim, ferramentas, ref_queimadas, ref_sede, Missao.tem_sede(grade)), true)
	return dados


func _acender_proximos(s: SimulacaoFogo, de: int, quantos: int) -> int:
	var ate := mini(de + quantos, ignicoes.size())
	for i in range(de, ate):
		Missao.acender(s, ignicoes[i])
	return ate


func _eventos(s: SimulacaoFogo, ja_acesos: int) -> int:
	if s.passo == missao.passo_mudanca_vento:
		s.definir_clima(s.temperatura, s.umidade, missao.novo_vento_kmh, missao.nova_direcao)
	for p in missao.focos_extras:
		if s.passo == p:
			ja_acesos = _acender_proximos(s, ja_acesos, 1)
	return ja_acesos
