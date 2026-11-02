# =============================================================================
# 03_exposicion_voto.R
# -----------------------------------------------------------------------------
# ¿Cuánto del voto de 2024 de cada partido proviene de regiones donde hoy no
# podría presentar candidaturas en 2028 (bajo el 0,15 % o sin constitución)?
# Dos definiciones del voto de un partido:
#   - militantes: candidaturas afiliadas al partido
#   - cupo: militantes más los independientes de su subpacto (o de su pacto, si
#     el pacto es de un solo partido)
# Incluye la línea base de los cargos mayoritarios (alcaldes y gobernadores).
#
# Entradas  data/processed/resultados_2024.rds, cumplimiento.rds
# Salidas   output/tablas/03_*.csv, data/processed/voto_partido_2024.rds
# =============================================================================

source(file.path("R", "00_funciones.R"))

res <- readRDS(file.path(DIR_PROC, "resultados_2024.rds"))
cump <- readRDS(file.path(DIR_PROC, "cumplimiento.rds"))

# Nombre del partido en el SERVEL 2024 -> sigla de 2026. El Partido Cristiano de
# Chile (2026) se aproxima con su predecesor, el Partido Social Cristiano.
SIGLAS <- c("PARTIDO DEMOCRATA CRISTIANO" = "PDC", "PARTIDO POR LA DEMOCRACIA" = "PPD",
            "PARTIDO RADICAL DE CHILE" = "PR", "PARTIDO SOCIALISTA DE CHILE" = "PS",
            "FEDERACION REGIONALISTA VERDE SOCIAL" = "FRVS", "PARTIDO LIBERAL DE CHILE" = "PL",
            "PARTIDO DE LA GENTE" = "PDG", "EVOLUCION POLITICA" = "EVOPOLI",
            "PARTIDO COMUNISTA DE CHILE" = "PCCh", "UNION DEMOCRATA INDEPENDIENTE" = "UDI",
            "RENOVACION NACIONAL" = "RN", "FRENTE AMPLIO" = "FA",
            "PARTIDO REPUBLICANO DE CHILE" = "PRCh", "PARTIDO SOCIAL CRISTIANO" = "PCC")

res <- res |> mutate(sigla = unname(SIGLAS[partido]))

# Partido del cupo de los independientes: el único partido con militantes en su
# subpacto (o en su pacto, si no hay subpacto y el pacto es de un solo partido).
cupo_de <- function(d, grupo) {
  d |> filter(tipo == "candidato", !is.na(sigla)) |>
    group_by(eleccion, region, unidad, across(all_of(grupo))) |>
    summarise(n_partidos = n_distinct(sigla), sigla_cupo = first(sigla), .groups = "drop") |>
    filter(n_partidos == 1) |> select(-n_partidos)
}
por_subpacto <- cupo_de(filter(res, !is.na(subpacto)), c("pacto", "subpacto"))
por_pacto <- cupo_de(filter(res, is.na(subpacto)), "pacto")
res <- res |>
  left_join(por_subpacto, by = c("eleccion", "region", "unidad", "pacto", "subpacto")) |>
  left_join(por_pacto, by = c("eleccion", "region", "unidad", "pacto"), suffix = c("", "_p")) |>
  mutate(sigla_cupo = case_when(!is.na(sigla) ~ sigla,
                                partido == "INDEPENDIENTES" & !is.na(subpacto) ~ sigla_cupo,
                                partido == "INDEPENDIENTES" & is.na(subpacto) ~ sigla_cupo_p,
                                TRUE ~ NA_character_)) |>
  select(-sigla_cupo_p)
saveRDS(res, file.path(DIR_PROC, "voto_partido_2024.rds"))

# Regiones expuestas por partido (corte del 30 de septiembre de 2026)
expuestas <- cump$matriz |>
  transmute(sigla, region = as.character(region),
            expuesta = !constituido | estado == "Bajo 0,15 %",
            motivo = case_when(!constituido ~ "No constituido", estado == "Bajo 0,15 %" ~ "Bajo 0,15 %",
                               TRUE ~ NA_character_))
saveRDS(expuestas, file.path(DIR_PROC, "regiones_expuestas.rds"))

validos <- res |> filter(tipo == "candidato") |> group_by(eleccion) |> summarise(validos = sum(votos))
emitidos <- res |> group_by(eleccion) |> summarise(emitidos = sum(votos))

voto <- bind_rows(
  res |> filter(tipo == "candidato", !is.na(sigla)) |> mutate(def = "militantes"),
  res |> filter(tipo == "candidato", !is.na(sigla_cupo)) |> mutate(sigla = sigla_cupo, def = "cupo")) |>
  left_join(expuestas, by = c("sigla", "region")) |>
  mutate(expuesta = coalesce(expuesta, FALSE))

exposicion <- voto |>
  group_by(def, eleccion, sigla) |>
  summarise(votos_expuestos = sum(votos[expuesta]), votos = sum(votos), .groups = "drop") |>
  left_join(validos, by = "eleccion") |> left_join(emitidos, by = "eleccion") |>
  mutate(pct_validos = votos / validos, pct_emitidos = votos / emitidos,
         pct_expuesto = votos_expuestos / votos) |>
  arrange(def, eleccion, desc(pct_expuesto))
escribir(exposicion, "03_exposicion_voto.csv")
print(as.data.frame(exposicion |> filter(def == "militantes", eleccion == "concejales") |>
                      mutate(across(starts_with("pct"), ~ round(100 * .x, 2)))))

# Cargos mayoritarios en las regiones expuestas -----------------------------------
mayoritarios <- voto |> filter(def == "militantes", eleccion %in% c("alcaldes", "gore")) |>
  group_by(eleccion, sigla, region, unidad, candidato) |>
  summarise(votos = sum(votos), electo = any(electo), expuesta = first(expuesta), .groups = "drop") |>
  group_by(eleccion, sigla) |>
  summarise(candidaturas = n(), electos = sum(electo),
            candidaturas_expuestas = sum(expuesta), electos_expuestos = sum(electo & expuesta),
            .groups = "drop")
escribir(mayoritarios, "03_mayoritarios.csv")
print(as.data.frame(filter(mayoritarios, sigla %in% c("EVOPOLI", "FRVS", "PL", "PCC", "PPD", "PRCh", "PDC", "PR", "UDI", "PCCh"))))
