class_name MapaView
extends Control
## Mostra a textura da grade, recebe cliques e arrastos do jogador e desenha os marcadores:
## alcance da ferramenta, brigada a caminho, norte e escala.

signal clique(celula: Vector2i)
signal arrasto(de: Vector2i, para: Vector2i)

const COR_BORDA := Color(0.32, 0.28, 0.24)
const COR_MIRA := Color(1, 1, 1, 0.85)

var sim: SimulacaoFogo
var ferramentas: Ferramentas
var textura: Texture2D
var ferramenta: Ferramentas.Tipo = Ferramentas.Tipo.FOCO
var interativo := true

var _arrastando := false
var _ultima := Vector2i(-1, -1)
var _mouse := Vector2i(-1, -1)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func configurar(p_sim: SimulacaoFogo, p_ferramentas: Ferramentas, p_textura: Texture2D) -> void:
	sim = p_sim
	ferramentas = p_ferramentas
	textura = p_textura
	queue_redraw()


## Retângulo (em pixels) onde o mapa é desenhado, centralizado e mantendo a proporção.
func area_mapa() -> Rect2:
	if sim == null:
		return Rect2()
	var escala := minf(size.x / sim.largura, size.y / sim.altura)
	var tamanho := Vector2(sim.largura, sim.altura) * escala
	return Rect2(((size - tamanho) / 2.0).floor(), tamanho)


func tamanho_celula() -> float:
	return area_mapa().size.x / sim.largura if sim != null else 1.0


func celula_em(pos: Vector2) -> Vector2i:
	var area := area_mapa()
	var rel := (pos - area.position) / tamanho_celula()
	return Vector2i(floori(rel.x), floori(rel.y))


func centro_celula(c: Vector2i) -> Vector2:
	return area_mapa().position + (Vector2(c) + Vector2(0.5, 0.5)) * tamanho_celula()


func _gui_input(event: InputEvent) -> void:
	if sim == null or not interativo:
		return
	if event is InputEventMouseMotion:
		var c := celula_em((event as InputEventMouseMotion).position)
		_mouse = c
		if _arrastando and c != _ultima and sim.grade.contem(c):
			arrasto.emit(_ultima, c)
			_ultima = c
		queue_redraw()
	elif event is InputEventMouseButton:
		var botao := event as InputEventMouseButton
		if botao.button_index != MOUSE_BUTTON_LEFT:
			return
		var c := celula_em(botao.position)
		if botao.pressed and sim.grade.contem(c):
			if ferramenta == Ferramentas.Tipo.ACEIRO:
				_arrastando = true
				_ultima = c
				arrasto.emit(c, c)
			else:
				clique.emit(c)
			accept_event()
		elif not botao.pressed:
			_arrastando = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2i(-1, -1)
		queue_redraw()


func _draw() -> void:
	if sim == null or textura == null:
		return
	var area := area_mapa()
	var cel := tamanho_celula()
	draw_rect(area.grow(6.0), Color(0.06, 0.055, 0.05))
	draw_texture_rect(textura, area, false)
	draw_rect(area.grow(6.0), COR_BORDA, false, 2.0)
	var fonte := get_theme_default_font()

	# Brigadas a caminho.
	for chamada in ferramentas.chamadas_pendentes:
		var centro := centro_celula(chamada.centro)
		var restante := chamada.passo_chegada - sim.passo
		draw_arc(centro, ferramentas.config.raio_brigada * cel, 0.0, TAU, 64, Color(1, 0.3, 0.25, 0.9), 3.0, true)
		_texto_com_fundo(fonte, centro, "193 · chega em %d" % restante, 18)

	# Norte e escala.
	var norte := area.position + Vector2(area.size.x - 34.0, 40.0)
	draw_colored_polygon(PackedVector2Array([norte + Vector2(0, -22), norte + Vector2(10, 6), norte + Vector2(-10, 6)]),
			Color(0.95, 0.91, 0.84, 0.9))
	_texto_com_fundo(fonte, norte + Vector2(0, 22), "N", 18)
	var metros := 200.0
	var largura_escala := metros / sim.config.metros_por_celula * cel
	var base := area.position + Vector2(18.0, area.size.y - 22.0)
	draw_rect(Rect2(base - Vector2(6, 26), Vector2(largura_escala + 12, 34)), Color(0, 0, 0, 0.45))
	draw_line(base, base + Vector2(largura_escala, 0), Color.WHITE, 3.0)
	draw_line(base + Vector2(0, -6), base + Vector2(0, 2), Color.WHITE, 2.0)
	draw_line(base + Vector2(largura_escala, -6), base + Vector2(largura_escala, 2), Color.WHITE, 2.0)
	draw_string(fonte, base + Vector2(0, -9), "%d m" % metros, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

	# Prévia da ferramenta sob o mouse.
	if not interativo or not sim.grade.contem(_mouse):
		return
	var pos := centro_celula(_mouse)
	match ferramenta:
		Ferramentas.Tipo.FOCO, Ferramentas.Tipo.ACEIRO:
			draw_rect(Rect2(pos - Vector2(cel, cel) / 2.0, Vector2(cel, cel)).grow(1.0), COR_MIRA, false, 2.0)
		Ferramentas.Tipo.PIPA:
			draw_arc(pos, (ferramentas.config.raio_pipa + 0.5) * cel, 0.0, TAU, 48, Color(0.5, 0.75, 1.0, 0.95), 2.0, true)
		Ferramentas.Tipo.BRIGADA:
			draw_arc(pos, (ferramentas.config.raio_brigada + 0.5) * cel, 0.0, TAU, 64, Color(1, 0.4, 0.35, 0.95), 2.0, true)


func _texto_com_fundo(fonte: Font, centro: Vector2, texto: String, tamanho: int) -> void:
	var medida := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho)
	var caixa := Rect2(centro - Vector2(medida.x / 2.0 + 6.0, medida.y / 2.0 + 2.0), medida + Vector2(12, 4))
	draw_rect(caixa, Color(0, 0, 0, 0.6))
	draw_string(fonte, Vector2(caixa.position.x + 6.0, centro.y + medida.y * 0.3), texto,
			HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, Color.WHITE)
