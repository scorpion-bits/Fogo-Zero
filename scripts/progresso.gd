class_name Progresso
## Estrelas e recordes de cada fase, salvos em user://progresso.cfg (no navegador, o Godot guarda
## isso no armazenamento do site).

const ARQUIVO := "user://progresso.cfg"
const SECAO_OPCOES := "opcoes"

static var _cfg: ConfigFile


static func _dados() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(ARQUIVO)
	return _cfg


static func estrelas(id: String) -> int:
	return int(_dados().get_value(id, "estrelas", 0))


static func recorde(id: String) -> int:
	return int(_dados().get_value(id, "recorde", 0))


static func jogada(id: String) -> bool:
	return _dados().has_section(id)


## A primeira fase está sempre aberta; as outras abrem com ao menos 1 estrela na anterior.
static func desbloqueada(fases: Array[Missao], indice: int) -> bool:
	return indice == 0 or estrelas(fases[indice - 1].id) >= 1


## Guarda o resultado se ele for melhor. Retorna true se bateu o recorde de pontos.
static func registrar(id: String, p_estrelas: int, pontos: int) -> bool:
	var d := _dados()
	var novo_recorde := pontos > recorde(id)
	d.set_value(id, "estrelas", maxi(p_estrelas, estrelas(id)))
	d.set_value(id, "recorde", maxi(pontos, recorde(id)))
	d.save(ARQUIVO)
	return novo_recorde


static func total_estrelas(fases: Array[Missao]) -> int:
	var total := 0
	for m in fases:
		total += estrelas(m.id)
	return total


## Apaga as estrelas e os recordes (a preferência de som fica).
static func apagar() -> void:
	var som := som_ligado()
	_cfg = ConfigFile.new()
	if not som:
		_cfg.set_value(SECAO_OPCOES, "som", false)
	_cfg.save(ARQUIVO)


static func som_ligado() -> bool:
	return bool(_dados().get_value(SECAO_OPCOES, "som", true))


static func definir_som(ligado: bool) -> void:
	_dados().set_value(SECAO_OPCOES, "som", ligado)
	_dados().save(ARQUIVO)
