class_name Estrelas
extends Control
## Três estrelas desenhadas (cheias ou vazias), sem depender de fonte com o símbolo ★.

const COR_CHEIA := Color("#F5C542")
const COR_VAZIA := Color(0.3, 0.27, 0.24)

var quantidade := 0:
	set(v):
		quantidade = v
		queue_redraw()
var tamanho := 28.0


static func criar(p_quantidade: int, p_tamanho: float = 28.0) -> Estrelas:
	var e := Estrelas.new()
	e.quantidade = p_quantidade
	e.tamanho = p_tamanho
	e.custom_minimum_size = Vector2(p_tamanho * 3.3, p_tamanho)
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return e


func _draw() -> void:
	var inicio := (size.x - tamanho * 3.3) / 2.0
	for i in 3:
		var centro := Vector2(inicio + tamanho * (0.5 + 1.15 * i), size.y / 2.0)
		draw_colored_polygon(poligono(centro, tamanho / 2.0), COR_CHEIA if i < quantidade else COR_VAZIA)


static func poligono(centro: Vector2, raio: float) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	for k in 10:
		var r := raio if k % 2 == 0 else raio * 0.45
		var angulo := -PI / 2.0 + k * PI / 5.0
		pontos.append(centro + Vector2(cos(angulo), sin(angulo)) * r)
	return pontos
