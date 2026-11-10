class_name Terreno
## Tipos de terreno e a paleta fixa de cores dos mapas PNG.

enum Tipo { CANA, PASTO, MATA, ESTRADA, AGUA, SEDE, ACEIRO }

const QUANTIDADE := 7
## Quantos tipos podem vir de um mapa PNG (o aceiro só é criado pelo jogador).
const TIPOS_DO_MAPA := 6

## Paleta oficial dos mapas PNG, na ordem do enum Tipo.
static var cores_mapa: Array[Color] = [
	Color("#C8B44A"),  # Cana-de-açúcar
	Color("#D9C27A"),  # Pasto seco
	Color("#2E6B2E"),  # Mata nativa
	Color("#8A7F70"),  # Estrada / aceiro
	Color("#3A6EA5"),  # Água
	Color("#B03A2E"),  # Construção / sede
]

## Cores usadas na tela. O aceiro aberto pelo jogador fica um pouco mais claro que a estrada,
## para que ele enxergue o que fez.
static var cores_tela: Array[Color] = [
	Color("#C8B44A"),
	Color("#D9C27A"),
	Color("#2E6B2E"),
	Color("#8A7F70"),
	Color("#3A6EA5"),
	Color("#B03A2E"),
	Color("#E6DDCB"),
]

static var nomes: PackedStringArray = [
	"Cana-de-açúcar", "Pasto seco", "Mata nativa", "Estrada", "Água", "Sede", "Aceiro",
]


## Devolve o tipo cuja cor da paleta é a mais próxima de `cor`. Assim, PNGs com pequenas
## variações (compressão, antisserrilhado) ainda são lidos corretamente.
static func classificar(cor: Color) -> int:
	var melhor := 0
	var menor_distancia := INF
	for tipo in TIPOS_DO_MAPA:
		var ref := cores_mapa[tipo]
		var d := (cor.r - ref.r) ** 2 + (cor.g - ref.g) ** 2 + (cor.b - ref.b) ** 2
		if d < menor_distancia:
			menor_distancia = d
			melhor = tipo
	return melhor
