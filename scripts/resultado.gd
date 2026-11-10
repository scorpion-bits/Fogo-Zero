class_name TelaResultado
extends Control
## Tela de fim de rodada: sede salva ou não, pontuação, área queimada por tipo, recursos usados,
## "O que aconteceu?" e uma dica de prevenção.

signal jogar_novamente
signal proxima_pedida
signal voltar_pedido

const COR_SUAVE := Color(0.64, 0.6, 0.55)
const COR_DESTAQUE := Color("#F28C28")

var _caixa: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.6)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(920, 0)
	centro.add_child(painel)
	_caixa = VBoxContainer.new()
	_caixa.add_theme_constant_override("separation", 8)
	painel.add_child(_caixa)
	hide()


## `opcoes`: "proxima" (há próxima fase aberta), "voltar" (texto do botão de voltar),
## "novo_recorde" e "titulo" (substitui o título padrão).
func mostrar(dados: Dictionary, opcoes: Dictionary = {}) -> void:
	for filho in _caixa.get_children():
		filho.queue_free()
	var salva: bool = dados["sede_salva"]
	var titulo := HBoxContainer.new()
	titulo.add_theme_constant_override("separation", 24)
	var texto_titulo: String = opcoes.get("titulo", "SEDE SALVA!" if salva else "A SEDE FOI ATINGIDA")
	var lbl_titulo := _label(texto_titulo, 40, Color("#6BCB5A") if salva else Color("#E5484D"))
	lbl_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.add_child(lbl_titulo)
	if dados.get("tem_referencia", false):
		titulo.add_child(Estrelas.criar(dados["estrelas"], 44.0))
	_add(titulo)
	var recorde := "   ·   Novo recorde!" if opcoes.get("novo_recorde", false) else ""
	_add(_label("Pontuação: %s   ·   Área queimada: %s ha%s" % [
		Hud.formatar_inteiro(dados["pontuacao"]), Narrador.formatar_ha(dados["area_ha"]), recorde], 24))
	if not (dados.get("comparacao", []) as Array).is_empty():
		_add(_label(" ".join(dados["comparacao"]), 20, COR_DESTAQUE))
	if dados.has("pontos_detalhe"):
		_add(_label(" · ".join(dados["pontos_detalhe"]), 17, COR_SUAVE))

	var colunas := HBoxContainer.new()
	colunas.add_theme_constant_override("separation", 40)
	colunas.add_child(_lista("Queimado por tipo de vegetação", dados["por_tipo"]))
	colunas.add_child(_lista("Recursos usados", dados["recursos"]))
	_add(colunas)

	_add(_titulo("O QUE ACONTECEU?"))
	_add(_label(" ".join(dados["o_que_aconteceu"]), 19))
	_add(_titulo("DICA DE PREVENÇÃO"))
	_add(_label(dados["dica"], 19))
	_add(_label(Narrador.CONTATOS, 19, COR_DESTAQUE))

	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_END
	botoes.add_theme_constant_override("separation", 12)
	var fechar := Ui.botao("Ver o mapa", hide, 20)
	botoes.add_child(fechar)
	botoes.add_child(Ui.botao(opcoes.get("voltar", "Menu"), voltar_pedido.emit, 20))
	if opcoes.get("proxima", false):
		botoes.add_child(Ui.botao("Tentar de novo", jogar_novamente.emit, 20))
		botoes.add_child(Ui.botao_principal("Próxima fase  ›", proxima_pedida.emit, 22))
	else:
		botoes.add_child(Ui.botao_principal("Tentar de novo", jogar_novamente.emit, 22))
	_add(_espaco(6))
	_add(botoes)
	show()


func _add(c: Control) -> void:
	_caixa.add_child(c)


func _lista(titulo: String, linhas: Array) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_titulo(titulo.to_upper()))
	for linha: String in linhas:
		v.add_child(_label(linha, 18))
	return v


func _titulo(texto: String) -> Label:
	var l := _label(texto, 15, COR_DESTAQUE)
	l.custom_minimum_size = Vector2(0, 30)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


func _label(texto: String, tamanho: int, cor: Color = Color(0.95, 0.91, 0.84)) -> Label:
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	return l


func _espaco(altura: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, altura)
	return c
