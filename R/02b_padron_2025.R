# =============================================================================
# 02b_padron_2025.R
# -----------------------------------------------------------------------------
# Inscritos y votantes por región en la elección de diputados de 2025.
#   - Valida el padrón regional usado en 01 (inscritos = padrón definitivo).
#   - Calcula el umbral anterior a la reforma (0,25 % de quienes sufragaron en la
#     última elección de diputados) para compararlo con el nuevo (0,3 % del padrón).
#
# Entradas  data/raw/2025_11_Diputados_Datos_Eleccion_v2.xlsx, data/fuentes/padron_region.csv
# Salidas   output/tablas/02b_umbral_antes_despues.csv
# =============================================================================

source(file.path("R", "00_funciones.R"))
suppressPackageStartupMessages(library(readxl))
NUM_REGION <- c(`1` = "Tarapacá", `2` = "Antofagasta", `3` = "Atacama", `4` = "Coquimbo",
                `5` = "Valparaíso", `6` = "O'Higgins", `7` = "Maule", `8` = "Biobío",
                `9` = "La Araucanía", `10` = "Los Lagos", `11` = "Aysén", `12` = "Magallanes",
                `13` = "Metropolitana de Santiago", `14` = "Los Ríos", `15` = "Arica y Parinacota",
                `16` = "Ñuble")

f <- list.files(DIR_RAW, pattern = "^2025_11_Diputados_Datos_Eleccion.*\\.xlsx$", recursive = TRUE, full.names = TRUE)[1]
part <- read_excel(f, sheet = "Participación", skip = 6) |>
  filter(!is.na(`Nro.Región`)) |>
  group_by(region = NUM_REGION[as.character(`Nro.Región`)]) |>
  summarise(inscritos = sum(Inscritos), votantes = sum(Votos), .groups = "drop")

padron <- leer_csv2(file.path(DIR_FUE, "padron_region.csv"))
comp <- padron |> left_join(part, by = "region") |>
  mutate(diferencia_padron = padron_definitivo - inscritos,
         participacion = votantes / inscritos,
         umbral_antes = 0.0025 * votantes, umbral_despues = UMBRAL_CONSTITUCION * padron_definitivo,
         mantencion_antes = umbral_antes / 2, mantencion_despues = umbral_despues / 2,
         aumento = umbral_despues / umbral_antes - 1)
print(as.data.frame(comp))
cat(sprintf("Total: inscritos %s, padrón %s; aumento efectivo del umbral %.1f %%\n",
            sum(comp$inscritos), sum(comp$padron_definitivo),
            100 * (sum(comp$umbral_despues) / sum(comp$umbral_antes) - 1)))
escribir(comp, "02b_umbral_antes_despues.csv")

# ¿Cuántos partidos alcanzarían ocho regiones con la regla anterior? -----------
cump <- readRDS(file.path(DIR_PROC, "cumplimiento.rds"))
regla_antes <- cump$base |> filter(corte == max(corte)) |>
  mutate(region = as.character(region)) |>
  left_join(select(comp, region, mantencion_antes), by = "region") |>
  group_by(sigla) |>
  summarise(seguras_antes = sum(constituido & afiliados >= mantencion_antes),
            seguras_despues = sum(segura), .groups = "drop") |>
  arrange(seguras_despues)
print(as.data.frame(regla_antes))
cat("Partidos bajo 8 regiones: antes", sum(regla_antes$seguras_antes < MIN_REGIONES),
    "| después", sum(regla_antes$seguras_despues < MIN_REGIONES), "\n")
escribir(regla_antes, "02b_regla_antes_despues.csv")
