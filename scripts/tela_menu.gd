class_name TelaMenu
extends Control
## Menu inicial: campanha, modo personalizado, demonstração e "Como jogar".

signal jogar_pedido
signal personalizado_pedido
signal demo_pedida

var _lbl_clima: Label
var _lbl_estrelas: Label
var _como_jogar: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ui.fundo(self)

	# Mapa de exemplo de fundo, escurecido, do lado direito.
	var textura := load("res://mapas/exemplo_terreno.png") as Texture2D
	if textura != null:
		var mapa := TextureRect.new()
		mapa.texture = textura
		mapa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mapa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mapa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		mapa.modulate = Color(1, 1, 1, 0.22)
		mapa.anchor_left = 0.45
		mapa.anchor_right = 1.0
		mapa.anchor_bottom = 1.0
		mapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mapa)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 14)
	coluna.anchor_top = 0.5
	coluna.anchor_bottom = 0.5
	coluna.offset_left = 140
	coluna.offset_right = 760
	coluna.offset_top = -380
	coluna.offset_bottom = 380
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(coluna)
	coluna.add_child(Ui.label("FOGO ZERO", 110, Ui.COR_DESTAQUE))
	coluna.add_child(Ui.label("Simulador de prevenção de queimadas", 34))
	coluna.add_child(Ui.label("Proteja a fazenda com o clima real de Araraquara. Planeje aceiros, combata o fogo e aprenda a evitar queimadas.", 22, Ui.COR_SUAVE))
	coluna.add_child(Ui.espaco(20))
	var jogar := Ui.botao_principal("Jogar", jogar_pedido.emit, 34)
	jogar.custom_minimum_size = Vector2(0, 84)
	coluna.add_child(jogar)
	_lbl_estrelas = Ui.label("", 18, Ui.COR_SUAVE)
	coluna.add_child(_lbl_estrelas)
	for item: Array in [
		["Modo personalizado (seu mapa, mapa real ou aleatório)", personalizado_pedido.emit],
		["Demonstração (30 segundos)", demo_pedida.emit],
		["Como jogar", _mostrar_como_jogar],
	]:
		var b := Ui.botao(item[0], item[1], 24)
		b.custom_minimum_size = Vector2(0, 62)
		coluna.add_child(b)
	coluna.add_child(Ui.espaco(16))
	_lbl_clima = Ui.label("Buscando o clima de Araraquara…", 20, Ui.COR_SUAVE)
	coluna.add_child(_lbl_clima)

	var rodape := Ui.label("Protótipo (prova de conceito) · Scorpion Bits · Araraquara-SP. Modelo simplificado para educação e treinamento: não é uma ferramenta operacional de combate a incêndio. Em caso de fogo, ligue 193 ou 199.", 16, Ui.COR_SUAVE)
	rodape.anchor_top = 1.0
	rodape.anchor_bottom = 1.0
	rodape.anchor_right = 1.0
	rodape.offset_left = 140
	rodape.offset_right = -140
	rodape.offset_top = -70
	rodape.offset_bottom = -24
	add_child(rodape)

	_montar_como_jogar()


func atualizar(total_estrelas: int, maximo: int) -> void:
	_lbl_estrelas.text = "Campanha: %d de %d estrelas" % [total_estrelas, maximo] if total_estrelas > 0 else "Campanha com 6 fases, da mais fácil à mais difícil."


func mostrar_clima(leitura: LeituraClima, risco: String) -> void:
	if leitura.online:
		_lbl_clima.text = "Agora em Araraquara: %d °C · umidade %d%% · vento %d km/h · risco de fogo %s" % [
			roundi(leitura.temperatura), roundi(leitura.umidade), roundi(leitura.vento_kmh), risco.to_lower()]
	else:
		_lbl_clima.text = "Sem conexão com o serviço de clima (o jogo funciona normalmente)."


func _montar_como_jogar() -> void:
	_como_jogar = Control.new()
	_como_jogar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_como_jogar)
	var escuro := ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.7)
	escuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_como_jogar.add_child(escuro)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_como_jogar.add_child(centro)
	var caixa := Ui.painel(centro, 10)
	caixa.custom_minimum_size = Vector2(1100, 0)
	caixa.add_child(Ui.label("COMO JOGAR", 36, Ui.COR_DESTAQUE))
	var passos := [
		["1. Prepare", "Antes do fogo, o mapa mostra as zonas de risco (círculos com !). O fogo vai começar em alguma delas, você não sabe qual. Arraste no mapa para abrir aceiros (faixas sem vegetação) entre o risco e a sede."],
		["2. Combata", "Clique em \"Começar o incêndio\". Use o caminhão-pipa (molha uma área e apaga o fogo) e chame a brigada pelo 193 (ela demora a chegar). Aceiro aberto durante o incêndio custa o dobro."],
		["3. Fique atento", "O vento empurra o fogo e pode mudar de direção. Em algumas fases surgem focos novos em lugares inesperados."],
		["4. Resultado", "O jogo compara com o mesmo incêndio sem nenhuma ação. 1 estrela: a sede foi salva. 2 estrelas: você evitou metade da área. 3 estrelas: evitou 80%."],
		["Atalhos", "1 a 4 escolhem a ferramenta · Espaço pausa · R recomeça · Esc volta ao menu."],
	]
	for p: Array in passos:
		caixa.add_child(Ui.label(p[0], 24, Ui.COR_DESTAQUE))
		caixa.add_child(Ui.label(p[1], 21))
	var fechar := Ui.botao_principal("Entendi", func() -> void: _como_jogar.hide(), 22)
	fechar.size_flags_horizontal = Control.SIZE_SHRINK_END
	caixa.add_child(fechar)
	_como_jogar.hide()


func _mostrar_como_jogar() -> void:
	_como_jogar.show()
