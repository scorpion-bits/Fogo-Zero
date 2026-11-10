class_name TelaFases
extends Control
## Mapa de fases da campanha: um caminho com as fases, estrelas conquistadas e cadeados.
## Ao escolher uma fase, o painel da direita mostra o briefing e o botão Jogar.

signal fase_escolhida(missao: Missao)
signal voltar_pedido

## Posição de cada fase no caminho, em fração da área do mapa.
const POSICOES: Array[Vector2] = [
	Vector2(0.10, 0.78), Vector2(0.28, 0.50), Vector2(0.47, 0.72),
	Vector2(0.62, 0.40), Vector2(0.80, 0.62), Vector2(0.90, 0.24),
]
const TAMANHO_NO := 124.0

var _fases: Array[Missao] = []
var _area: Control
var _briefing: VBoxContainer
var _selecionada := 0
var _lbl_total: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ui.fundo(self)
	_fases = Campanha.fases()

	var topo := HBoxContainer.new()
	topo.anchor_right = 1.0
	topo.offset_left = 48
	topo.offset_right = -48
	topo.offset_top = 32
	topo.add_theme_constant_override("separation", 24)
	add_child(topo)
	topo.add_child(Ui.botao("‹ Menu", voltar_pedido.emit, 22))
	var titulo := Ui.label("ESCOLHA A FASE", 40, Ui.COR_DESTAQUE)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(titulo)
	_lbl_total = Ui.label("", 22, Ui.COR_SUAVE)
	_lbl_total.autowrap_mode = TextServer.AUTOWRAP_OFF
	topo.add_child(_lbl_total)

	_area = Control.new()
	_area.anchor_bottom = 1.0
	_area.anchor_right = 1.0
	_area.offset_left = 48
	_area.offset_top = 120
	_area.offset_right = -680
	_area.offset_bottom = -48
	_area.draw.connect(_desenhar_caminho)
	_area.resized.connect(_posicionar_nos)
	add_child(_area)

	var lado := PanelContainer.new()
	lado.anchor_left = 1.0
	lado.anchor_right = 1.0
	lado.anchor_bottom = 1.0
	lado.offset_left = -640
	lado.offset_right = -48
	lado.offset_top = 120
	lado.offset_bottom = -48
	add_child(lado)
	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lado.add_child(rolagem)
	_briefing = VBoxContainer.new()
	_briefing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_briefing.add_theme_constant_override("separation", 10)
	rolagem.add_child(_briefing)


## Recria os nós com o progresso atual e seleciona a próxima fase a jogar.
func atualizar() -> void:
	for filho in _area.get_children():
		filho.queue_free()
	# Seleciona a primeira fase aberta ainda sem estrelas (ou a última aberta).
	var proxima := -1
	var ultima_aberta := 0
	for i in _fases.size():
		var aberta := Progresso.desbloqueada(_fases, i)
		if aberta:
			ultima_aberta = i
			if proxima < 0 and Progresso.estrelas(_fases[i].id) == 0:
				proxima = i
		var no := VBoxContainer.new()
		no.alignment = BoxContainer.ALIGNMENT_CENTER
		no.add_theme_constant_override("separation", 4)
		var b := Ui.botao(str(i + 1) if aberta else "?", _selecionar.bind(i), 48)
		b.custom_minimum_size = Vector2(TAMANHO_NO, TAMANHO_NO)
		b.disabled = not aberta
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var estilo := StyleBoxFlat.new()
		estilo.set_corner_radius_all(int(TAMANHO_NO / 2))
		estilo.bg_color = Color(0.2, 0.18, 0.157) if aberta else Color(0.13, 0.12, 0.11)
		estilo.border_color = Ui.COR_DESTAQUE if aberta else Color(0.25, 0.22, 0.2)
		estilo.set_border_width_all(4)
		b.add_theme_stylebox_override("normal", estilo)
		b.add_theme_stylebox_override("disabled", estilo)
		var hover := estilo.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.3, 0.24, 0.18)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		no.add_child(b)
		var nome := Ui.label(_fases[i].nome if aberta else "Bloqueada", 20, Ui.COR_TEXTO if aberta else Ui.COR_SUAVE)
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nome.custom_minimum_size = Vector2(220, 0)
		no.add_child(nome)
		var e := Estrelas.criar(Progresso.estrelas(_fases[i].id), 26.0)
		e.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		no.add_child(e)
		_area.add_child(no)
	_lbl_total.text = "%d de %d estrelas" % [Progresso.total_estrelas(_fases), _fases.size() * 3]
	_posicionar_nos.call_deferred()
	_selecionar(proxima if proxima >= 0 else ultima_aberta)


func _posicionar_nos() -> void:
	var nos := _area.get_children()
	for i in nos.size():
		var no := nos[i] as Control
		no.reset_size()
		var centro := POSICOES[i] * _area.size
		no.position = centro - Vector2(no.size.x / 2.0, TAMANHO_NO / 2.0)
	_area.queue_redraw()


func _desenhar_caminho() -> void:
	for i in POSICOES.size() - 1:
		var a := POSICOES[i] * _area.size
		var b := POSICOES[i + 1] * _area.size
		var aberta := Progresso.desbloqueada(_fases, i + 1)
		var cor := Ui.COR_DESTAQUE.darkened(0.2) if aberta else Color(0.25, 0.22, 0.2)
		# Linha tracejada entre as fases.
		var comprimento := a.distance_to(b)
		var n := int(comprimento / 26.0)
		for k in n:
			if k % 2 == 0:
				_tracejar(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), cor)


func _tracejar(de: Vector2, para: Vector2, cor: Color) -> void:
	_area.draw_line(de, para, cor, 6.0, true)


func _selecionar(i: int) -> void:
	_selecionada = i
	for filho in _briefing.get_children():
		filho.queue_free()
	var m := _fases[i]
	_briefing.add_child(Ui.label("FASE %d" % m.numero, 20, Ui.COR_DESTAQUE))
	_briefing.add_child(Ui.label(m.nome, 40))
	_briefing.add_child(Ui.label(m.descricao, 21))
	Ui.titulo_secao(_briefing, "CONDIÇÕES")
	_briefing.add_child(Ui.label("Clima: %d °C · umidade %d%% · vento %d km/h vindo do %s" % [
		roundi(m.temperatura), roundi(m.umidade), roundi(m.vento_kmh), Narrador.nome_direcao_graus(m.vento_direcao)], 20))
	_briefing.add_child(Ui.label("Causa provável: " + m.causa, 20))
	_briefing.add_child(Ui.label("Recursos: R$ %s · %d cargas do caminhão-pipa · %d chamada%s da brigada (chega em %d passos)" % [
		Hud.formatar_inteiro(m.orcamento), m.cargas_pipa, m.chamadas_brigada,
		"" if m.chamadas_brigada == 1 else "s", m.atraso_brigada], 20))
	var desafios := PackedStringArray()
	desafios.append("%d zona%s de risco" % [m.candidatos, "" if m.candidatos == 1 else "s"])
	desafios.append("%d foco%s no início" % [m.focos_iniciais, "" if m.focos_iniciais == 1 else "s"])
	if not m.focos_extras.is_empty():
		desafios.append("foco surpresa durante o incêndio")
	if m.passo_mudanca_vento >= 0:
		desafios.append("o vento muda de direção")
	_briefing.add_child(Ui.label("Desafios: " + ", ".join(desafios) + ".", 20))
	Ui.titulo_secao(_briefing, "OBJETIVO")
	_briefing.add_child(Ui.label("1 estrela: salvar a sede · 2 estrelas: evitar 50% da área que queimaria · 3 estrelas: evitar 80%", 20))
	if Progresso.jogada(m.id):
		var linha := HBoxContainer.new()
		linha.add_child(Ui.rotulo("Seu melhor:", 20, Ui.COR_SUAVE))
		linha.add_child(Estrelas.criar(Progresso.estrelas(m.id), 24.0))
		linha.add_child(Ui.rotulo("%s pontos" % Hud.formatar_inteiro(Progresso.recorde(m.id)), 20, Ui.COR_SUAVE))
		_briefing.add_child(linha)
	_briefing.add_child(Ui.label("Dica: " + m.dica, 19, Ui.COR_SUAVE))
	_briefing.add_child(Ui.espaco(8))
	var jogar := Ui.botao_principal("Jogar fase %d" % m.numero, fase_escolhida.emit.bind(m), 28)
	jogar.custom_minimum_size = Vector2(0, 76)
	_briefing.add_child(jogar)
