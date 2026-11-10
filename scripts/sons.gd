class_name Sons
extends Node
## Sons do jogo, todos gerados por código (sem arquivos de áudio): estalos de fogo e vento em
## laço, com volume conforme o incêndio e o vento, e efeitos curtos (água, sirene, aceiro, alerta,
## vitória, derrota, clique). M liga e desliga o som.

const TAXA := 22050
const PLAYERS_EFEITO := 5

var ligado := true

var _fogo: AudioStreamPlayer
var _vento: AudioStreamPlayer
var _efeitos: Array[AudioStreamPlayer] = []
var _proximo := 0
var _sons := {}
var _rng := RandomNumberGenerator.new()
var _ultimo_aceiro := 0


func _ready() -> void:
	_rng.seed = 7
	_sons["agua"] = _wav(_agua())
	_sons["sirene"] = _wav(_sirene())
	_sons["aceiro"] = _wav(_aceiro())
	_sons["alerta"] = _wav(_alerta())
	_sons["vitoria"] = _wav(_melodia([523.25, 659.25, 783.99, 1046.5], 0.13, 0.5))
	_sons["derrota"] = _wav(_melodia([392.0, 349.23, 311.13, 261.63], 0.2, 0.6))
	_sons["estrela"] = _wav(_melodia([1318.5], 0.05, 0.35))
	_sons["clique"] = _wav(_melodia([880.0], 0.01, 0.05))
	_sons["ignicao"] = _wav(_ignicao())
	_fogo = _laco(_crepitar(), -80.0)
	_vento = _laco(_vento_som(), -80.0)
	for i in PLAYERS_EFEITO:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_efeitos.append(p)


func tocar(nome: String, volume_db: float = 0.0) -> void:
	if not ligado or not _sons.has(nome):
		return
	var p := _efeitos[_proximo]
	_proximo = (_proximo + 1) % _efeitos.size()
	p.stream = _sons[nome]
	p.volume_db = volume_db
	p.play()


## Som de arrastar o aceiro, no máximo a cada 120 ms.
func aceiro() -> void:
	var agora := Time.get_ticks_msec()
	if agora - _ultimo_aceiro > 120:
		_ultimo_aceiro = agora
		tocar("aceiro", -8.0)


## Volume dos laços: `celulas_fogo` em chamas e vento em km/h (0 desliga o vento).
func ambiente(celulas_fogo: int, vento_kmh: float, delta: float) -> void:
	var alvo_fogo := -80.0 if celulas_fogo <= 0 or not ligado else lerpf(-26.0, -4.0, clampf(log(1.0 + celulas_fogo) / log(800.0), 0.0, 1.0))
	var alvo_vento := -80.0 if vento_kmh <= 0.0 or not ligado else lerpf(-30.0, -12.0, clampf(vento_kmh / 40.0, 0.0, 1.0))
	_fogo.volume_db = move_toward(_fogo.volume_db, alvo_fogo, delta * 40.0)
	_vento.volume_db = move_toward(_vento.volume_db, alvo_vento, delta * 30.0)


func alternar() -> bool:
	ligado = not ligado
	if not ligado:
		for p in _efeitos:
			p.stop()
	return ligado


# --- Geração ----------------------------------------------------------------------------------

func _laco(amostras: PackedFloat32Array, volume: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var w := _wav(amostras)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = amostras.size()
	p.stream = w
	p.volume_db = volume
	add_child(p)
	p.play()
	return p


func _wav(amostras: PackedFloat32Array) -> AudioStreamWAV:
	var dados := PackedByteArray()
	dados.resize(amostras.size() * 2)
	for i in amostras.size():
		dados.encode_s16(i * 2, int(clampf(amostras[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.stereo = false
	w.data = dados
	return w


func _vazio(segundos: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(segundos * TAXA))
	return a


## Mistura o fim com o começo, para o laço não estalar na emenda.
func _emendar(a: PackedFloat32Array, segundos: float) -> PackedFloat32Array:
	var n := int(segundos * TAXA)
	var total := a.size() - n
	var b := a.slice(0, total)
	for i in n:
		var t := float(i) / n
		b[i] = a[i] * t + a[total + i] * (1.0 - t)
	return b


func _crepitar() -> PackedFloat32Array:
	var a := _vazio(3.2)
	var grave := 0.0
	for i in a.size():
		grave = grave * 0.985 + _rng.randf_range(-1.0, 1.0) * 0.015
		a[i] = grave * 2.2
	# Estalos: pequenos pulsos que somem rápido.
	for k in 260:
		var inicio := _rng.randi_range(0, a.size() - 400)
		var forca := _rng.randf_range(0.15, 0.9) * (1.0 if _rng.randf() < 0.8 else 1.6)
		var dur := _rng.randi_range(40, 300)
		for j in dur:
			a[inicio + j] += _rng.randf_range(-1.0, 1.0) * forca * exp(-6.0 * j / dur)
	for i in a.size():
		a[i] *= 0.6
	return _emendar(a, 0.2)


func _vento_som() -> PackedFloat32Array:
	var a := _vazio(5.2)
	var f1 := 0.0
	var f2 := 0.0
	for i in a.size():
		var t := float(i) / TAXA
		f1 = f1 * 0.995 + _rng.randf_range(-1.0, 1.0) * 0.005
		f2 = f2 * 0.97 + f1 * 0.03
		a[i] = f2 * 7.0 * (0.6 + 0.4 * sin(t * 1.3) * sin(t * 0.7 + 1.0))
	return _emendar(a, 0.4)


func _agua() -> PackedFloat32Array:
	var a := _vazio(1.3)
	var f := 0.0
	for i in a.size():
		var t := float(i) / a.size()
		var r := _rng.randf_range(-1.0, 1.0)
		f = f * 0.6 + r * 0.4
		var env := minf(t * 12.0, 1.0) * pow(1.0 - t, 1.6)
		a[i] = (r - f) * 0.7 * env
	return a


func _sirene() -> PackedFloat32Array:
	var a := _vazio(2.4)
	var fase := 0.0
	for i in a.size():
		var t := float(i) / TAXA
		var freq := 700.0 + 450.0 * (0.5 + 0.5 * sin(t * TAU * 0.85 - PI / 2.0))
		fase += TAU * freq / TAXA
		var env := minf(t * 8.0, 1.0) * minf((2.4 - t) * 4.0, 1.0)
		a[i] = (sin(fase) * 0.5 + sin(fase * 2.0) * 0.15 + sin(fase * 3.0) * 0.08) * env * 0.55
	return a


func _aceiro() -> PackedFloat32Array:
	var a := _vazio(0.12)
	var f := 0.0
	for i in a.size():
		var t := float(i) / a.size()
		f = f * 0.8 + _rng.randf_range(-1.0, 1.0) * 0.2
		a[i] = f * 1.4 * sin(t * PI)
	return a


func _alerta() -> PackedFloat32Array:
	var a := _vazio(0.5)
	for i in a.size():
		var t := float(i) / TAXA
		var bipe := 1.0 if (t < 0.18 or (t > 0.26 and t < 0.44)) else 0.0
		a[i] = sin(t * TAU * 988.0) * 0.4 * bipe
	return a


func _ignicao() -> PackedFloat32Array:
	var a := _vazio(1.0)
	var f := 0.0
	for i in a.size():
		var t := float(i) / a.size()
		f = f * 0.9 + _rng.randf_range(-1.0, 1.0) * 0.1
		a[i] = f * 3.0 * minf(t * 4.0, 1.0) * (1.0 - t)
	return a


func _melodia(notas: Array, duracao_nota: float, cauda: float) -> PackedFloat32Array:
	var a := _vazio(duracao_nota * notas.size() + cauda)
	for k in notas.size():
		var inicio := int(k * duracao_nota * TAXA)
		var n := a.size() - inicio
		for j in n:
			var t := float(j) / TAXA
			var env := minf(t * 200.0, 1.0) * exp(-t * 5.0)
			a[inicio + j] += (sin(TAU * notas[k] * t) + 0.3 * sin(TAU * notas[k] * 2.0 * t)) * env * 0.3
	return a
