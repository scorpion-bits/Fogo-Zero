class_name Ui
## Peças de interface usadas pelas telas (menu, fases, modo personalizado e resultado).

const COR_TEXTO := Color(0.95, 0.91, 0.84)
const COR_SUAVE := Color(0.64, 0.6, 0.55)
const COR_DESTAQUE := Color("#F28C28")
const COR_ESCURA := Color(0.09, 0.08, 0.07)
const COR_SUCESSO := Color("#6BCB5A")
const COR_PERIGO := Color("#E5484D")
const COR_FUNDO := Color(0.086, 0.078, 0.07)


static func label(texto: String, tamanho: int, cor: Color = COR_TEXTO) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Rótulo curto, numa linha só (para usar dentro de linhas com botões e campos).
static func rotulo(texto: String, tamanho: int, cor: Color = COR_TEXTO) -> Label:
	var l := label(texto, tamanho, cor)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


static func botao(texto: String, ao_clicar: Callable, tamanho: int = 0) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	if tamanho > 0:
		b.add_theme_font_size_override("font_size", tamanho)
	b.pressed.connect(ao_clicar)
	return b


## Botão grande e laranja, para a ação principal da tela.
static func botao_principal(texto: String, ao_clicar: Callable, tamanho: int = 26) -> Button:
	var b := botao(texto, ao_clicar, tamanho)
	for estado in ["normal", "hover", "pressed", "disabled"]:
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = COR_DESTAQUE.lightened(0.12 if estado == "hover" else 0.0).darkened(0.15 if estado == "pressed" else 0.0)
		if estado == "disabled":
			estilo.bg_color = Color(0.25, 0.2, 0.16)
		estilo.set_corner_radius_all(10)
		estilo.set_content_margin_all(14)
		b.add_theme_stylebox_override(estado, estilo)
	for chave in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(chave, COR_ESCURA)
	return b


static func espaco(altura: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, altura)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func titulo_secao(caixa: Control, texto: String) -> void:
	caixa.add_child(espaco(4))
	caixa.add_child(label(texto, 15, COR_DESTAQUE))
	var linha := ColorRect.new()
	linha.color = Color(0.3, 0.26, 0.22)
	linha.custom_minimum_size = Vector2(0, 1)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(linha)


## Painel com o estilo do tema e uma caixa vertical dentro. Devolve a caixa.
static func painel(pai: Control, separacao: int = 8) -> VBoxContainer:
	var p := PanelContainer.new()
	pai.add_child(p)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", separacao)
	p.add_child(caixa)
	return caixa


## Fundo opaco que cobre a tela inteira (as telas de menu ficam por cima do jogo).
static func fundo(pai: Control) -> ColorRect:
	var f := ColorRect.new()
	f.color = COR_FUNDO
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pai.add_child(f)
	return f
