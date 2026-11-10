class_name GeradorMapa
## Gerador procedural simples de fazendas para teste: vegetação por ruído, um córrego com mata
## ciliar, uma estrada, a sede com um piquete de pasto e uma camada de secura.
## A mesma semente sempre gera o mesmo mapa.


static func gerar(largura: int, altura: int, semente: int) -> Grade:
	var g := Grade.new(largura, altura)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var ruido := FastNoiseLite.new()
	ruido.seed = semente
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.025
	var ruido_secura := FastNoiseLite.new()
	ruido_secura.seed = semente + 1
	ruido_secura.frequency = 0.05

	# Vegetação.
	for y in altura:
		for x in largura:
			var n := ruido.get_noise_2d(x, y)
			var tipo := Terreno.Tipo.CANA
			if n < -0.3:
				tipo = Terreno.Tipo.MATA
			elif n > 0.3:
				tipo = Terreno.Tipo.PASTO
			g.terreno[y * largura + x] = tipo

	# Córrego de norte a sul, sem furos diagonais, com mata ciliar.
	var x_rio := rng.randi_range(int(largura * 0.15), int(largura * 0.85))
	var anterior := x_rio
	var margem := rng.randi_range(2, 4)
	for y in altura:
		if rng.randf() < 0.5:
			x_rio = clampi(x_rio + rng.randi_range(-1, 1), 4, largura - 6)
		for x in range(mini(anterior, x_rio) - margem, maxi(anterior, x_rio) + 2 + margem):
			if x >= 0 and x < largura:
				g.terreno[y * largura + x] = Terreno.Tipo.MATA
		for x in range(mini(anterior, x_rio), maxi(anterior, x_rio) + 2):
			g.terreno[y * largura + x] = Terreno.Tipo.AGUA
		anterior = x_rio

	# Estrada de oeste a leste, com 2 células de largura.
	var y_estrada := rng.randi_range(int(altura * 0.65), int(altura * 0.85))
	var y_anterior := y_estrada
	for x in largura:
		if rng.randf() < 0.15:
			y_estrada = clampi(y_estrada + rng.randi_range(-1, 1), 20, altura - 4)
		for y in range(mini(y_anterior, y_estrada), maxi(y_anterior, y_estrada) + 2):
			g.terreno[y * largura + x] = Terreno.Tipo.ESTRADA
		y_anterior = y_estrada

	# Sede com piquete de pasto e acesso até a estrada.
	var sede := Vector2i(rng.randi_range(int(largura * 0.2), int(largura * 0.8)),
			rng.randi_range(int(altura * 0.25), int(altura * 0.55)))
	for y in range(sede.y - 8, sede.y + 9):
		for x in range(sede.x - 8, sede.x + 9):
			var c := Vector2i(x, y)
			if g.contem(c) and c.distance_to(sede) <= 8.0:
				g.terreno[g.indice(c)] = Terreno.Tipo.PASTO
	for y in range(sede.y + 3, altura):
		var i := y * largura + sede.x
		if g.terreno[i] == Terreno.Tipo.ESTRADA:
			break
		g.terreno[i] = Terreno.Tipo.ESTRADA
	for y in range(sede.y - 2, sede.y + 2):
		for x in range(sede.x - 3, sede.x + 3):
			g.terreno[y * largura + x] = Terreno.Tipo.SEDE

	# Secura: ruído, pasto mais seco, mata e água mais úmidas.
	for i in largura * altura:
		var p := g.posicao(i)
		var s := 135.0 + 75.0 * ruido_secura.get_noise_2d(p.x, p.y)
		match g.terreno[i]:
			Terreno.Tipo.PASTO: s += 35.0
			Terreno.Tipo.MATA: s -= 35.0
			Terreno.Tipo.AGUA: s = 0.0
		g.secura[i] = clampi(roundi(s), 0, 255)

	g.fixar_original()
	return g
