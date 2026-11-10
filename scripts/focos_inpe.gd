class_name FocosInpe
## (Opcional) Lê um CSV de focos de calor do INPE (Programa Queimadas / BDQueimadas) baixado à mão
## e conta quantos focos houve nas últimas N horas num raio de X km de Araraquara.
##
## As "últimas N horas" são contadas a partir do registro mais recente do arquivo, porque o CSV é
## baixado manualmente e pode não ser de hoje.

const ARQUIVO_REAL := "res://dados/focos_inpe.csv"
const ARQUIVO_EXEMPLO := "res://dados/focos_exemplo_ficticio.csv"


## Texto para o HUD, ou "" se não houver CSV.
static func resumo(config: SimulacaoConfig) -> String:
	var caminho := ARQUIVO_REAL if FileAccess.file_exists(ARQUIVO_REAL) else ARQUIVO_EXEMPLO
	if not FileAccess.file_exists(caminho):
		return ""
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		return ""
	var col_lat := -1
	var col_lon := -1
	var col_data := -1
	var focos: Array[Vector2] = []  # (unix, distância km)
	while not arquivo.eof_reached():
		var linha := arquivo.get_csv_line()
		if linha.is_empty() or linha[0].begins_with("#") or (linha.size() == 1 and linha[0].strip_edges().is_empty()):
			continue
		if col_lat < 0:
			for i in linha.size():
				var nome := linha[i].strip_edges().to_lower()
				if nome in ["lat", "latitude"]:
					col_lat = i
				elif nome in ["lon", "longitude"]:
					col_lon = i
				elif nome in ["data_hora_gmt", "datahora", "data_hora", "data"]:
					col_data = i
			if col_lat < 0 or col_lon < 0 or col_data < 0:
				return "Focos INPE: colunas lat/lon/data não encontradas no CSV."
			continue
		if linha.size() <= maxi(col_lat, maxi(col_lon, col_data)):
			continue
		var quando := _unix(linha[col_data])
		if quando <= 0:
			continue
		var d := distancia_km(config.latitude, config.longitude, linha[col_lat].to_float(), linha[col_lon].to_float())
		focos.append(Vector2(quando, d))
	if focos.is_empty():
		return "Focos INPE: nenhum registro válido no CSV."
	var mais_recente := 0.0
	for f in focos:
		mais_recente = maxf(mais_recente, f.x)
	var limite := mais_recente - config.janela_focos_horas * 3600.0
	var total := 0
	for f in focos:
		if f.x >= limite and f.y <= config.raio_focos_km:
			total += 1
	var data := Time.get_datetime_dict_from_unix_time(int(mais_recente))
	var texto := "Focos INPE: %d nas %d h até %02d/%02d/%d %02d:%02d UTC, num raio de %d km." % [
		total, roundi(config.janela_focos_horas), data["day"], data["month"], data["year"],
		data["hour"], data["minute"], roundi(config.raio_focos_km)]
	if caminho == ARQUIVO_EXEMPLO:
		texto += " (arquivo de EXEMPLO, dados fictícios)"
	return texto


static func distancia_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var r := 6371.0
	var dlat := deg_to_rad(lat2 - lat1)
	var dlon := deg_to_rad(lon2 - lon1)
	var a := sin(dlat / 2) ** 2 + cos(deg_to_rad(lat1)) * cos(deg_to_rad(lat2)) * sin(dlon / 2) ** 2
	return 2.0 * r * asin(sqrt(a))


static func _unix(texto: String) -> float:
	var t := texto.strip_edges().replace("/", "-").replace(" ", "T")
	if t.length() == 16:
		t += ":00"
	return float(Time.get_unix_time_from_datetime_string(t))
