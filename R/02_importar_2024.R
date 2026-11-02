# =============================================================================
# 02_importar_2024.R
# -----------------------------------------------------------------------------
# Lee la votación por comuna de las elecciones de 2024 (SERVEL) y la deja en un
# formato común: concejales, consejeros regionales, alcaldes y gobernadores
# regionales (primera vuelta).
#
# Entradas  data/raw/2024_10_*.xlsx (archivos oficiales del SERVEL)
# Salidas   data/processed/resultados_2024.rds
# =============================================================================

source(file.path("R", "00_funciones.R"))
suppressPackageStartupMessages(library(readxl))

# Número de región del SERVEL -> nombre usado en las tablas de afiliación
NUM_REGION <- c(`1` = "Tarapacá", `2` = "Antofagasta", `3` = "Atacama", `4` = "Coquimbo",
                `5` = "Valparaíso", `6` = "O'Higgins", `7` = "Maule", `8` = "Biobío",
                `9` = "La Araucanía", `10` = "Los Lagos", `11` = "Aysén", `12` = "Magallanes",
                `13` = "Metropolitana de Santiago", `14` = "Los Ríos", `15` = "Arica y Parinacota",
                `16` = "Ñuble")

ARCHIVOS <- tribble(
  ~eleccion,      ~patron,                                         ~unidad,
  "concejales",   "^2024_10_Concejales_DatosEleccion\\.xlsx$",     "Comuna",
  "core",         "^2024_10_ConsejerosRegionales_DatosEleccion\\.xlsx$", "Circunscripción Provincial",
  "alcaldes",     "^2024_10_Alcaldes_Datos_Eleccion\\.xlsx$",      "Comuna",
  "gore",         "^2024_10_GobernadoresRegionales_Datos_Eleccion\\.xlsx$", "Región"
)

leer <- function(eleccion, patron, unidad) {
  f <- list.files(DIR_RAW, pattern = patron, recursive = TRUE, full.names = TRUE)[1]
  if (is.na(f)) stop("Falta el archivo de ", eleccion, " en data/raw/")
  message("Leyendo ", basename(f))
  d <- read_excel(f, sheet = "Votación por comuna", skip = 6)
  if (!"Subpacto" %in% names(d)) d$Subpacto <- NA_character_
  marca <- intersect(c("Cargo", "Resultado"), names(d))[1]
  d |>
    # La Antártica no tiene municipio propio: el SERVEL replica en ella la
    # votación de Cabo de Hornos, por lo que se excluye para no duplicarla.
    filter(!is.na(`Nro.Región`), Comuna != "ANTARTICA") |>
    transmute(eleccion,
              region = NUM_REGION[as.character(`Nro.Región`)],
              comuna = Comuna,
              unidad = if (unidad == "Región") region else .data[[unidad]],
              lista = Lista, pacto = Pacto,
              subpacto = na_if(Subpacto, "---"), partido = Partido,
              candidato = str_squish(paste(Nombres, `Primer apellido`, `Segundo apellido`)),
              votos = as.numeric(Votos),
              electo = .data[[marca]] %in% c("CONCEJAL", "CONSEJERO REGIONAL", "ALCALDE", "ELECTO"),
              segunda_vuelta = .data[[marca]] %in% "NOMINADO SEGUNDA VOTACION",
              tipo = case_when(Nombres == "VOTOS EN BLANCO" ~ "blanco",
                               Nombres == "VOTOS NULOS" ~ "nulo",
                               TRUE ~ "candidato"))
}

res <- pmap_dfr(ARCHIVOS, leer)
stopifnot(!any(is.na(res$region)))

# Gobernadores: el archivo marca "ELECTO" a quienes ganaron en primera vuelta y
# "NOMINADO SEGUNDA VOTACION" a quienes pasaron a segunda vuelta.
resumen <- res |> group_by(eleccion) |>
  summarise(unidades = n_distinct(paste(region, unidad)), comunas = n_distinct(comuna),
            candidaturas = sum(tipo == "candidato"), electos = sum(electo),
            votos_validos = sum(votos[tipo == "candidato"]), .groups = "drop")
print(as.data.frame(resumen))
escribir(resumen, "02_resumen_importacion.csv")
saveRDS(res, file.path(DIR_PROC, "resultados_2024.rds"))
