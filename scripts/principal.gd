extends Control
## Cena principal: junta as telas (menu, mapa de fases, modo personalizado), o mapa, a partida,
## o clima, o HUD, a tela de resultado e o modo demonstração.
##
## Atalhos no jogo: 1–4 ferramentas · Espaço pausa · Enter começa o incêndio · R recomeça ·
## Esc volta. Para abrir direto na demonstração: godot --path . -- --demo

enum Tela { MENU, FASES, PERSONALIZADO, JOGO }

@export var config: SimulacaoConfig = preload("res://recursos/simulacao_config.tres")

var partida: Partida
var missao: Missao
var sim: SimulacaoFogo
var ferramentas: Ferramentas
var renderizador: Renderizador
var ferramenta := Ferramentas.Tipo.ACEIRO
var velocidade := 1.0
var roteiro: RoteiroDemo = null
var tela := Tela.MENU

var _fases: Array[Missao] = []
var _leitura: LeituraClima
var _manual := false
var _manual_valores := PackedFloat32Array([0, 0, 0, 0])
var _acumulador := 0.0
var _encerrada := false
var _tempo := 0.0
var _gravando_video := false
var _menu: TelaMenu
var _tela_fases: TelaFases
var _personalizado: TelaPersonalizado
var _sons: Sons

@onready var _mapa: MapaView = $MapaView
@onready var _clima: ClimaApi = $ClimaApi
@onready var _hud: Hud = $HUD
@onready var _resultado: TelaResultado = $Resultado


func _ready() -> void:
	_fases = Campanha.fases()
	_gravando_video = "--write-movie" in OS.get_cmdline_args()
	if _gravando_video:
		# Durante a gravação, nenhum clique, tecla ou rolagem pode mudar o vídeo.
		get_viewport().gui_disable_input = true
		set_process_unhandled_input(false)
	_leitura = LeituraClima.offline(config, "Buscando o clima de %s…" % config.nome_local)

	_sons = Sons.new()
	add_child(_sons)
	_hud.configurar(config)
	_hud.som_pedido.connect(_alternar_som)
	_hud.ferramenta_escolhida.connect(_escolher_ferramenta)
	_hud.velocidade_escolhida.connect(_escolher_velocidade)
	_hud.reiniciar_pedido.connect(reiniciar)
	_hud.comecar_pedido.connect(_comecar_incendio)
	_hud.menu_pedido.connect(_voltar)
	_hud.sair_demo_pedido.connect(mostrar_menu)
	_hud.atualizar_clima_pedido.connect(_clima.atualizar)
	_hud.clima_manual_alterado.connect(_on_clima_manual)
	_hud.mostrar_focos(FocosInpe.resumo(config))

	_mapa.clique.connect(_on_clique)
	_mapa.arrasto.connect(_on_arrasto)
	_resultado.jogar_novamente.connect(reiniciar)
	_resultado.proxima_pedida.connect(_proxima_fase)
	_resultado.voltar_pedido.connect(_voltar)

	_menu = TelaMenu.new()
	add_child(_menu)
	_menu.jogar_pedido.connect(mostrar_fases)
	_menu.personalizado_pedido.connect(func() -> void: _mostrar_tela(Tela.PERSONALIZADO))
	_menu.demo_pedida.connect(iniciar_demo)
	_tela_fases = TelaFases.new()
	add_child(_tela_fases)
	_tela_fases.fase_escolhida.connect(iniciar_missao)
	_tela_fases.voltar_pedido.connect(mostrar_menu)
	_personalizado = TelaPersonalizado.new()
	_personalizado.config = config
	add_child(_personalizado)
	_personalizado.jogar_pedido.connect(iniciar_missao)
	_personalizado.voltar_pedido.connect(mostrar_menu)
	get_window().files_dropped.connect(_personalizado.receber_arquivos)

	_clima.leitura_recebida.connect(_on_clima)
	_clima.iniciar(config)

	if "--demo" in OS.get_cmdline_user_args():
		iniciar_demo()
	else:
		mostrar_menu()


func _process(delta: float) -> void:
	_tempo += delta
	if tela != Tela.JOGO or sim == null:
		_sons.ambiente(0, 6.0, delta)
		return
	_sons.ambiente(sim.ativos.size(), sim.vento_kmh, delta)
	if roteiro != null:
		_processar_demo(delta)
	elif not _encerrada:
		_processar_partida(delta)
	renderizador.atualizar(_tempo)
	_mapa.progresso_passo = _acumulador if velocidade > 0.0 and not _encerrada else 0.0
	_mapa.tempo = _tempo
	_hud.mostrar_status(sim)
	_hud.mostrar_recursos(ferramentas)
	_mapa.queue_redraw()


func _processar_partida(delta: float) -> void:
	if partida.etapa == Partida.Etapa.INCENDIO and velocidade > 0.0 and partida.ativa():
		# Sem fogo (esperando um evento), o tempo corre mais rápido.
		var pps := config.passos_por_segundo * (1.0 if sim.ha_fogo() else 4.0)
		_acumulador += delta * pps * velocidade
		var passos := 0
		while _acumulador >= 1.0 and passos < 4 and not partida.terminou():
			for mensagem in partida.passo():
				_hud.mostrar_mensagem(mensagem, 4.0)
				_mostrar_clima_hud()
				_sons.tocar("alerta", -4.0)
			_acumulador -= 1.0
			passos += 1
		_acumulador = minf(_acumulador, 1.0)
	partida.avancar_referencia(40)
	_mapa.zonas = partida.centros_pendentes()
	if partida.terminou():
		_encerrar_partida()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	var tecla := (event as InputEventKey).keycode
	if tecla == KEY_ESCAPE:
		if tela == Tela.JOGO:
			_voltar()
		elif tela != Tela.MENU:
			mostrar_menu()
		return
	if tela != Tela.JOGO:
		return
	match tecla:
		KEY_1: _escolher_ferramenta(Ferramentas.Tipo.FOCO)
		KEY_2: _escolher_ferramenta(Ferramentas.Tipo.ACEIRO)
		KEY_3: _escolher_ferramenta(Ferramentas.Tipo.PIPA)
		KEY_4: _escolher_ferramenta(Ferramentas.Tipo.BRIGADA)
		KEY_SPACE: _escolher_velocidade(1.0 if velocidade == 0.0 else 0.0)
		KEY_ENTER, KEY_KP_ENTER: _comecar_incendio()
		KEY_R: reiniciar()
		KEY_M: _alternar_som()


# --- Telas ---------------------------------------------------------------------------------

func _mostrar_tela(nova: Tela) -> void:
	tela = nova
	_menu.visible = nova == Tela.MENU
	_tela_fases.visible = nova == Tela.FASES
	_personalizado.visible = nova == Tela.PERSONALIZADO
	if nova != Tela.JOGO:
		_resultado.hide()


func mostrar_menu() -> void:
	roteiro = null
	_menu.atualizar(Progresso.total_estrelas(_fases), _fases.size() * 3)
	_mostrar_tela(Tela.MENU)


func mostrar_fases() -> void:
	_tela_fases.atualizar()
	_mostrar_tela(Tela.FASES)


## Sai do jogo para a tela de onde a partida veio.
func _voltar() -> void:
	if roteiro != null or missao == null:
		mostrar_menu()
	elif missao.numero > 0:
		mostrar_fases()
	else:
		_mostrar_tela(Tela.PERSONALIZADO)


# --- Partida -------------------------------------------------------------------------------

func iniciar_missao(m: Missao) -> void:
	roteiro = null
	missao = m
	partida = Partida.new(m, config)
	_conectar(partida.sim, partida.ferramentas)
	_mapa.zonas = partida.centros_pendentes()
	_mapa.raio_zona = m.raio_risco
	_mapa.destacar_zonas = true
	_mapa.interativo = true
	_hud.modo_demo(false)
	_hud.modo_missao(m)
	_hud.definir_etapa(partida.etapa, m.foco_livre)
	_aplicar_clima()
	_escolher_ferramenta(Ferramentas.Tipo.FOCO if m.foco_livre else Ferramentas.Tipo.ACEIRO)
	_escolher_velocidade(1.0)
	_hud.definir_legenda("Escolha a ferramenta 1 e clique no mapa para acender um foco." if m.foco_livre
			else "Prepare a fazenda: abra aceiros e depois clique em \"Começar o incêndio\".")
	_mostrar_tela(Tela.JOGO)


func reiniciar() -> void:
	if roteiro != null:
		iniciar_demo()
	elif missao != null:
		iniciar_missao(missao)


func _proxima_fase() -> void:
	if missao != null and missao.numero > 0 and missao.numero < _fases.size():
		iniciar_missao(_fases[missao.numero])


func _conectar(p_sim: SimulacaoFogo, p_ferramentas: Ferramentas) -> void:
	sim = p_sim
	ferramentas = p_ferramentas
	ferramentas.brigada_chegou.connect(_on_brigada_chegou)
	ferramentas.pipa_usada.connect(_on_pipa_usada)
	ferramentas.brigada_chamada.connect(func(_c: Vector2i) -> void: _sons.tocar("sirene", -6.0))
	renderizador = Renderizador.new(sim)
	_mapa.configurar(sim, ferramentas, renderizador.textura)
	_encerrada = false
	_acumulador = 0.0
	_resultado.hide()


func _comecar_incendio() -> void:
	if partida == null or roteiro != null or partida.etapa != Partida.Etapa.PREPARACAO:
		return
	partida.iniciar_incendio()
	_mapa.destacar_zonas = false
	_mapa.zonas = partida.centros_pendentes()
	_hud.definir_etapa(partida.etapa, missao.foco_livre)
	_hud.definir_legenda("")
	_hud.mostrar_mensagem("O fogo começou! Use o caminhão-pipa (3) e a brigada (4).", 4.0)
	_escolher_ferramenta(Ferramentas.Tipo.PIPA)
	_mostrar_clima_hud()
	_sons.tocar("ignicao")


func _encerrar_partida() -> void:
	_encerrada = true
	_hud.definir_legenda("")
	var dados := partida.resultado()
	var opcoes := {"voltar": "Mapa de fases" if missao.numero > 0 else "Configurar outra"}
	if missao.numero > 0:
		var ja_jogada := Progresso.jogada(missao.id)
		var recorde := Progresso.registrar(missao.id, dados["estrelas"], dados["pontuacao"])
		opcoes["novo_recorde"] = recorde and ja_jogada
		opcoes["proxima"] = missao.numero < _fases.size() and Progresso.desbloqueada(_fases, missao.numero)
	if sim.focos.is_empty() and not missao.foco_livre:
		opcoes["titulo"] = "FOGO ISOLADO!"
	_resultado.mostrar(dados, opcoes)
	_sons.tocar("vitoria" if dados["sede_salva"] else "derrota", -2.0)


# --- Demonstração --------------------------------------------------------------------------

func iniciar_demo() -> void:
	var img_t := Grade.carregar_imagem(config.mapa_terreno)
	if img_t == null:
		push_error("Mapa de exemplo não encontrado: " + config.mapa_terreno)
		return
	var g := Grade.de_imagens(img_t, Grade.carregar_imagem(config.mapa_secura), config.largura, config.altura)
	missao = null
	partida = null
	var s := SimulacaoFogo.new(config, g)
	_conectar(s, Ferramentas.new(config, s))
	roteiro = RoteiroDemo.new(config)
	roteiro.preparar(sim)
	renderizador.redesenhar_tudo()
	_mapa.zonas = []
	_mapa.interativo = false
	_hud.modo_demo(true)
	_hud.definir_legenda("")
	_escolher_velocidade(1.0)
	_mostrar_clima_hud()
	_mostrar_tela(Tela.JOGO)


func _processar_demo(delta: float) -> void:
	if _encerrada or velocidade <= 0.0:
		return
	_acumulador += delta * config.passos_por_segundo_demo * velocidade
	var passos := 0
	while _acumulador >= 1.0 and passos < 4 and not _encerrada:
		roteiro.antes_do_passo(sim, ferramentas)
		_hud.definir_legenda(roteiro.legenda)
		if sim.terminou():
			_encerrar_demo()
		else:
			sim.avancar()
			ferramentas.processar_passo()
			if sim.terminou():
				_encerrar_demo()
		_acumulador -= 1.0
		passos += 1
	_acumulador = minf(_acumulador, 1.0)


func _encerrar_demo() -> void:
	_encerrada = true
	var dados := Narrador.resumo(sim, ferramentas)
	dados.merge(Narrador.avaliar(sim, ferramentas, -1, false, true), true)
	roteiro.ao_terminar(sim)
	_hud.definir_legenda(roteiro.legenda)
	await get_tree().create_timer(2.5).timeout
	if roteiro == null:
		return
	_resultado.mostrar(dados, {"voltar": "Menu"})
	_sons.tocar("vitoria" if dados["sede_salva"] else "derrota", -2.0)
	if _gravando_video:
		await get_tree().create_timer(5.0).timeout
		get_tree().quit()


# --- Clima ---------------------------------------------------------------------------------

func _on_clima(leitura: LeituraClima) -> void:
	_leitura = leitura
	var classe := Risco.classe(config, Risco.indice(config, leitura.temperatura, leitura.umidade, leitura.vento_kmh))
	_menu.mostrar_clima(leitura, Risco.nomes[classe])
	_personalizado.receber_clima(leitura)
	_aplicar_clima()


func _on_clima_manual(ativo: bool, temperatura: float, umidade: float, vento: float, direcao: float) -> void:
	_manual = ativo
	_manual_valores = PackedFloat32Array([temperatura, umidade, vento, direcao])
	_aplicar_clima()


## Aplica o clima da missão (fixo, real ou manual) enquanto o fogo não começou.
func _aplicar_clima() -> void:
	if partida == null or roteiro != null:
		return
	if missao.foco_livre and _manual:
		var v := _manual_valores
		partida.definir_clima(v[0], v[1], v[2], v[3])
	elif missao.clima_real:
		partida.definir_clima(_leitura.temperatura, _leitura.umidade, _leitura.vento_kmh, _leitura.vento_direcao)
	_mostrar_clima_hud()


func _mostrar_clima_hud() -> void:
	if sim == null:
		return
	var modo := "Clima da missão (cenário fixo)"
	var cor := Color("#7FC8F8")
	var real := false
	if roteiro != null:
		modo = "Cenário de demonstração: dia crítico"
		cor = Color("#F28C28")
	elif missao.foco_livre and _manual:
		modo = "Modo manual (cenário)"
	elif missao.clima_real:
		modo = _leitura.mensagem
		cor = Color("#6BCB5A") if _leitura.online else Color("#F2A541")
		real = _leitura.online
	_hud.mostrar_clima(_leitura, real, sim.temperatura, sim.umidade, sim.vento_kmh, sim.vento_direcao, modo, cor)


# --- Ferramentas ---------------------------------------------------------------------------

func _escolher_ferramenta(tipo: Ferramentas.Tipo) -> void:
	if roteiro != null:
		return
	if tipo == Ferramentas.Tipo.FOCO and missao != null and not missao.foco_livre:
		return
	ferramenta = tipo
	_mapa.ferramenta = tipo
	_hud.definir_ferramenta(tipo)


func _escolher_velocidade(valor: float) -> void:
	velocidade = valor
	_hud.definir_velocidade(valor)


func _on_clique(celula: Vector2i) -> void:
	if _encerrada or roteiro != null or partida == null:
		return
	if ferramentas.em_preparacao and ferramenta in [Ferramentas.Tipo.PIPA, Ferramentas.Tipo.BRIGADA]:
		_hud.mostrar_mensagem("O caminhão-pipa e a brigada ficam de prontidão até o fogo começar.")
		return
	match ferramenta:
		Ferramentas.Tipo.FOCO:
			if not missao.foco_livre:
				return
			if ferramentas.iniciar_foco(celula):
				_hud.definir_legenda("")
				if velocidade == 0.0:
					_hud.mostrar_mensagem("Foco aceso. A simulação está pausada (Espaço continua).")
			else:
				_hud.mostrar_mensagem("Aqui não pega fogo.")
		Ferramentas.Tipo.PIPA:
			if not ferramentas.usar_pipa(celula):
				_hud.mostrar_mensagem("O caminhão-pipa está sem cargas.")
		Ferramentas.Tipo.BRIGADA:
			if ferramentas.chamar_brigada(celula):
				_hud.mostrar_mensagem("Brigada acionada pelo 193. Chega em %d passos." % ferramentas.config.atraso_brigada)
			else:
				_hud.mostrar_mensagem("Não há mais chamadas de brigada nesta missão.")


func _on_arrasto(de: Vector2i, para: Vector2i) -> void:
	if _encerrada or roteiro != null or partida == null or ferramenta != Ferramentas.Tipo.ACEIRO:
		return
	if not ferramentas.pode_usar(Ferramentas.Tipo.ACEIRO):
		_hud.mostrar_mensagem("Orçamento esgotado: não dá para abrir mais aceiro.")
		return
	if ferramentas.abrir_aceiro(Ferramentas.linha_sem_furos(de, para)) > 0:
		_sons.aceiro()


func _alternar_som() -> void:
	_hud.definir_som(_sons.alternar())


func _on_pipa_usada(centro: Vector2i, _apagadas: int) -> void:
	_sons.tocar("agua")
	_mapa.veiculos.agua(centro, ferramentas.config.raio_pipa, _tempo, true)


func _on_brigada_chegou(centro: Vector2i, apagadas: int) -> void:
	_mapa.veiculos.agua(centro, ferramentas.config.raio_brigada, _tempo, false)
	_sons.tocar("agua", -3.0)
	if roteiro == null:
		_hud.mostrar_mensagem("A brigada chegou e apagou %d células em chamas." % apagadas)
