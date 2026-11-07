# =============================================================================
# Reforma al sistema político (Boletín 17.640-06) y umbrales de afiliación
# 00_funciones.R — paquetes, constantes y funciones comunes
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(purrr)
  library(stringr); library(ggplot2)
})

DIR_FUE  <- file.path("data", "fuentes")
DIR_RAW  <- file.path("data", "raw")
DIR_PROC <- file.path("data", "processed")
DIR_TAB  <- file.path("output", "tablas")
DIR_FIG  <- file.path("output", "figuras")
for (d in c(DIR_PROC, DIR_TAB, DIR_FIG)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# Umbrales de la Ley 18.603 tras el Boletín 17.640-06
UMBRAL_CONSTITUCION <- 0.003   # art. 6: 0,3 % del padrón electoral definitivo
UMBRAL_MANTENCION   <- 0.0015  # art. 56 N.° 4: menos del 50 % del número exigido
MIN_REGIONES        <- 8       # arts. 3 y 56: sin la alternativa de tres regiones contiguas
MINIMO_ABSOLUTO     <- 500     # art. 6: si el porcentaje da menos de 500 afiliados, se exigen 500

REGIONES <- c("Arica y Parinacota", "Tarapacá", "Antofagasta", "Atacama", "Coquimbo",
              "Valparaíso", "Metropolitana de Santiago", "O'Higgins", "Maule", "Ñuble",
              "Biobío", "La Araucanía", "Los Ríos", "Los Lagos", "Aysén", "Magallanes")

leer_csv2 <- function(f, ...) read_delim(f, delim = ";", show_col_types = FALSE,
                                         locale = locale(decimal_mark = ",", grouping_mark = "."), ...)
escribir <- function(x, nombre) write_csv2(x, file.path(DIR_TAB, nombre))

# Índice de Gini (para la nacionalización de la afiliación, Jones y Mainwaring, 2003)
gini <- function(x) {
  x <- sort(x[!is.na(x)]); n <- length(x)
  if (n < 2 || sum(x) == 0) return(NA_real_)
  sum((2 * seq_len(n) - n - 1) * x) / (n * sum(x))
}

# Asignación D'Hondt: votos por lista y número de escaños -> escaños por lista
dhondt <- function(votos, escanos) {
  if (escanos <= 0 || length(votos) == 0) return(integer(length(votos)))
  cocientes <- outer(votos, seq_len(escanos), "/")
  orden <- order(cocientes, decreasing = TRUE)[seq_len(escanos)]
  tabulate(((orden - 1) %% length(votos)) + 1, nbins = length(votos))
}
