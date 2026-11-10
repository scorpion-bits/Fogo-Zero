class_name SetaVento
extends Control
## Rosa dos ventos com uma seta apontando para onde o vento sopra.

var direcao := 0.0:
	set(valor):
		direcao = valor
		queue_redraw()
var velocidade := 0.0:
	set(valor):
		velocidade = valor
		queue_redraw()
var cor_seta := Color("#F28C28")


func _draw() -> void:
	var centro := size / 2.0
	var raio := minf(size.x, size.y) / 2.0 - 2.0
	draw_circle(centro, raio, Color(0.08, 0.07, 0.06))
	draw_arc(centro, raio, 0.0, TAU, 48, Color(0.35, 0.31, 0.27), 2.0, true)
	var fonte := get_theme_default_font()
	var tamanho := 13
	for item: Array in [["N", Vector2(0, -1)], ["L", Vector2(1, 0)], ["S", Vector2(0, 1)], ["O", Vector2(-1, 0)]]:
		var texto: String = item[0]
		var pos: Vector2 = centro + (item[1] as Vector2) * (raio - 10.0)
		var medida := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho)
		draw_string(fonte, pos + Vector2(-medida.x / 2.0, medida.y / 3.0), texto,
				HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, Color(0.6, 0.55, 0.5))
	if velocidade < 0.5:
		draw_circle(centro, 5.0, cor_seta)
		return
	# A seta aponta para onde o vento vai (direção meteorológica + 180°).
	var rumo := deg_to_rad(direcao + 180.0)
	var v := Vector2(sin(rumo), -cos(rumo))
	var comprimento := raio - 20.0
	var ponta := centro + v * comprimento
	var cauda := centro - v * comprimento
	draw_line(cauda, ponta, cor_seta, 5.0, true)
	var lado := v.orthogonal() * 9.0
	draw_colored_polygon(PackedVector2Array([ponta + v * 4.0, ponta - v * 14.0 + lado, ponta - v * 14.0 - lado]), cor_seta)
