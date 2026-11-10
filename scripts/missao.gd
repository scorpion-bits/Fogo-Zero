class_name Missao
extends RefCounted
## Uma missão: mapa, clima, recursos e os eventos do incêndio (onde e quando o fogo começa,
## focos novos e mudança de vento). As fases da campanha estão em campanha.gd; o modo
## personalizado monta uma missão a partir das escolhas do jogador.
##
## Fluxo: na PREPARAÇÃO o jogador vê os pontos de risco (⚠) e só pode abrir aceiros. No
## INCÊNDIO o fogo começa sozinho perto de alguns desses pontos (o jogador não sabe quais).

enum Mapa { EXEMPLO, GERADO, GRADE }

var id := ""
var numero := 0
var nome := ""
var descricao := ""
## Causa mostrada ao jogador ("fagulhas da rodovia", "queima de lixo"...).
var causa := ""
var dica := ""

var mapa := Mapa.EXEMPLO
var semente_mapa := 0
## Para Mapa.GRADE: a grade pronta (imagem enviada ou mapa real). Nunca é modificada.
var grade_pronta: Grade
var metros_por_celula := 0.0
## Atribuição das fontes do mapa (mostrada no HUD), quando houver.
var creditos := ""

var semente := 1
var clima_real := false
var temperatura := 30.0
var umidade := 35.0
var vento_kmh := 12.0
var vento_direcao := 90.0
## Mudança de vento no meio do incêndio (passo < 0 = sem mudança).
var passo_mudanca_vento := -1
var nova_direcao := 0.0
var novo_vento_kmh := 0.0

## Zonas de risco mostradas na preparação.
var candidatos := 3
## Raio (células) de cada zona de risco: o fogo começa numa célula sorteada dentro dela.
var raio_risco := 9
## Quantos deles pegam fogo no início.
var focos_iniciais := 1
## Passos em que um novo foco surge num lugar inesperado (fora das zonas mostradas).
var focos_extras: Array[int] = []
## 0 = pontos de risco em qualquer direção; 1 = sempre do lado de onde vem o vento (mais difícil).
var ameaca := 0.5
## Distância (em células) dos pontos de risco até a sede.
var distancia_min := 26
var distancia_max := 56

var orcamento := 1500
var cargas_pipa := 3
var chamadas_brigada := 1
var atraso_brigada := 25
## Modo livre: sem preparação; o jogador acende o foco onde quiser (sem estrelas).
var foco_livre := false

## Cópia da configuração com os recursos desta missão.
func configurar(base: SimulacaoConfig) -> SimulacaoConfig:
	var c := base.duplicate() as SimulacaoConfig
	c.orcamento = orcamento
	c.cargas_pipa = cargas_pipa
	c.chamadas_brigada = chamadas_brigada
	c.atraso_brigada = atraso_brigada
	if metros_por_celula > 0.0:
		c.metros_por_celula = metros_por_celula
	return c


func criar_grade(config: SimulacaoConfig) -> Grade:
	match mapa:
		Mapa.GERADO:
			return GeradorMapa.gerar(config.largura, config.altura, semente_mapa)
		Mapa.GRADE:
			return grade_pronta.copiar()
	var img_t := Grade.carregar_imagem(config.mapa_terreno)
	return Grade.de_imagens(img_t, Grade.carregar_imagem(config.mapa_secura), config.largura, config.altura)


func ultimo_evento() -> int:
	var ultimo := maxi(passo_mudanca_vento, 0)
	for p in focos_extras:
		ultimo = maxi(ultimo, p)
	return ultimo


## Sorteia os centros das zonas de risco e, para cada um, a célula exata onde o fogo começa.
## Devolve {"centros": Array[Vector2i], "ignicoes": Array[Vector2i]}, na ordem em que acendem:
## primeiro as zonas mostradas (em ordem sorteada), depois os focos extras, que não são mostrados.
func sortear_focos(grade: Grade, vetor_vento: Vector2) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente * 7919 + 13
	var sede := centro_sede(grade)
	var opcoes: Array[Dictionary] = []
	for tentativa in 1500:
		# A zona inteira fica dentro do mapa.
		var c := Vector2i(rng.randi_range(raio_risco + 1, grade.largura - raio_risco - 2),
				rng.randi_range(raio_risco + 1, grade.altura - raio_risco - 2))
		var t := grade.terreno[grade.indice(c)]
		if t != Terreno.Tipo.CANA and t != Terreno.Tipo.PASTO:
			continue
		var d := Vector2(c - sede)
		if d.length() < distancia_min or d.length() > distancia_max:
			continue
		# Do lado de onde vem o vento, o fogo é empurrado para a sede.
		var contra := (-vetor_vento).dot(d.normalized()) if vetor_vento.length() > 0.01 else 0.0
		opcoes.append({"celula": c, "nota": ameaca * contra + (1.0 - ameaca) * rng.randf_range(-1.0, 1.0)})
	opcoes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["nota"] > b["nota"])

	var total := candidatos + focos_extras.size()
	var centros: Array[Vector2i] = []
	var distancia_entre := 2.4 * raio_risco
	while centros.size() < total and distancia_entre >= 4.0:
		for o in opcoes:
			if centros.size() >= total:
				break
			var c: Vector2i = o["celula"]
			var longe := true
			for outro in centros:
				if Vector2(c - outro).length() < distancia_entre:
					longe = false
					break
			if longe:
				centros.append(c)
		distancia_entre *= 0.7
	# Entre as zonas mostradas, a ordem é sorteada: o jogador não sabe quais vão pegar fogo.
	for i in range(mini(candidatos, centros.size()) - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := centros[i]
		centros[i] = centros[j]
		centros[j] = tmp
	var ignicoes: Array[Vector2i] = []
	for c in centros:
		var celula := c
		for tentativa in 40:
			var deslocamento := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, raio_risco - 1.0)
			var opcao := c + Vector2i(deslocamento.round())
			if grade.contem(opcao) and grade.terreno[grade.indice(opcao)] in [Terreno.Tipo.CANA, Terreno.Tipo.PASTO]:
				celula = opcao
				break
		ignicoes.append(celula)
	return {"centros": centros, "ignicoes": ignicoes}


## Centro da sede (média das células de construção) ou o centro do mapa, se não houver sede.
static func centro_sede(grade: Grade) -> Vector2i:
	var soma := Vector2.ZERO
	var n := 0
	for i in grade.largura * grade.altura:
		if grade.terreno[i] == Terreno.Tipo.SEDE:
			soma += Vector2(grade.posicao(i))
			n += 1
	if n == 0:
		@warning_ignore("integer_division")
		return Vector2i(grade.largura / 2, grade.altura / 2)
	return Vector2i((soma / n).round())


static func tem_sede(grade: Grade) -> bool:
	return Terreno.Tipo.SEDE in grade.terreno


## Acende o fogo na célula prevista ou, se ali não puder queimar (o jogador abriu um aceiro em
## cima), numa vizinha imediata. Retorna false se não houver onde acender.
static func acender(sim: SimulacaoFogo, celula: Vector2i) -> bool:
	if sim.iniciar_foco(celula):
		return true
	for k in 8:
		if sim.iniciar_foco(celula + Vector2i(SimulacaoFogo.DX[k], SimulacaoFogo.DY[k])):
			return true
	return false
