class_name Hud
extends Control
## Interface do jogo: clima e risco (painel esquerdo), ferramentas, recursos e simulação (painel
## direito), legenda no topo e o aviso de uso educacional embaixo. Os controles são montados por
## código, a partir do Resource de configuração.

signal ferramenta_escolhida(tipo: Ferramentas.Tipo)
signal velocidade_escolhida(valor: float)
signal reiniciar_pedido
signal comecar_pedido
signal som_pedido
signal menu_pedido
signal sair_demo_pedido
signal atualizar_clima_pedido
signal clima_manual_alterado(ativo: bool, temperatura: float, umidade: float, vento: float, direcao: float)

const LARGURA_PAINEL := 400.0
const MARGEM := 16.0
const COR_DESTAQUE := Color("#F28C28")
const COR_SUAVE := Color(0.64, 0.6, 0.55)
const COR_ESCURA := Color(0.09, 0.08, 0.07)
const AVISO := "Modelo simplificado para educação e treinamento. Não é uma ferramenta operacional de combate a incêndio."

var config: SimulacaoConfig

var _seta: SetaVento
var _lbl_temperatura: Label
var _lbl_umidade: Label
var _lbl_vento: Label
var _lbl_horario: Label
var _lbl_status_clima: Label
var _lbl_risco: Label
var _estilo_risco: StyleBoxFlat
var _lbl_focos: Label
var _btn_atualizar: Button
var _secao_manual: Control
var _chk_manual: CheckButton
var _sliders: Dictionary[String, HSlider] = {}
var _valores_sliders: Dictionary[String, Label] = {}
var _botoes_ferramenta: Array[Button] = []
var _botoes_velocidade: Array[Button] = []
var _velocidades: Array[float] = [0.0, 1.0, 2.0, 4.0]
var _secao_controles: Array[Control] = []
var _rolagens: Array[ScrollContainer] = []
var _lbl_orcamento: Label
var _lbl_pipa: Label
var _lbl_brigada: Label
var _lbl_status: Label
var _btn_sair_demo: Button
var _lbl_missao: Label
var _lbl_creditos: Label
var _secao_missao: VBoxContainer
var _lbl_etapa: Label
var _lbl_instrucao: Label
var _btn_comecar: Button
var _btn_som: Button
var _lbl_modo_demo: Label
var _painel_legenda: PanelContainer
var _lbl_legenda: Label
var _legenda_fixa := ""
var _tempo_mensagem := 0.0
var _ignorar_sliders := false


func _process(delta: float) -> void:
	if _tempo_mensagem > 0.0:
		_tempo_mensagem -= delta
		if _tempo_mensagem <= 0.0:
			_mostrar_texto_legenda(_legenda_fixa)


func configurar(p_config: SimulacaoConfig) -> void:
	config = p_config
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_montar_esquerda()
	_montar_direita()
	_montar_topo_e_rodape()


# --- Atualizações vindas da cena principal -------------------------------------------------

## `leitura_real` diz se os valores mostrados são os da leitura da API (e não manual/demonstração).
func mostrar_clima(leitura: LeituraClima, leitura_real: bool, temperatura: float, umidade: float,
		vento: float, direcao: float, modo: String, cor_modo: Color) -> void:
	_seta.direcao = direcao
	_seta.velocidade = vento
	_lbl_temperatura.text = "%d °C" % roundi(temperatura)
	_lbl_umidade.text = "Umidade: %d%%" % roundi(umidade)
	_lbl_vento.text = "Vento: %d km/h\nvindo do %s" % [roundi(vento), Narrador.nome_direcao_graus(direcao)]
	_lbl_horario.text = "Leitura: %s (Brasília)" % leitura.horario
	_lbl_horario.visible = leitura_real
	_lbl_status_clima.text = modo
	_lbl_status_clima.add_theme_color_override("font_color", cor_modo)
	var indice := Risco.indice(config, temperatura, umidade, vento)
	var classe := Risco.classe(config, indice)
	_lbl_risco.text = "RISCO DE FOGO: %s" % Risco.nomes[classe].to_upper()
	_estilo_risco.bg_color = Risco.cores[classe]


func mostrar_recursos(f: Ferramentas) -> void:
	_lbl_orcamento.text = "Orçamento: R$ %s" % formatar_inteiro(f.orcamento)
	_lbl_pipa.text = "Cargas do caminhão-pipa: %d de %d" % [f.cargas_pipa, f.config.cargas_pipa]
	var brigada := "Brigada (193): %d de %d" % [f.chamadas_brigada, f.config.chamadas_brigada]
	for chamada in f.chamadas_pendentes:
		brigada += "\n  a caminho: chega em %d passos" % (chamada.passo_chegada - f.sim.passo)
	_lbl_brigada.text = brigada
	_botoes_ferramenta[Ferramentas.Tipo.ACEIRO].text = "2  Aceiro (R$ %d por célula)" % f.custo_aceiro()
	_botoes_ferramenta[Ferramentas.Tipo.PIPA].text = "3  Caminhão-pipa (%d)" % f.cargas_pipa
	_botoes_ferramenta[Ferramentas.Tipo.BRIGADA].text = "4  Chamar brigada 193 (%d)" % f.chamadas_brigada
	for tipo in [Ferramentas.Tipo.ACEIRO, Ferramentas.Tipo.PIPA, Ferramentas.Tipo.BRIGADA]:
		_botoes_ferramenta[tipo].disabled = not f.pode_usar(tipo)


func mostrar_status(sim: SimulacaoFogo) -> void:
	_lbl_status.text = "Passo %d · em chamas: %d\nÁrea queimada: %s ha (%s%% da vegetação)" % [
		sim.passo, sim.ativos.size(), Narrador.formatar_ha(sim.area_queimada_ha()),
		("%.1f" % (100.0 * sim.fracao_vegetacao_queimada())).replace(".", ",")]


func mostrar_focos(texto: String) -> void:
	_lbl_focos.text = texto
	_lbl_focos.visible = not texto.is_empty()


func definir_ferramenta(tipo: Ferramentas.Tipo) -> void:
	for i in _botoes_ferramenta.size():
		_botoes_ferramenta[i].set_pressed_no_signal(i == tipo)


func definir_velocidade(valor: float) -> void:
	for i in _botoes_velocidade.size():
		_botoes_velocidade[i].set_pressed_no_signal(is_equal_approx(_velocidades[i], valor))


func definir_som(ligado: bool) -> void:
	_btn_som.text = "Som: ligado (M)" if ligado else "Som: desligado (M)"


## Ajusta o HUD para a missão: título, ferramenta de foco só no modo livre, cenário manual idem.
func modo_missao(m: Missao) -> void:
	_lbl_missao.text = "FASE %d · %s" % [m.numero, m.nome.to_upper()] if m.numero > 0 else "MODO PERSONALIZADO"
	_lbl_missao.visible = true
	_botoes_ferramenta[Ferramentas.Tipo.FOCO].visible = m.foco_livre
	_secao_manual.visible = m.foco_livre
	_btn_atualizar.visible = m.clima_real
	_lbl_creditos.text = m.creditos
	_lbl_creditos.visible = not m.creditos.is_empty()


func definir_etapa(etapa: Partida.Etapa, foco_livre: bool) -> void:
	# O botão continua no lugar (desativado) para o painel não pular de posição.
	_btn_comecar.visible = not foco_livre
	_btn_comecar.disabled = etapa != Partida.Etapa.PREPARACAO
	_btn_comecar.text = "Começar o incêndio" if etapa == Partida.Etapa.PREPARACAO else "Incêndio em andamento"
	if foco_livre:
		_lbl_etapa.text = "MODO LIVRE"
		_lbl_etapa.add_theme_color_override("font_color", Color("#7FC8F8"))
		_lbl_instrucao.text = "Escolha a ferramenta 1 e clique no mapa para acender um foco. Sem estrelas neste modo."
	elif etapa == Partida.Etapa.PREPARACAO:
		_lbl_etapa.text = "PREPARAÇÃO"
		_lbl_etapa.add_theme_color_override("font_color", Color("#7FC8F8"))
		_lbl_instrucao.text = "Arraste no mapa para abrir aceiros. O fogo vai começar numa das zonas de risco (!), mas você não sabe qual."
	else:
		_lbl_etapa.text = "INCÊNDIO!"
		_lbl_etapa.add_theme_color_override("font_color", Ui.COR_PERIGO)
		_lbl_instrucao.text = "Caminhão-pipa (3) apaga e molha uma área. Brigada (4) chega depois de alguns passos. Aceiro agora custa o dobro."


## Legenda fixa no topo do mapa (dica inicial ou legenda do modo demonstração).
func definir_legenda(texto: String) -> void:
	_legenda_fixa = texto
	if _tempo_mensagem <= 0.0:
		_mostrar_texto_legenda(texto)


## Mensagem temporária no topo do mapa (ex.: "Sem cargas").
func mostrar_mensagem(texto: String, segundos: float = 2.5) -> void:
	_tempo_mensagem = segundos
	_mostrar_texto_legenda(texto)


## No modo demonstração o HUD fica limpo: só clima, risco, recursos, status e legenda.
func modo_demo(ativo: bool) -> void:
	for c in _secao_controles:
		c.visible = not ativo
	_secao_missao.visible = not ativo
	_lbl_missao.visible = false
	_lbl_creditos.visible = false
	_secao_manual.visible = false
	_btn_atualizar.visible = false
	_btn_sair_demo.visible = ativo
	_lbl_modo_demo.visible = ativo
	for rolagem in _rolagens:
		rolagem.set_deferred("scroll_vertical", 0)


static func formatar_inteiro(valor: int) -> String:
	var texto := str(absi(valor))
	var resultado := ""
	while texto.length() > 3:
		resultado = "." + texto.right(3) + resultado
		texto = texto.left(texto.length() - 3)
	return ("-" if valor < 0 else "") + texto + resultado


# --- Montagem -------------------------------------------------------------------------------

func _montar_esquerda() -> void:
	var caixa := _painel(true)
	var titulo := _label(config.nome_projeto.to_upper(), 44, COR_DESTAQUE)
	caixa.add_child(titulo)
	caixa.add_child(_label("Simulador de prevenção de queimadas", 19))
	caixa.add_child(_label("Protótipo (prova de conceito) · Scorpion Bits", 15, COR_SUAVE))
	_lbl_modo_demo = _label("MODO DEMONSTRAÇÃO", 17, COR_DESTAQUE)
	_lbl_modo_demo.visible = false
	caixa.add_child(_lbl_modo_demo)
	_lbl_missao = _label("", 22, COR_DESTAQUE)
	_lbl_missao.visible = false
	caixa.add_child(_lbl_missao)

	_titulo_secao(caixa, "CLIMA · " + config.nome_local.to_upper())
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 16)
	_seta = SetaVento.new()
	_seta.custom_minimum_size = Vector2(112, 112)
	linha.add_child(_seta)
	var dados := VBoxContainer.new()
	dados.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dados.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dados.add_theme_constant_override("separation", 2)
	_lbl_temperatura = _label("-- °C", 34)
	_lbl_umidade = _label("Umidade: --", 19)
	_lbl_vento = _label("Vento: --", 19)
	for l in [_lbl_temperatura, _lbl_umidade, _lbl_vento]:
		dados.add_child(l)
	linha.add_child(dados)
	caixa.add_child(linha)
	_lbl_horario = _label("", 15, COR_SUAVE)
	caixa.add_child(_lbl_horario)
	_lbl_status_clima = _label("Buscando clima…", 15, COR_SUAVE)
	caixa.add_child(_lbl_status_clima)
	caixa.add_child(_label("Dados meteorológicos: Open-Meteo.com (CC BY 4.0)", 14, COR_SUAVE))
	_btn_atualizar = _botao("Atualizar clima", atualizar_clima_pedido.emit)
	caixa.add_child(_btn_atualizar)

	var painel_risco := PanelContainer.new()
	_estilo_risco = StyleBoxFlat.new()
	_estilo_risco.set_corner_radius_all(10)
	_estilo_risco.set_content_margin_all(12)
	_estilo_risco.bg_color = Risco.cores[0]
	painel_risco.add_theme_stylebox_override("panel", _estilo_risco)
	_lbl_risco = _label("RISCO DE FOGO: --", 22, COR_ESCURA)
	_lbl_risco.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	painel_risco.add_child(_lbl_risco)
	caixa.add_child(_espaco(6))
	caixa.add_child(painel_risco)
	caixa.add_child(_label("Índice simplificado, não oficial (umidade, temperatura e vento).", 14, COR_SUAVE))
	_lbl_focos = _label("", 15, COR_SUAVE)
	_lbl_focos.visible = false
	caixa.add_child(_lbl_focos)
	_lbl_creditos = _label("", 14, COR_SUAVE)
	_lbl_creditos.visible = false
	caixa.add_child(_lbl_creditos)

	var manual := VBoxContainer.new()
	_secao_manual = manual
	_titulo_secao(manual, "CENÁRIO MANUAL")
	_chk_manual = CheckButton.new()
	_chk_manual.text = "Usar valores manuais"
	_chk_manual.toggled.connect(func(_v: bool) -> void: _emitir_manual())
	manual.add_child(_chk_manual)
	_slider(manual, "temperatura", "Temperatura", 5, 45, 1, config.temperatura_padrao)
	_slider(manual, "umidade", "Umidade", 5, 100, 1, config.umidade_padrao)
	_slider(manual, "vento", "Vento", 0, 60, 1, config.vento_padrao_kmh)
	_slider(manual, "direcao", "Vem do", 0, 355, 5, config.direcao_vento_padrao)
	manual.add_child(_botao("Dia crítico (como agosto de 2024)", _aplicar_dia_critico))
	caixa.add_child(manual)


func _montar_direita() -> void:
	var caixa := _painel(false)
	_secao_missao = VBoxContainer.new()
	_secao_missao.add_theme_constant_override("separation", 6)
	var linha_etapa := HBoxContainer.new()
	_lbl_etapa = _label("", 28, COR_DESTAQUE)
	_lbl_etapa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_etapa.autowrap_mode = TextServer.AUTOWRAP_OFF
	linha_etapa.add_child(_lbl_etapa)
	linha_etapa.add_child(_botao("Menu (Esc)", menu_pedido.emit))
	_secao_missao.add_child(linha_etapa)
	_lbl_instrucao = _label("", 17)
	_secao_missao.add_child(_lbl_instrucao)
	_btn_comecar = Ui.botao_principal("Começar o incêndio", comecar_pedido.emit, 24)
	_secao_missao.add_child(_btn_comecar)
	caixa.add_child(_secao_missao)

	var ferramentas := VBoxContainer.new()
	_titulo_secao(ferramentas, "FERRAMENTAS")
	var grupo := ButtonGroup.new()
	var nomes := ["1  Acender foco", "2  Aceiro", "3  Caminhão-pipa", "4  Chamar brigada 193"]
	var dicas := [
		"Clique numa célula para começar um foco de incêndio.",
		"Arraste no mapa para abrir uma faixa sem vegetação (barreira). Custa orçamento.",
		"Clique para molhar uma área: apaga o fogo e deixa a vegetação molhada por um tempo.",
		"Clique onde a brigada deve agir. Ela demora alguns passos para chegar.",
	]
	for i in nomes.size():
		var b := _botao(nomes[i], ferramenta_escolhida.emit.bind(i))
		b.toggle_mode = true
		b.button_group = grupo
		b.tooltip_text = dicas[i]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_botoes_ferramenta.append(b)
		ferramentas.add_child(b)
	caixa.add_child(ferramentas)
	_secao_controles.append(ferramentas)

	_titulo_secao(caixa, "RECURSOS")
	_lbl_orcamento = _label("", 19)
	_lbl_pipa = _label("", 17)
	_lbl_brigada = _label("", 17)
	for l in [_lbl_orcamento, _lbl_pipa, _lbl_brigada]:
		caixa.add_child(l)

	var simulacao := VBoxContainer.new()
	_titulo_secao(simulacao, "SIMULAÇÃO")
	var velocidades := HBoxContainer.new()
	var grupo_v := ButtonGroup.new()
	for i in _velocidades.size():
		var texto := "Pausa" if _velocidades[i] == 0.0 else "%d×" % roundi(_velocidades[i])
		var b := _botao(texto, velocidade_escolhida.emit.bind(_velocidades[i]))
		b.toggle_mode = true
		b.button_group = grupo_v
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_botoes_velocidade.append(b)
		velocidades.add_child(b)
	simulacao.add_child(velocidades)
	var linha_sim := HBoxContainer.new()
	var recomecar := _botao("Recomeçar a missão (R)", reiniciar_pedido.emit)
	recomecar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha_sim.add_child(recomecar)
	_btn_som = _botao("Som: ligado (M)", som_pedido.emit)
	linha_sim.add_child(_btn_som)
	simulacao.add_child(linha_sim)
	caixa.add_child(simulacao)
	_secao_controles.append(simulacao)

	_btn_sair_demo = _botao("Sair da demonstração", sair_demo_pedido.emit)
	_btn_sair_demo.visible = false
	caixa.add_child(_btn_sair_demo)

	_lbl_status = _label("", 16, COR_SUAVE)
	caixa.add_child(_espaco(4))
	caixa.add_child(_lbl_status)

	_titulo_secao(caixa, "LEGENDA")
	var legenda := GridContainer.new()
	legenda.columns = 2
	legenda.add_theme_constant_override("h_separation", 18)
	for tipo in Terreno.QUANTIDADE:
		legenda.add_child(_item_legenda(Terreno.cores_tela[tipo], Terreno.nomes[tipo]))
	legenda.add_child(_item_legenda(Renderizador.FOGO_MEIO, "Fogo"))
	legenda.add_child(_item_legenda(Renderizador.COR_QUEIMADA, "Queimada"))
	legenda.add_child(_item_legenda(Terreno.cores_tela[0].lerp(Renderizador.COR_MOLHADA, 0.6), "Molhada"))
	caixa.add_child(legenda)


func _montar_topo_e_rodape() -> void:
	_painel_legenda = PanelContainer.new()
	add_child(_painel_legenda)
	_painel_legenda.anchor_right = 1.0
	_painel_legenda.offset_left = LARGURA_PAINEL + MARGEM * 3
	_painel_legenda.offset_right = -(LARGURA_PAINEL + MARGEM * 3)
	_painel_legenda.offset_top = MARGEM
	_painel_legenda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_legenda = _label("", 22)
	_lbl_legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_painel_legenda.add_child(_lbl_legenda)
	_painel_legenda.visible = false

	var aviso := _label(AVISO, 15, COR_SUAVE)
	add_child(aviso)
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.anchor_top = 1.0
	aviso.anchor_bottom = 1.0
	aviso.anchor_right = 1.0
	aviso.offset_left = LARGURA_PAINEL + MARGEM * 2
	aviso.offset_right = -(LARGURA_PAINEL + MARGEM * 2)
	aviso.offset_top = -34
	aviso.offset_bottom = -10


func _mostrar_texto_legenda(texto: String) -> void:
	_lbl_legenda.text = texto
	_painel_legenda.visible = not texto.is_empty()


func _painel(esquerda: bool) -> VBoxContainer:
	var painel := PanelContainer.new()
	add_child(painel)
	painel.anchor_left = 0.0 if esquerda else 1.0
	painel.anchor_right = painel.anchor_left
	painel.anchor_bottom = 1.0
	painel.offset_left = MARGEM if esquerda else -MARGEM - LARGURA_PAINEL
	painel.offset_right = MARGEM + LARGURA_PAINEL if esquerda else -MARGEM
	painel.offset_top = MARGEM
	painel.offset_bottom = -MARGEM
	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	painel.add_child(rolagem)
	_rolagens.append(rolagem)
	var caixa := VBoxContainer.new()
	caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caixa.add_theme_constant_override("separation", 6)
	rolagem.add_child(caixa)
	return caixa


func _titulo_secao(caixa: Control, texto: String) -> void:
	caixa.add_child(_espaco(4))
	caixa.add_child(_label(texto, 15, COR_DESTAQUE))
	var linha := ColorRect.new()
	linha.color = Color(0.3, 0.26, 0.22)
	linha.custom_minimum_size = Vector2(0, 1)
	caixa.add_child(linha)


func _label(texto: String, tamanho: int, cor: Color = Color(0.95, 0.91, 0.84)) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _botao(texto: String, ao_clicar: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(ao_clicar)
	return b


func _espaco(altura: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, altura)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _item_legenda(cor: Color, texto: String) -> HBoxContainer:
	var linha := HBoxContainer.new()
	var amostra := ColorRect.new()
	amostra.color = cor
	amostra.custom_minimum_size = Vector2(18, 18)
	amostra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(amostra)
	var l := _label(texto, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	linha.add_child(l)
	return linha


func _slider(caixa: Control, chave: String, nome: String, minimo: float, maximo: float,
		passo: float, valor: float) -> void:
	var linha := HBoxContainer.new()
	var l := _label(nome, 16)
	l.custom_minimum_size = Vector2(110, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	linha.add_child(l)
	var s := HSlider.new()
	s.min_value = minimo
	s.max_value = maximo
	s.step = passo
	s.value = valor
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(_v: float) -> void: _emitir_manual())
	linha.add_child(s)
	var v := _label("", 16)
	v.custom_minimum_size = Vector2(92, 0)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	linha.add_child(v)
	caixa.add_child(linha)
	_sliders[chave] = s
	_valores_sliders[chave] = v
	_atualizar_valores_sliders()


func _atualizar_valores_sliders() -> void:
	var formatos := {"temperatura": "%d °C", "umidade": "%d%%", "vento": "%d km/h"}
	for chave: String in _sliders:
		var valor := roundi(_sliders[chave].value)
		if chave == "direcao":
			_valores_sliders[chave].text = "%d° (%s)" % [valor, _sigla_direcao(valor)]
		else:
			_valores_sliders[chave].text = formatos[chave] % valor


func _sigla_direcao(graus: float) -> String:
	var siglas := ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]
	return siglas[roundi(fposmod(graus, 360.0) / 45.0) % 8]


func _aplicar_dia_critico() -> void:
	_ignorar_sliders = true
	_sliders["temperatura"].value = config.temperatura_demo
	_sliders["umidade"].value = config.umidade_demo
	_sliders["vento"].value = config.vento_demo_kmh
	_sliders["direcao"].value = config.direcao_vento_demo
	_ignorar_sliders = false
	_chk_manual.set_pressed_no_signal(true)
	_emitir_manual()


func _emitir_manual() -> void:
	if _sliders.size() < 4:
		return
	_atualizar_valores_sliders()
	if _ignorar_sliders:
		return
	clima_manual_alterado.emit(_chk_manual.button_pressed, _sliders["temperatura"].value,
			_sliders["umidade"].value, _sliders["vento"].value, _sliders["direcao"].value)
