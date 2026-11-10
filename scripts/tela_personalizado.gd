class_name TelaPersonalizado
extends Control
## Modo personalizado: o jogador escolhe o mapa (exemplo, aleatório, imagem enviada ou mapa real
## de satélite), o clima, a dificuldade e o modo (missão com fogo surpresa ou livre).
## Clicar na prévia marca a sede.

signal jogar_pedido(missao: Missao)
signal voltar_pedido

enum Fonte { EXEMPLO, ALEATORIO, ARQUIVO, REAL }

## Cenários de clima: nome, temperatura, umidade, vento, de onde vem.
const CLIMAS := [
	["Hoje em Araraquara (real)", 0.0, 0.0, 0.0, 0.0],
	["Dia comum", 28.0, 45.0, 10.0, 90.0],
	["Dia seco", 33.0, 22.0, 18.0, 45.0],
	["Dia crítico (agosto)", 36.0, 15.0, 30.0, 315.0],
]
const DIFICULDADES := ["Fácil", "Normal", "Difícil"]
## Locais prontos para o mapa real (latitude, longitude).
const LOCAIS := [
	["Zona rural, sudoeste de Araraquara", -21.8602, -48.2558],
	["Horto Florestal de Araraquara", -21.7712, -48.1528],
	["Cana e mata, norte (Bueno de Andrada)", -21.7064, -48.1983],
	["Usina e canaviais, Américo Brasiliense", -21.7294, -48.0987],
]

## Mínimo de células de cana ou pasto para jogar no modo Missão.
const MIN_VEGETACAO_MISSAO := 400

var config: SimulacaoConfig

var _fonte := Fonte.EXEMPLO
var _clima := 0
var _dificuldade := 1
var _livre := false
var _leitura: LeituraClima
## Grade escolhida (sem a sede marcada pelo jogador) e a que vai para o jogo.
var _grade_base: Grade
var _grade: Grade
var _sede_marcada := Vector2i(-1, -1)
var _foto: Image
var _ver_foto := false
var _creditos := ""

var _previa: TextureRect
var _lbl_info: Label
var _lbl_creditos: Label
var _btn_ver_foto: Button
var _opcoes_fonte: VBoxContainer
var _spin_semente: SpinBox
var _edit_busca: LineEdit
var _edit_lat: LineEdit
var _edit_lon: LineEdit
var _lbl_status_real: Label
var _btn_baixar: Button
var _btn_jogar: Button
var _paineis_fonte: Array[Control] = []
var _mapa_real: MapaReal
var _dialogo: FileDialog
var _callback_web: JavaScriptObject


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ui.fundo(self)
	_mapa_real = MapaReal.new()
	add_child(_mapa_real)
	_mapa_real.lugar_encontrado.connect(_on_lugar)
	_mapa_real.mapa_pronto.connect(_on_mapa_real)
	_mapa_real.andamento.connect(func(t: String) -> void: _lbl_status_real.text = t)
	_mapa_real.falhou.connect(func(t: String) -> void:
		_lbl_status_real.text = t
		_btn_baixar.disabled = false)

	var topo := HBoxContainer.new()
	topo.anchor_right = 1.0
	topo.offset_left = 48
	topo.offset_right = -48
	topo.offset_top = 32
	topo.add_theme_constant_override("separation", 24)
	add_child(topo)
	topo.add_child(Ui.botao("‹ Menu", voltar_pedido.emit, 22))
	var titulo := Ui.label("MODO PERSONALIZADO", 40, Ui.COR_DESTAQUE)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(titulo)

	# Coluna de opções.
	var lado := PanelContainer.new()
	lado.anchor_bottom = 1.0
	lado.offset_left = 48
	lado.offset_right = 48 + 900
	lado.offset_top = 120
	lado.offset_bottom = -48
	add_child(lado)
	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lado.add_child(rolagem)
	var caixa := VBoxContainer.new()
	caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caixa.add_theme_constant_override("separation", 8)
	rolagem.add_child(caixa)

	Ui.titulo_secao(caixa, "MAPA")
	caixa.add_child(_grupo(["Exemplo", "Aleatório", "Enviar imagem", "Mapa real (satélite)"], 0, _escolher_fonte))
	_opcoes_fonte = VBoxContainer.new()
	caixa.add_child(_opcoes_fonte)
	_montar_opcoes_fonte()

	Ui.titulo_secao(caixa, "CLIMA")
	var nomes_clima: Array[String] = []
	for c: Array in CLIMAS:
		nomes_clima.append(c[0])
	caixa.add_child(_grupo(nomes_clima, 0, func(i: int) -> void: _clima = i))

	Ui.titulo_secao(caixa, "DIFICULDADE")
	caixa.add_child(_grupo(DIFICULDADES, 1, func(i: int) -> void: _dificuldade = i))
	caixa.add_child(Ui.label("Fácil: mais recursos e 1 foco. Normal: 3 zonas de risco. Difícil: 2 focos, um foco surpresa, brigada atrasada e menos dinheiro.", 17, Ui.COR_SUAVE))

	Ui.titulo_secao(caixa, "MODO")
	caixa.add_child(_grupo(["Missão (fogo surpresa, com estrelas)", "Livre (você acende o fogo)"], 0,
			func(i: int) -> void: _livre = i == 1))
	caixa.add_child(Ui.espaco(10))
	_btn_jogar = Ui.botao_principal("Jogar", _jogar, 30)
	_btn_jogar.custom_minimum_size = Vector2(0, 80)
	caixa.add_child(_btn_jogar)

	# Prévia do mapa.
	var direita := VBoxContainer.new()
	direita.anchor_left = 0.0
	direita.anchor_right = 1.0
	direita.anchor_bottom = 1.0
	direita.offset_left = 48 + 900 + 40
	direita.offset_right = -48
	direita.offset_top = 120
	direita.offset_bottom = -48
	direita.add_theme_constant_override("separation", 8)
	add_child(direita)
	var linha := HBoxContainer.new()
	var titulo_previa := Ui.label("PRÉVIA (clique para marcar a sede)", 18, Ui.COR_DESTAQUE)
	titulo_previa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(titulo_previa)
	_btn_ver_foto = Ui.botao("Ver imagem original", _alternar_foto, 17)
	_btn_ver_foto.visible = false
	linha.add_child(_btn_ver_foto)
	direita.add_child(linha)
	_previa = TextureRect.new()
	_previa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_previa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_previa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_previa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_previa.mouse_filter = Control.MOUSE_FILTER_STOP
	_previa.gui_input.connect(_on_previa_input)
	direita.add_child(_previa)
	_lbl_info = Ui.label("", 17, Ui.COR_SUAVE)
	direita.add_child(_lbl_info)
	_lbl_creditos = Ui.label("", 14, Ui.COR_SUAVE)
	direita.add_child(_lbl_creditos)

	_escolher_fonte(0)


func receber_clima(leitura: LeituraClima) -> void:
	_leitura = leitura


## Arquivos arrastados para a janela (desktop): o primeiro PNG/JPG vira o mapa.
func receber_arquivos(arquivos: PackedStringArray) -> void:
	if not visible:
		return
	for caminho in arquivos:
		if caminho.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"] and not "secura" in caminho.get_file():
			_carregar_arquivo(caminho)
			return


# --- Fontes de mapa ------------------------------------------------------------------------

func _montar_opcoes_fonte() -> void:
	# Exemplo.
	var exemplo := Ui.label("Fazenda de exemplo com cana, pasto, mata ciliar, córrego, estrada e sede.", 18, Ui.COR_SUAVE)
	# Aleatório.
	var aleatorio := HBoxContainer.new()
	aleatorio.add_child(Ui.rotulo("Semente do mapa:", 18))
	_spin_semente = SpinBox.new()
	_spin_semente.max_value = 99999
	_spin_semente.value = 7
	_spin_semente.value_changed.connect(func(_v: float) -> void: _gerar_aleatorio())
	aleatorio.add_child(_spin_semente)
	aleatorio.add_child(Ui.botao("Sortear outro", func() -> void: _spin_semente.value = randi() % 99999, 18))
	# Arquivo.
	var arquivo := VBoxContainer.new()
	arquivo.add_child(Ui.label("Envie um PNG na paleta do jogo (gerado pelo ferramentas/converter_mapa.py a partir do drone) ou uma foto aérea comum, que o jogo classifica pela cor. No computador, também dá para arrastar o arquivo para a janela.", 17, Ui.COR_SUAVE))
	var botoes_arquivo := HBoxContainer.new()
	botoes_arquivo.add_child(Ui.botao("Escolher imagem…", _escolher_arquivo.bind(false), 18))
	botoes_arquivo.add_child(Ui.botao("Camada de secura (opcional)…", _escolher_arquivo.bind(true), 18))
	arquivo.add_child(botoes_arquivo)
	# Mapa real.
	var real := VBoxContainer.new()
	real.add_child(Ui.label("Um quadrado de 1,28 km × 1,28 km de qualquer lugar do Brasil (10 m por célula). A foto de satélite é classificada pela cor e as estradas, rios e construções vêm do OpenStreetMap. A precisão é menor que a do drone.", 17, Ui.COR_SUAVE))
	var locais := HBoxContainer.new()
	var escolha_local := OptionButton.new()
	escolha_local.add_item("Lugares prontos…")
	for l: Array in LOCAIS:
		escolha_local.add_item(l[0])
	escolha_local.item_selected.connect(func(i: int) -> void:
		if i > 0:
			_edit_lat.text = str(LOCAIS[i - 1][1])
			_edit_lon.text = str(LOCAIS[i - 1][2])
			_baixar_real())
	escolha_local.focus_mode = Control.FOCUS_NONE
	locais.add_child(escolha_local)
	real.add_child(locais)
	var busca := HBoxContainer.new()
	_edit_busca = LineEdit.new()
	_edit_busca.placeholder_text = "Buscar lugar (ex.: Fazenda tal, Araraquara)"
	_edit_busca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_busca.text_submitted.connect(func(t: String) -> void: _mapa_real.buscar_lugar(t))
	busca.add_child(_edit_busca)
	busca.add_child(Ui.botao("Buscar", func() -> void: _mapa_real.buscar_lugar(_edit_busca.text), 18))
	real.add_child(busca)
	var coordenadas := HBoxContainer.new()
	coordenadas.add_child(Ui.rotulo("Lat.", 18))
	_edit_lat = LineEdit.new()
	_edit_lat.text = str(LOCAIS[0][1])
	_edit_lat.custom_minimum_size = Vector2(150, 0)
	coordenadas.add_child(_edit_lat)
	coordenadas.add_child(Ui.rotulo("Lon.", 18))
	_edit_lon = LineEdit.new()
	_edit_lon.text = str(LOCAIS[0][2])
	_edit_lon.custom_minimum_size = Vector2(150, 0)
	coordenadas.add_child(_edit_lon)
	_btn_baixar = Ui.botao_principal("Baixar mapa", _baixar_real, 20)
	coordenadas.add_child(_btn_baixar)
	real.add_child(coordenadas)
	var mover := HBoxContainer.new()
	mover.add_child(Ui.rotulo("Mover 1 km:", 18))
	for d: Array in [["N", Vector2(0, 1)], ["S", Vector2(0, -1)], ["O", Vector2(-1, 0)], ["L", Vector2(1, 0)]]:
		mover.add_child(Ui.botao(d[0], _mover.bind(d[1]), 18))
	real.add_child(mover)
	_lbl_status_real = Ui.label("Escolha um lugar e clique em \"Baixar mapa\".", 17, Ui.COR_SUAVE)
	real.add_child(_lbl_status_real)

	_paineis_fonte = [exemplo, aleatorio, arquivo, real]
	for p in _paineis_fonte:
		_opcoes_fonte.add_child(p)


func _escolher_fonte(i: int) -> void:
	_fonte = i as Fonte
	for k in _paineis_fonte.size():
		_paineis_fonte[k].visible = k == i
	_foto = null
	_ver_foto = false
	_creditos = ""
	match _fonte:
		Fonte.EXEMPLO:
			var img_t := Grade.carregar_imagem(config.mapa_terreno)
			_definir_grade(Grade.de_imagens(img_t, Grade.carregar_imagem(config.mapa_secura), config.largura, config.altura),
					"Mapa de exemplo (8 m por célula).")
		Fonte.ALEATORIO:
			_gerar_aleatorio()
		Fonte.ARQUIVO:
			_definir_grade(null, "Nenhuma imagem enviada ainda.")
		Fonte.REAL:
			_definir_grade(null, "Nenhum mapa baixado ainda.")


func _gerar_aleatorio() -> void:
	if _fonte == Fonte.ALEATORIO:
		_definir_grade(GeradorMapa.gerar(config.largura, config.altura, int(_spin_semente.value)),
				"Mapa aleatório, semente %d (8 m por célula)." % int(_spin_semente.value))


func _definir_grade(g: Grade, info: String) -> void:
	_grade_base = g
	_sede_marcada = Vector2i(-1, -1)
	_lbl_info.text = info
	_lbl_creditos.text = _creditos
	_btn_ver_foto.visible = _foto != null
	_atualizar_previa()


func _atualizar_previa() -> void:
	_grade = null
	if _grade_base != null:
		_grade = _grade_base.copiar()
		if _sede_marcada.x >= 0:
			for dy in range(-2, 2):
				for dx in range(-3, 3):
					var c := _sede_marcada + Vector2i(dx, dy)
					if _grade.contem(c):
						_grade.terreno[_grade.indice(c)] = Terreno.Tipo.SEDE
			_grade.fixar_original()
	_btn_jogar.disabled = _grade == null
	if _ver_foto and _foto != null:
		_previa.texture = ImageTexture.create_from_image(_foto)
		_btn_ver_foto.text = "Ver mapa do jogo"
	elif _grade != null:
		_previa.texture = ImageTexture.create_from_image(_grade.para_imagem_terreno())
		_btn_ver_foto.text = "Ver imagem original"
	else:
		_previa.texture = null
	var sem_sede := _grade != null and not Missao.tem_sede(_grade)
	if sem_sede:
		_lbl_info.text = _lbl_info.text.split("\n")[0] + "\nNenhuma sede no mapa: clique na prévia para marcar onde ela fica."


func _alternar_foto() -> void:
	_ver_foto = not _ver_foto
	_atualizar_previa()


func _on_previa_input(event: InputEvent) -> void:
	if _grade_base == null or not event is InputEventMouseButton:
		return
	var botao := event as InputEventMouseButton
	if not botao.pressed or botao.button_index != MOUSE_BUTTON_LEFT:
		return
	# Área onde a textura é desenhada (mantendo a proporção).
	var lado := minf(_previa.size.x, _previa.size.y)
	var origem := (_previa.size - Vector2(lado, lado)) / 2.0
	var rel := (botao.position - origem) / lado
	if rel.x < 0.0 or rel.y < 0.0 or rel.x >= 1.0 or rel.y >= 1.0:
		return
	_sede_marcada = Vector2i(int(rel.x * _grade_base.largura), int(rel.y * _grade_base.altura))
	_ver_foto = false
	_atualizar_previa()
	_lbl_info.text = _lbl_info.text.split("\n")[0] + "\nSede marcada em (%d, %d)." % [_sede_marcada.x, _sede_marcada.y]


# --- Mapa real ------------------------------------------------------------------------------

func _baixar_real() -> void:
	if _mapa_real.ocupado():
		return
	var lat := _edit_lat.text.replace(",", ".").to_float()
	var lon := _edit_lon.text.replace(",", ".").to_float()
	if absf(lat) < 0.001 or absf(lon) < 0.001:
		_lbl_status_real.text = "Coordenadas inválidas."
		return
	_btn_baixar.disabled = true
	_mapa_real.lado_celulas = config.largura
	_mapa_real.baixar(lat, lon)


func _mover(direcao: Vector2) -> void:
	var lat := _edit_lat.text.replace(",", ".").to_float()
	var lon := _edit_lon.text.replace(",", ".").to_float()
	lat += direcao.y * 1000.0 / 111320.0
	lon += direcao.x * 1000.0 / (111320.0 * cos(deg_to_rad(lat)))
	_edit_lat.text = "%.5f" % lat
	_edit_lon.text = "%.5f" % lon
	_baixar_real()


func _on_lugar(lat: float, lon: float, nome: String) -> void:
	_edit_lat.text = "%.5f" % lat
	_edit_lon.text = "%.5f" % lon
	_lbl_status_real.text = "Encontrado: " + nome
	_baixar_real()


func _on_mapa_real(g: Grade, foto: Image) -> void:
	_btn_baixar.disabled = false
	if _fonte != Fonte.REAL:
		return
	_foto = foto
	_creditos = MapaReal.CREDITOS
	_definir_grade(g, "Mapa real em %s, %s (10 m por célula). Classificação aproximada por cor." % [_edit_lat.text, _edit_lon.text])


# --- Imagem enviada -------------------------------------------------------------------------

func _escolher_arquivo(secura: bool) -> void:
	if OS.has_feature("web"):
		_escolher_arquivo_web(secura)
		return
	if _dialogo == null:
		_dialogo = FileDialog.new()
		_dialogo.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialogo.access = FileDialog.ACCESS_FILESYSTEM
		_dialogo.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Imagens"])
		_dialogo.use_native_dialog = true
		add_child(_dialogo)
	for c in _dialogo.file_selected.get_connections():
		_dialogo.file_selected.disconnect(c["callable"])
	_dialogo.title = "Camada de secura (tons de cinza)" if secura else "Mapa de terreno ou foto aérea"
	_dialogo.file_selected.connect(_carregar_secura if secura else _carregar_arquivo)
	_dialogo.popup_centered_ratio(0.6)


func _carregar_arquivo(caminho: String) -> void:
	var img := Image.load_from_file(caminho)
	if img == null:
		_lbl_info.text = "Não foi possível abrir " + caminho.get_file()
		return
	_usar_imagem(img, caminho.get_file())
	# Mapa na paleta com um "..._secura.png" ao lado: usa como camada de secura.
	var caminho_secura := caminho.get_base_dir().path_join(caminho.get_file().replace("terreno", "secura"))
	if caminho_secura != caminho and FileAccess.file_exists(caminho_secura):
		_carregar_secura(caminho_secura)


func _carregar_secura(caminho: String) -> void:
	var img := Image.load_from_file(caminho)
	if img != null:
		_usar_secura(img, caminho.get_file())


func _usar_imagem(img: Image, nome: String) -> void:
	if _fonte != Fonte.ARQUIVO:
		return
	_foto = null
	_creditos = ""
	if ClassificadorFoto.eh_paleta(img):
		_definir_grade(Grade.de_imagens(img, null, config.largura, config.altura),
				"%s: mapa na paleta do jogo (%d×%d px)." % [nome, img.get_width(), img.get_height()])
	else:
		_foto = ClassificadorFoto.reduzir(img, 512)
		_definir_grade(ClassificadorFoto.classificar(ClassificadorFoto.reduzir(img, config.largura)),
				"%s: foto classificada automaticamente pela cor (aproximado)." % nome)


func _usar_secura(img: Image, nome: String) -> void:
	if _grade_base == null:
		_lbl_info.text = "Envie primeiro o mapa de terreno."
		return
	var s := img.duplicate() as Image
	if s.is_compressed():
		s.decompress()
	s.convert(Image.FORMAT_L8)
	s.resize(_grade_base.largura, _grade_base.altura, Image.INTERPOLATE_BILINEAR)
	_grade_base.secura = s.get_data()
	_lbl_info.text = _lbl_info.text.split("\n")[0] + "\nSecura: " + nome
	_atualizar_previa()


## No navegador não há acesso ao disco: um <input type="file"> lê o arquivo e devolve em base64.
func _escolher_arquivo_web(secura: bool) -> void:
	_callback_web = JavaScriptBridge.create_callback(_on_arquivo_web.bind(secura))
	var janela := JavaScriptBridge.get_interface("window")
	janela.fogoZeroArquivo = _callback_web
	JavaScriptBridge.eval("""
		(function () {
			var entrada = document.createElement('input');
			entrada.type = 'file';
			entrada.accept = 'image/png,image/jpeg,image/webp';
			entrada.onchange = function () {
				var arquivo = entrada.files[0];
				if (!arquivo) return;
				var leitor = new FileReader();
				leitor.onload = function () {
					var bytes = new Uint8Array(leitor.result);
					var texto = '';
					for (var i = 0; i < bytes.length; i += 8192) {
						texto += String.fromCharCode.apply(null, bytes.subarray(i, i + 8192));
					}
					window.fogoZeroArquivo(arquivo.name, btoa(texto));
				};
				leitor.readAsArrayBuffer(arquivo);
			};
			entrada.click();
		})();
	""", true)


func _on_arquivo_web(argumentos: Array, secura: bool) -> void:
	var nome := str(argumentos[0])
	var bytes := Marshalls.base64_to_raw(str(argumentos[1]))
	var img := Image.new()
	var erro := img.load_png_from_buffer(bytes)
	if erro != OK:
		erro = img.load_jpg_from_buffer(bytes)
	if erro != OK:
		erro = img.load_webp_from_buffer(bytes)
	if erro != OK:
		_lbl_info.text = "Não foi possível ler " + nome
		return
	if secura:
		_usar_secura(img, nome)
	else:
		_usar_imagem(img, nome)


# --- Jogar -----------------------------------------------------------------------------------

func _jogar() -> void:
	if _grade == null:
		return
	if not _livre:
		# O fogo da missão começa em cana ou pasto: sem isso não há incêndio para enfrentar.
		var vegetacao := _grade.terreno.count(Terreno.Tipo.CANA) + _grade.terreno.count(Terreno.Tipo.PASTO)
		if vegetacao < MIN_VEGETACAO_MISSAO:
			_lbl_info.text = _lbl_info.text.split("\n")[0] + "\nEste mapa quase não tem cana ou pasto para o fogo começar. Escolha outro lugar ou use o modo Livre."
			return
	var m := Missao.new()
	m.id = "personalizado"
	m.numero = 0
	m.nome = "Personalizado"
	m.mapa = Missao.Mapa.GRADE
	m.grade_pronta = _grade
	m.metros_por_celula = 10.0 if _fonte == Fonte.REAL else 0.0
	m.creditos = _creditos
	m.semente = randi() % 100000
	m.foco_livre = _livre
	var c: Array = CLIMAS[_clima]
	m.clima_real = _clima == 0
	if m.clima_real and _leitura != null:
		m.temperatura = _leitura.temperatura
		m.umidade = _leitura.umidade
		m.vento_kmh = _leitura.vento_kmh
		m.vento_direcao = _leitura.vento_direcao
	elif not m.clima_real:
		m.temperatura = c[1]
		m.umidade = c[2]
		m.vento_kmh = c[3]
		m.vento_direcao = c[4]
	match _dificuldade:
		0:
			m.orcamento = 1600
			m.cargas_pipa = 4
			m.chamadas_brigada = 2
			m.candidatos = 2
			m.ameaca = 0.3
		1:
			m.orcamento = 1300
			m.candidatos = 3
			m.ameaca = 0.6
		2:
			m.orcamento = 1000
			m.cargas_pipa = 2
			m.atraso_brigada = 35
			m.candidatos = 4
			m.focos_iniciais = 2
			m.focos_extras = [30]
			m.ameaca = 0.85
			m.raio_risco = 11
	jogar_pedido.emit(m)


func _grupo(nomes: Array, inicial: int, ao_escolher: Callable) -> HFlowContainer:
	var linha := HFlowContainer.new()
	var grupo := ButtonGroup.new()
	for i in nomes.size():
		var b := Ui.botao(nomes[i], ao_escolher.bind(i), 19)
		b.toggle_mode = true
		b.button_group = grupo
		b.button_pressed = i == inicial
		linha.add_child(b)
	return linha
