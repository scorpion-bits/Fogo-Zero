extends SceneTree
## Confere se o conteúdo dos painéis do HUD cabe na largura deles (nada cortado na lateral).
## Uso: godot --headless --path . -s testes/medir_hud.gd

var _principal: Node
var _quadro := 0


func _initialize() -> void:
	_principal = (load("res://cenas/principal.tscn") as PackedScene).instantiate()
	root.add_child(_principal)


func _process(_delta: float) -> bool:
	_quadro += 1
	if _quadro == 5:
		_principal.call("iniciar_missao", Campanha.fases()[0])
	if _quadro < 10:
		return false
	var ok := true
	for rolagem: ScrollContainer in _principal.get_node("HUD").get("_rolagens"):
		# O painel cresce junto com o conteúdo: se passar da largura prevista, ele sai da tela.
		var painel := rolagem.get_parent() as Control
		var cabe := painel.size.x <= Hud.LARGURA_PAINEL + 0.5
		ok = ok and cabe
		print("  [%s] painel com %d px (previsto: %d px)" % ["ok" if cabe else "FALHOU",
				roundi(painel.size.x), roundi(Hud.LARGURA_PAINEL)])
	print("HUD CABE NOS PAINÉIS" if ok else "HUD CORTADO")
	quit(0 if ok else 1)
	return true
