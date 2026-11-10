shader_type canvas_item;
// Desenha o mapa a partir da textura de dados (uma célula por texel, veja renderizador.gd):
//   R = tipo de terreno, G = estado, B = intensidade (fogo restante, brasa ou água), A = secura.
// Tudo o que é visual (textura do terreno, chama, brilho, cinzas, fumaça) é calculado aqui.

uniform sampler2D dados : filter_nearest;
uniform vec2 tamanho = vec2(128.0, 128.0);
// Para onde o vento sopra (vetor unitário em coordenadas de tela) e força de 0 a 1.
uniform vec2 vento = vec2(0.0, -1.0);
uniform float forca_vento = 0.3;

const vec3 CANA_VERDE = vec3(0.56, 0.66, 0.27);
const vec3 CANA_SECA = vec3(0.80, 0.71, 0.32);
const vec3 PASTO = vec3(0.85, 0.76, 0.48);
const vec3 PASTO_TUFO = vec3(0.72, 0.64, 0.36);
const vec3 MATA_ESCURA = vec3(0.10, 0.27, 0.12);
const vec3 MATA_CLARA = vec3(0.24, 0.50, 0.22);
const vec3 ESTRADA = vec3(0.54, 0.50, 0.44);
const vec3 AGUA = vec3(0.20, 0.42, 0.66);
const vec3 TELHADO = vec3(0.69, 0.23, 0.18);
const vec3 ACEIRO = vec3(0.87, 0.81, 0.70);
const vec3 CINZA = vec3(0.16, 0.15, 0.14);
const vec3 FUMACA = vec3(0.55, 0.53, 0.52);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * ruido(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

vec4 celula(vec2 pos) {
	ivec2 c = clamp(ivec2(floor(pos)), ivec2(0), ivec2(tamanho) - 1);
	return texelFetch(dados, c, 0);
}

// Quanto há de fogo em volta do ponto, interpolando as 4 células mais próximas (fumaça suave).
float fogo_suave(vec2 p) {
	vec2 q = p - 0.5;
	vec2 f = fract(q);
	vec2 b = floor(q) + 0.5;
	float a00 = round(celula(b).g * 255.0) == 1.0 ? 1.0 : 0.0;
	float a10 = round(celula(b + vec2(1.0, 0.0)).g * 255.0) == 1.0 ? 1.0 : 0.0;
	float a01 = round(celula(b + vec2(0.0, 1.0)).g * 255.0) == 1.0 ? 1.0 : 0.0;
	float a11 = round(celula(b + vec2(1.0, 1.0)).g * 255.0) == 1.0 ? 1.0 : 0.0;
	return mix(mix(a00, a10, f.x), mix(a01, a11, f.x), f.y);
}

int tipo_de(vec4 d) { return int(round(d.r * 255.0)); }
int estado_de(vec4 d) { return int(round(d.g * 255.0)); }

vec3 terreno(int tipo, vec2 pos, float secura) {
	float grao = ruido(pos * 6.0) * 0.12 - 0.06;
	if (tipo == 0) {
		// Cana: fileiras de plantio, mais verde ou mais amarela conforme a secura.
		float linhas = 0.5 + 0.5 * sin((pos.y * 3.0 + fbm(pos * 0.4) * 2.0) * 6.2832);
		vec3 base = mix(CANA_VERDE, CANA_SECA, clamp(secura * 1.3 - 0.1, 0.0, 1.0));
		return base * (0.86 + 0.16 * linhas) + grao;
	} else if (tipo == 1) {
		// Pasto seco: tufos espalhados.
		float tufo = step(0.78, hash(floor(pos * 4.0)));
		return mix(PASTO, PASTO_TUFO, tufo * 0.8) * (0.95 + fbm(pos * 0.7) * 0.1) + grao;
	} else if (tipo == 2) {
		// Mata: copas de árvores (manchas claras e escuras).
		float copa = fbm(pos * 1.6);
		float arvore = smoothstep(0.55, 0.15, length(fract(pos * 1.5) - vec2(hash(floor(pos * 1.5)) * 0.4 + 0.3)));
		return mix(MATA_ESCURA, MATA_CLARA, clamp(copa * 0.9 + arvore * 0.35, 0.0, 1.0));
	} else if (tipo == 3) {
		return ESTRADA * (0.92 + ruido(pos * 9.0) * 0.16);
	} else if (tipo == 4) {
		float onda = sin(pos.x * 2.5 + pos.y * 1.3 + TIME * 1.6 + fbm(pos * 0.8) * 4.0);
		return AGUA + vec3(0.07, 0.09, 0.1) * smoothstep(0.75, 1.0, onda);
	} else if (tipo == 5) {
		// Sede: telhado com fileiras de telhas.
		float telha = step(0.82, fract(pos.y * 4.0)) + step(0.9, fract(pos.x * 6.0 + floor(pos.y * 4.0) * 0.5));
		return TELHADO * (1.0 - 0.25 * clamp(telha, 0.0, 1.0));
	}
	// Aceiro: terra revolvida, com sulcos.
	float sulco = 0.5 + 0.5 * sin((pos.x + pos.y) * 9.0);
	return ACEIRO * (0.88 + 0.1 * sulco) + grao * 0.5;
}

vec3 chama(float intensidade, vec2 pos) {
	float n = fbm(pos * 2.2 - vec2(0.0, TIME * 2.6)) ;
	float calor = clamp(intensidade * 0.75 + n * 0.6, 0.0, 1.2);
	vec3 cor = mix(vec3(0.55, 0.06, 0.02), vec3(1.0, 0.42, 0.04), smoothstep(0.15, 0.6, calor));
	cor = mix(cor, vec3(1.0, 0.9, 0.45), smoothstep(0.7, 1.1, calor));
	return cor * (0.85 + 0.25 * sin(TIME * 17.0 + hash(floor(pos)) * 30.0));
}

void fragment() {
	vec2 pos = UV * tamanho;
	// Bordas orgânicas: a célula lida é deslocada um pouco por ruído.
	vec2 deslocado = pos + (vec2(ruido(pos * 0.9), ruido(pos * 0.9 + 17.0)) - 0.5) * 0.55;
	vec4 d = celula(deslocado);
	int tipo = tipo_de(d);
	int estado = estado_de(d);
	float valor = d.b;
	vec3 cor = terreno(tipo, pos, d.a);

	if (estado == 3) {
		// Molhada: tom azulado que some aos poucos.
		cor = mix(cor, vec3(0.32, 0.55, 0.85), 0.25 + 0.35 * valor);
		cor += vec3(0.25) * step(0.97, hash(floor(pos * 5.0) + floor(TIME * 3.0))) * valor;
	} else if (estado == 2) {
		float cinza = fbm(pos * 1.4);
		cor = mix(CINZA, CINZA * 1.9, cinza * 0.7);
		if (tipo == 5) {
			cor = mix(cor, vec3(0.3, 0.07, 0.05), 0.6);
		}
		// Brasas que se apagam aos poucos.
		float brasa = step(0.82, hash(floor(pos * 3.0)) ) * valor;
		cor += vec3(1.0, 0.35, 0.05) * brasa * (0.6 + 0.4 * sin(TIME * 6.0 + hash(floor(pos * 3.0)) * 40.0));
	} else if (estado == 1) {
		cor = chama(valor, pos);
	}

	// Brilho do fogo nas células vizinhas.
	float brilho = 0.0;
	for (int dy = -2; dy <= 2; dy++) {
		for (int dx = -2; dx <= 2; dx++) {
			vec4 v = celula(pos + vec2(float(dx), float(dy)));
			if (estado_de(v) == 1) {
				float dist = length(fract(pos) - 0.5 - vec2(float(dx), float(dy)));
				brilho += v.b * max(0.0, 1.0 - dist / 2.6);
			}
		}
	}
	if (estado != 1) {
		cor += vec3(0.55, 0.22, 0.03) * clamp(brilho * 0.35, 0.0, 0.7);
	}

	// Fumaça: vem das células em chamas do lado de onde sopra o vento.
	vec2 dir = vento * (0.6 + forca_vento * 1.6);
	float fumaca = 0.0;
	vec2 espalha = vec2(-dir.y, dir.x);
	for (int k = 1; k <= 8; k++) {
		// A pluma abre um pouco conforme se afasta do fogo.
		float abertura = (ruido(pos * 0.7 + float(k) * 3.1 - vento * TIME) - 0.5) * float(k) * 0.35;
		vec2 origem = pos - dir * float(k) * 1.3 + espalha * abertura;
		fumaca += fogo_suave(origem) * (1.0 - float(k) / 9.0) * 0.4;
	}
	float textura_fumaca = fbm(pos * 0.55 - vento * TIME * (0.8 + forca_vento * 2.0));
	fumaca = clamp(fumaca * (0.45 + textura_fumaca), 0.0, 0.72);
	cor = mix(cor, FUMACA, fumaca);

	COLOR = vec4(cor, 1.0);
}
