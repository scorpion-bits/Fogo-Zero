class_name TelaResultado
extends Control
## Tela de fim de rodada: sede salva ou não, pontuação, área queimada por tipo, recursos usados,
## "O que aconteceu?" e uma dica de prevenção.

signal jogar_novamente
signal fechado

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


func mostrar(dados: Dictionary) -> void:
	for filho in _caixa.get_children():
		filho.queue_free()
	var salva: bool = dados["sede_salva"]
	_add(_label("SEDE SALVA!" if salva else "A SEDE FOI ATINGIDA", 40,
			Color("#6BCB5A") if salva else Color("#E5484D")))
	_add(_label("Pontuação: %s   ·   Área queimada: %s ha" % [
		Hud.formatar_inteiro(dados["pontuacao"]), Narrador.formatar_ha(dados["area_ha"])], 24))

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
	var novamente := Button.new()
	novamente.text = "Jogar de novo (mesma semente)"
	novamente.pressed.connect(jogar_novamente.emit)
	var fechar := Button.new()
	fechar.text = "Ver o mapa"
	fechar.pressed.connect(func() -> void:
		hide()
		fechado.emit())
	botoes.add_child(fechar)
	botoes.add_child(novamente)
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
