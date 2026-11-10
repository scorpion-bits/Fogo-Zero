class_name SimulacaoConfig
extends Resource
## Todas as constantes do protótipo. Para ajustar, abra recursos/simulacao_config.tres no
## Inspetor da Godot: não é preciso mexer no código.

@export_group("Identidade")
## Nome provisório do projeto, mostrado no HUD.
@export var nome_projeto: String = "Fogo Zero"

@export_group("Grade e mapa")
@export var largura: int = 128
@export var altura: int = 128
## Só informativo: usado para converter células em hectares nos textos.
@export var metros_por_celula: float = 8.0
@export_file("*.png") var mapa_terreno: String = "res://mapas/exemplo_terreno.png"
@export_file("*.png") var mapa_secura: String = "res://mapas/exemplo_secura.png"

@export_group("Tempo e semente")
## Passos da simulação por segundo na velocidade 1×.
@export var passos_por_segundo: float = 6.0
## Mesma semente + mesmas ações = mesmo resultado.
@export var semente: int = 2024

@export_group("Inflamabilidade base (p_base, chance por passo)")
@export_range(0.0, 1.0) var p_base_cana: float = 0.30
@export_range(0.0, 1.0) var p_base_pasto: float = 0.42
@export_range(0.0, 1.0) var p_base_mata: float = 0.13
@export_range(0.0, 1.0) var p_base_sede: float = 0.10
@export_range(0.0, 1.0) var p_base_estrada: float = 0.0
@export_range(0.0, 1.0) var p_base_agua: float = 0.0
@export_range(0.0, 1.0) var p_base_aceiro: float = 0.0

@export_group("Tempo de queima (passos)")
@export var queima_cana: int = 5
@export var queima_pasto: int = 3
@export var queima_mata: int = 12
@export var queima_sede: int = 14

@export_group("Fatores do modelo")
## Expoente da umidade: f_umidade = clamp((1 - UR/100)^k, f_umidade_min, 1).
@export var k_umidade: float = 2.0
@export var f_umidade_min: float = 0.05
## Força do vento (por km/h): f_vento = exp(c × velocidade × cos(ângulo)).
@export var c_vento: float = 0.035
## Fator nas vizinhas diagonais (1/√2).
@export var fator_diagonal: float = 0.7071
## A secura 0..255 vira um fator entre estes dois valores (128 ≈ 1,0).
@export var secura_min: float = 0.5
@export var secura_max: float = 1.5
## Multiplica a chance de queima de uma célula molhada (inflamabilidade quase zero).
@export var fator_molhada: float = 0.02

@export_group("Clima padrão (modo offline)")
@export var temperatura_padrao: float = 30.0
@export var umidade_padrao: float = 35.0
@export var vento_padrao_kmh: float = 12.0
## De onde o vento vem, em graus (0 = norte, 90 = leste).
@export var direcao_vento_padrao: float = 90.0

@export_group("Clima real (Open-Meteo)")
@export var latitude: float = -21.7946
@export var longitude: float = -48.1756
@export var nome_local: String = "Araraquara-SP"
## Segundos entre atualizações automáticas.
@export var intervalo_clima: float = 900.0
@export var tempo_limite_clima: float = 10.0

@export_group("Índice de risco (simplificado, não oficial)")
@export var risco_peso_umidade: float = 0.5
@export var risco_peso_temperatura: float = 0.25
@export var risco_peso_vento: float = 0.25
@export var risco_temp_min: float = 15.0
@export var risco_temp_max: float = 40.0
@export var risco_vento_max: float = 40.0
@export var risco_limiar_medio: float = 0.35
@export var risco_limiar_alto: float = 0.55
@export var risco_limiar_critico: float = 0.75

@export_group("Recursos do jogador")
@export var orcamento: int = 1500
@export var custo_aceiro_celula: int = 5
@export var cargas_pipa: int = 3
@export var raio_pipa: int = 5
## Por quantos passos a célula fica molhada.
@export var passos_molhada: int = 45
@export var chamadas_brigada: int = 1
## Passos entre chamar o 193 e a brigada chegar.
@export var atraso_brigada: int = 25
@export var raio_brigada: int = 9

@export_group("Focos do INPE (opcional)")
@export var raio_focos_km: float = 50.0
@export var janela_focos_horas: float = 48.0

@export_group("Modo demonstração")
@export var semente_demo: int = 815
@export var passos_por_segundo_demo: float = 5.0
@export var temperatura_demo: float = 36.0
@export var umidade_demo: float = 15.0
@export var vento_demo_kmh: float = 30.0
@export var direcao_vento_demo: float = 315.0


func p_base(tipo: int) -> float:
	match tipo:
		Terreno.Tipo.CANA: return p_base_cana
		Terreno.Tipo.PASTO: return p_base_pasto
		Terreno.Tipo.MATA: return p_base_mata
		Terreno.Tipo.SEDE: return p_base_sede
		Terreno.Tipo.ESTRADA: return p_base_estrada
		Terreno.Tipo.AGUA: return p_base_agua
		Terreno.Tipo.ACEIRO: return p_base_aceiro
	return 0.0


func tempo_queima(tipo: int) -> int:
	match tipo:
		Terreno.Tipo.CANA: return queima_cana
		Terreno.Tipo.PASTO: return queima_pasto
		Terreno.Tipo.MATA: return queima_mata
		Terreno.Tipo.SEDE: return queima_sede
	return 1
