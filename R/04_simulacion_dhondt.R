# =============================================================================
# 04_simulacion_dhondt.R
# -----------------------------------------------------------------------------
# Prueba retrospectiva del efecto mecánico (H3) con los resultados de 2024.
# 1. Valida la asignación D'Hondt entre listas contra los electos del SERVEL.
# 2. Para cada partido y cada comuna (concejales) o circunscripción provincial
#    (consejeros regionales) de una región donde hoy está expuesto, retira sus
#    votos del pacto y reasigna los escaños: ¿pierde el pacto un escaño?
# 3. Calcula la fracción crítica: la menor proporción de los votos del partido
#    que debe salir del pacto para que este pierda un escaño. Mide qué tan
#    frágil es el escaño ante un trasvase parcial (supuesto más realista que la
#    salida total).
#
# Entradas  data/processed/voto_partido_2024.rds, regiones_expuestas.rds
# Salidas   output/tablas/04_*.csv, data/processed/simulacion.rds
# =============================================================================

source(file.path("R", "00_funciones.R"))

res <- readRDS(file.path(DIR_PROC, "voto_partido_2024.rds"))
expuestas <- readRDS(file.path(DIR_PROC, "regiones_expuestas.rds")) |> filter(expuesta)

# Listas por unidad: en concejales y consejeros los escaños se asignan entre
# listas (pactos o candidaturas fuera de pacto) con D'Hondt.
listas <- res |>
  filter(eleccion %in% c("concejales", "core"), tipo == "candidato") |>
  mutate(id_lista = coalesce(paste(lista, pacto), paste("IND", candidato)))

magnitud <- listas |> group_by(eleccion, region, unidad) |>
  summarise(escanos = n_distinct(candidato[electo]), .groups = "drop")

votos_lista <- listas |>
  group_by(eleccion, region, unidad, id_lista, pacto) |>
  summarise(votos = sum(votos), electos = n_distinct(candidato[electo]), .groups = "drop")

asignar <- function(d, m) mutate(d, escanos_dhondt = dhondt(votos, m))
base <- votos_lista |>
  left_join(magnitud, by = c("eleccion", "region", "unidad")) |>
  group_by(eleccion, region, unidad) |>
  group_modify(~ asignar(.x, .x$escanos[1])) |> ungroup()

validacion <- base |> group_by(eleccion) |>
  summarise(unidades = n_distinct(paste(region, unidad)),
            listas = n(), escanos = sum(electos),
            listas_coinciden = mean(escanos_dhondt == electos),
            unidades_coinciden = n_distinct(paste(region, unidad)) -
              n_distinct(paste(region, unidad)[escanos_dhondt != electos]), .groups = "drop")
print(as.data.frame(validacion)); escribir(validacion, "04_validacion_dhondt.csv")

# Votos de cada partido por lista y unidad, en regiones expuestas -----------------
votos_partido <- bind_rows(
  listas |> filter(!is.na(sigla)) |> mutate(def = "militantes"),
  listas |> filter(!is.na(sigla_cupo)) |> mutate(sigla = sigla_cupo, def = "cupo")) |>
  semi_join(expuestas, by = c("sigla", "region")) |>
  group_by(def, sigla, eleccion, region, unidad, id_lista) |>
  summarise(votos_partido = sum(votos), .groups = "drop")

simular <- function(def, sigla, eleccion, region, unidad, id_lista, votos_partido) {
  u <- base[base$eleccion == eleccion & base$region == region & base$unidad == unidad, ]
  k <- which(u$id_lista == id_lista); m <- u$escanos[1]
  esc0 <- u$escanos_dhondt[k]
  escanos_con <- function(f) { v <- u$votos; v[k] <- v[k] - f * votos_partido; dhondt(v, m) }
  esc1 <- escanos_con(1)
  pierde <- esc1[k] < esc0
  # fracción crítica por bisección (NA si ni la salida total le quita un escaño)
  critica <- NA_real_
  if (pierde) {
    lo <- 0; hi <- 1
    for (i in 1:25) { mid <- (lo + hi) / 2; if (escanos_con(mid)[k] < esc0) hi <- mid else lo <- mid }
    critica <- hi
  }
  ganador <- if (pierde) u$pacto[which(esc1 > u$escanos_dhondt)[1]] else NA_character_
  tibble(def, sigla, eleccion, region, unidad, id_lista, votos_partido,
         votos_lista = u$votos[k], magnitud = m, escanos_lista = esc0,
         pierde_escano = pierde, fraccion_critica = critica, pacto_que_gana = ganador)
}

sim <- pmap_dfr(votos_partido, simular)
saveRDS(list(base = base, sim = sim), file.path(DIR_PROC, "simulacion.rds"))

resumen <- sim |> group_by(def, eleccion, sigla) |>
  summarise(unidades = n(), pierde = sum(pierde_escano), pct_pierde = mean(pierde_escano),
            escanos_perdidos = sum(pierde_escano),
            critica_mediana = median(fraccion_critica, na.rm = TRUE), .groups = "drop") |>
  arrange(def, eleccion, desc(pct_pierde))
print(as.data.frame(resumen |> mutate(pct_pierde = round(100 * pct_pierde, 1))))
escribir(resumen, "04_resumen_simulacion.csv")

# H3: ¿el efecto es mayor cuanto menor la magnitud? -----------------------------
por_magnitud <- sim |> filter(def == "militantes", eleccion == "concejales") |>
  group_by(magnitud) |>
  summarise(casos = n(), pct_pierde = mean(pierde_escano),
            critica_mediana = median(fraccion_critica, na.rm = TRUE), .groups = "drop")
print(as.data.frame(por_magnitud)); escribir(por_magnitud, "04_por_magnitud.csv")
escribir(sim, "04_simulacion_detalle.csv")

# ¿A qué bloque va el escaño perdido? -------------------------------------------
# Bloques de los pactos de 2024 según su composición partidaria (data/fuentes);
# los pactos no clasificados (PDG, Centro Democrático, ecologistas, izquierda
# extraparlamentaria, independientes) quedan como "Otros".
bloques <- leer_csv2(file.path(DIR_FUE, "bloques_pactos_2024.csv"))
destino <- sim |> filter(pierde_escano) |>
  left_join(distinct(select(base, eleccion, region, unidad, id_lista, pacto_origen = pacto)),
            by = c("eleccion", "region", "unidad", "id_lista")) |>
  left_join(rename(bloques, bloque_origen = bloque), by = c("pacto_origen" = "pacto")) |>
  left_join(rename(bloques, bloque_gana = bloque), by = c("pacto_que_gana" = "pacto")) |>
  mutate(across(c(bloque_origen, bloque_gana), ~ coalesce(.x, "Otros")),
         mismo_bloque = bloque_origen == bloque_gana)
resumen_destino <- destino |> group_by(def, eleccion, sigla, bloque_origen) |>
  summarise(escanos = n(), pct_mismo_bloque = mean(mismo_bloque),
            mismo_bloque = sum(mismo_bloque), .groups = "drop")
print(as.data.frame(filter(resumen_destino, def == "militantes")))
escribir(resumen_destino, "04_destino_escano.csv")
tot <- destino |> group_by(def, eleccion) |> summarise(escanos = n(), pct_mismo_bloque = mean(mismo_bloque), .groups = "drop")
print(as.data.frame(tot)); escribir(tot, "04_destino_total.csv")
