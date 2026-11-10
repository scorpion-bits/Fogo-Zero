extends Control
## Cena principal: junta o mapa, a simulação, as ferramentas, o clima, o HUD, a tela de
## resultado e o modo demonstração.
##
## Atalhos: 1–4 ferramentas · Espaço pausa · R reinicia · D demonstração.
## Para abrir direto na demonstração: godot --path . -- --demo

const DICA_INICIAL := "Escolha uma ferramenta e clique no mapa. Comece com um foco de incêndio (1)."

@export var config: SimulacaoConfig = preload("res://recursos/simulacao_config.tres")

var grade: Grade
var sim: SimulacaoFogo
var ferramentas: Ferramentas
var renderizador: Renderizador
var ferramenta := Ferramentas.Tipo.FOCO
var velocidade := 1.0
var semente := 0
var roteiro: RoteiroDemo = null

var _leitura: LeituraClima
var _manual := false
var _manual_valores := PackedFloat32Array([0, 0, 0, 0])
var _acumulador := 0.0
var _encerrada := false
var _tempo := 0.0
var _gravando_video := false
var _dialogo: FileDialog

@onready var _mapa: MapaView = $MapaView
@onready var _clima: ClimaApi = $ClimaApi
@onready var _hud: Hud = $HUD
@onready var _resultado: TelaResultado = $Resultado


func _ready() -> void:
	semente = config.semente
	_gravando_video = "--write-movie" in OS.get_cmdline_args()
	_leitura = LeituraClima.offline(config, "Buscando o clima de %s…" % config.nome_local)

	_hud.configurar(config)
	_hud.ferramenta_escolhida.connect(_escolher_ferramenta)
	_hud.velocidade_escolhida.connect(_escolher_velocidade)
	_hud.reiniciar_pedido.connect(_reiniciar_rodada)
	_hud.semente_alterada.connect(func(v: int) -> void:
		semente = v
		_reiniciar_rodada())
	_hud.mapa_exemplo_pedido.connect(_carregar_mapa_exemplo)
	_hud.mapa_aleatorio_pedido.connect(_carregar_mapa_aleatorio)
	_hud.abrir_mapa_pedido.connect(_abrir_dialogo)
	_hud.demo_pedida.connect(iniciar_demo)
	_hud.sair_demo_pedido.connect(_reiniciar_rodada)
	_hud.atualizar_clima_pedido.connect(_clima.atualizar)
	_hud.clima_manual_alterado.connect(_on_clima_manual)
	_hud.permitir_abrir_arquivo(not OS.has_feature("web"))
	_hud.definir_semente(semente)
	_hud.mostrar_focos(FocosInpe.resumo(config))

	_mapa.clique.connect(_on_clique)
	_mapa.arrasto.connect(_on_arrasto)
	_resultado.jogar_novamente.connect(_reiniciar_rodada)
	get_window().files_dropped.connect(_on_arquivos_soltos)

	_clima.leitura_recebida.connect(_on_clima)
	_clima.iniciar(config)

	_carregar_mapa_exemplo()
	if "--demo" in OS.get_cmdline_user_args():
		iniciar_demo()


func _process(delta: float) -> void:
	_tempo += delta
	if not _encerrada and velocidade > 0.0 and (sim.ha_fogo() or roteiro != null):
		var pps := config.passos_por_segundo_demo if roteiro != null else config.passos_por_segundo
		_acumulador += delta * pps * velocidade
		var passos := 0
		while _acumulador >= 1.0 and passos < 4 and not _encerrada:
			_passo()
			_acumulador -= 1.0
			passos += 1
		_acumulador = minf(_acumulador, 1.0)
	renderizador.atualizar(_tempo)
	_hud.mostrar_status(sim)
	_hud.mostrar_recursos(ferramentas)
	_mapa.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).keycode:
		KEY_1: _escolher_ferramenta(Ferramentas.Tipo.FOCO)
		KEY_2: _escolher_ferramenta(Ferramentas.Tipo.ACEIRO)
		KEY_3: _escolher_ferramenta(Ferramentas.Tipo.PIPA)
		KEY_4: _escolher_ferramenta(Ferramentas.Tipo.BRIGADA)
		KEY_SPACE: _escolher_velocidade(1.0 if velocidade == 0.0 else 0.0)
		KEY_R: _reiniciar_rodada()
		KEY_D: iniciar_demo()


# --- Rodada --------------------------------------------------------------------------------

func _passo() -> void:
	if roteiro != null:
		roteiro.antes_do_passo(sim, ferramentas)
		_hud.definir_legenda(roteiro.legenda)
	if sim.terminou():
		_encerrar()
		return
	sim.avancar()
	ferramentas.processar_passo()
	if sim.terminou():
		_encerrar()


func _encerrar() -> void:
	_encerrada = true
	var dados := Narrador.resumo(sim, ferramentas)
	if roteiro == null:
		_hud.definir_legenda("")
		_resultado.mostrar(dados)
		return
	roteiro.ao_terminar(sim)
	_hud.definir_legenda(roteiro.legenda)
	await get_tree().create_timer(2.5).timeout
	if roteiro == null:
		return
	_resultado.mostrar(dados)
	if _gravando_video:
		await get_tree().create_timer(5.0).timeout
		get_tree().quit()


func _montar(nova_grade: Grade) -> void:
	grade = nova_grade
	sim = SimulacaoFogo.new(config, grade)
	ferramentas = Ferramentas.new(config, sim)
	ferramentas.brigada_chegou.connect(_on_brigada_chegou)
	renderizador = Renderizador.new(sim)
	_mapa.configurar(sim, ferramentas, renderizador.textura)
	_reiniciar_rodada()


func _reiniciar_rodada() -> void:
	if roteiro != null:
		roteiro = null
		_hud.modo_demo(false)
		_mapa.interativo = true
	sim.reiniciar(semente)
	ferramentas.reiniciar()
	_aplicar_clima()
	renderizador.redesenhar_tudo()
	_encerrada = false
	_acumulador = 0.0
	_resultado.hide()
	_hud.definir_legenda(DICA_INICIAL)
	_escolher_ferramenta(Ferramentas.Tipo.FOCO)
	_escolher_velocidade(1.0)


func iniciar_demo() -> void:
	var g := _grade_exemplo()
	if g == null:
		return
	_montar(g)
	roteiro = RoteiroDemo.new(config)
	roteiro.preparar(sim)
	renderizador.redesenhar_tudo()
	_mapa.interativo = false
	_hud.modo_demo(true)
	_hud.definir_legenda("")
	_hud.mostrar_clima(_leitura, false, sim.temperatura, sim.umidade, sim.vento_kmh, sim.vento_direcao,
			"Cenário de demonstração: dia crítico", Color("#F28C28"))


# --- Clima ---------------------------------------------------------------------------------

func _on_clima(leitura: LeituraClima) -> void:
	_leitura = leitura
	_aplicar_clima()


func _on_clima_manual(ativo: bool, temperatura: float, umidade: float, vento: float, direcao: float) -> void:
	_manual = ativo
	_manual_valores = PackedFloat32Array([temperatura, umidade, vento, direcao])
	_aplicar_clima()


func _aplicar_clima() -> void:
	if roteiro != null or sim == null:
		return
	var modo: String
	var cor: Color
	var v: PackedFloat32Array
	if _manual:
		v = _manual_valores
		modo = "Modo manual (cenário)"
		cor = Color("#7FC8F8")
	else:
		v = PackedFloat32Array([_leitura.temperatura, _leitura.umidade, _leitura.vento_kmh, _leitura.vento_direcao])
		modo = _leitura.mensagem
		cor = Color("#6BCB5A") if _leitura.online else Color("#F2A541")
	sim.definir_clima(v[0], v[1], v[2], v[3])
	_hud.mostrar_clima(_leitura, not _manual and _leitura.online, v[0], v[1], v[2], v[3], modo, cor)


# --- Ferramentas ---------------------------------------------------------------------------

func _escolher_ferramenta(tipo: Ferramentas.Tipo) -> void:
	if roteiro != null:
		return
	ferramenta = tipo
	_mapa.ferramenta = tipo
	_hud.definir_ferramenta(tipo)


func _escolher_velocidade(valor: float) -> void:
	velocidade = valor
	_hud.definir_velocidade(valor)


func _on_clique(celula: Vector2i) -> void:
	if _encerrada or roteiro != null:
		return
	match ferramenta:
		Ferramentas.Tipo.FOCO:
			if ferramentas.iniciar_foco(celula):
				_hud.definir_legenda("")
				if velocidade == 0.0:
					_hud.mostrar_mensagem("Foco iniciado. A simulação está pausada (Espaço continua).")
			else:
				_hud.mostrar_mensagem("Aqui não pega fogo.")
		Ferramentas.Tipo.PIPA:
			if not ferramentas.usar_pipa(celula):
				_hud.mostrar_mensagem("O caminhão-pipa está sem cargas.")
		Ferramentas.Tipo.BRIGADA:
			if ferramentas.chamar_brigada(celula):
				_hud.mostrar_mensagem("Brigada acionada pelo 193. Chega em %d passos." % config.atraso_brigada)
			else:
				_hud.mostrar_mensagem("Não há mais chamadas de brigada nesta rodada.")


func _on_arrasto(de: Vector2i, para: Vector2i) -> void:
	if _encerrada or roteiro != null or ferramenta != Ferramentas.Tipo.ACEIRO:
		return
	if not ferramentas.pode_usar(Ferramentas.Tipo.ACEIRO):
		_hud.mostrar_mensagem("Orçamento esgotado: não dá para abrir mais aceiro.")
		return
	ferramentas.abrir_aceiro(Ferramentas.linha_sem_furos(de, para))


func _on_brigada_chegou(_centro: Vector2i, apagadas: int) -> void:
	if roteiro == null:
		_hud.mostrar_mensagem("A brigada chegou e apagou %d células em chamas." % apagadas)


# --- Mapas ---------------------------------------------------------------------------------

func _grade_exemplo() -> Grade:
	var img_t := Grade.carregar_imagem(config.mapa_terreno)
	if img_t == null:
		push_error("Mapa de exemplo não encontrado: " + config.mapa_terreno)
		return null
	return Grade.de_imagens(img_t, Grade.carregar_imagem(config.mapa_secura), config.largura, config.altura)


func _carregar_mapa_exemplo() -> void:
	var g := _grade_exemplo()
	if g != null:
		_montar(g)


func _carregar_mapa_aleatorio() -> void:
	_montar(GeradorMapa.gerar(config.largura, config.altura, randi() % 100000))
	_hud.mostrar_mensagem("Mapa aleatório gerado.")


## Carrega um PNG de terreno do disco. Se existir um arquivo "..._secura.png" ao lado (com o mesmo
## nome trocando "terreno" por "secura"), ele vira a camada de secura.
func carregar_mapa_arquivo(caminho: String) -> void:
	var img_t := Grade.carregar_imagem(caminho)
	if img_t == null:
		_hud.mostrar_mensagem("Não foi possível abrir " + caminho.get_file())
		return
	var img_s: Image = null
	var caminho_secura := caminho.get_base_dir().path_join(caminho.get_file().replace("terreno", "secura"))
	if caminho_secura != caminho:
		img_s = Grade.carregar_imagem(caminho_secura)
	_montar(Grade.de_imagens(img_t, img_s, config.largura, config.altura))
	_hud.mostrar_mensagem("Mapa carregado: %s%s" % [caminho.get_file(), " + secura" if img_s != null else ""], 4.0)


func _abrir_dialogo() -> void:
	if _dialogo == null:
		_dialogo = FileDialog.new()
		_dialogo.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialogo.access = FileDialog.ACCESS_FILESYSTEM
		_dialogo.filters = PackedStringArray(["*.png ; Mapa de terreno (PNG)"])
		_dialogo.title = "Abrir mapa de terreno (PNG com a paleta)"
		_dialogo.use_native_dialog = true
		_dialogo.file_selected.connect(carregar_mapa_arquivo)
		add_child(_dialogo)
	_dialogo.popup_centered_ratio(0.6)


func _on_arquivos_soltos(arquivos: PackedStringArray) -> void:
	for caminho in arquivos:
		if caminho.get_extension().to_lower() == "png" and not "secura" in caminho.get_file():
			carregar_mapa_arquivo(caminho)
			return
