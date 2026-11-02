# =============================================================================
# 01_cumplimiento.R
# -----------------------------------------------------------------------------
# Cumplimiento territorial de los umbrales de afiliación por partido y región:
#   - umbral de constitución (0,3 % del padrón, art. 6)
#   - umbral de mantención (0,15 %, art. 56 N.° 4), que rige a los partidos ya
#     constituidos durante el plazo transitorio de 18 meses
#   - mínimo de ocho regiones sin riesgo para conservar la calidad de partido
# Compara los cortes del SERVEL al 31 de julio y al 30 de septiembre de 2026.
#
# Entradas  data/fuentes/afiliacion_region.csv, padron_region.csv, universo_partidos.csv
# Salidas   output/tablas/01_*.csv, data/processed/cumplimiento.rds
# =============================================================================

source(file.path("R", "00_funciones.R"))

afil <- leer_csv2(file.path(DIR_FUE, "afiliacion_region.csv"))
padron <- leer_csv2(file.path(DIR_FUE, "padron_region.csv"))
universo <- leer_csv2(file.path(DIR_FUE, "universo_partidos.csv"))

constituidos <- universo |> filter(str_detect(estado, "^Constituido")) |> pull(sigla)

base <- afil |>
  filter(sigla %in% constituidos) |>
  left_join(padron, by = "region") |>
  pivot_longer(starts_with("afiliados_"), names_to = "corte", values_to = "afiliados",
               names_prefix = "afiliados_") |>
  mutate(corte = as.Date(str_replace_all(corte, "_", "-")),
         constituido = constituido == "Sí",
         afiliados = replace_na(afiliados, 0),
         tasa = afiliados / padron_definitivo,
         piso_constitucion = UMBRAL_CONSTITUCION * padron_definitivo,
         piso_mantencion = UMBRAL_MANTENCION * padron_definitivo,
         cumple_constitucion = constituido & afiliados >= piso_constitucion,
         segura = constituido & afiliados >= piso_mantencion,
         en_riesgo = constituido & !segura,
         faltan_mantencion = if_else(en_riesgo, ceiling(piso_mantencion - afiliados), 0),
         region = factor(region, levels = REGIONES))

stopifnot(n_distinct(base$region) == 16, !any(is.na(base$padron_definitivo)))

# Resumen por partido ------------------------------------------------------------
faltan_para_ocho <- function(d) {
  # afiliados mínimos para llegar a 8 regiones seguras, completando primero las
  # regiones constituidas con menor brecha
  seguras <- sum(d$segura)
  if (seguras >= MIN_REGIONES) return(0)
  brechas <- sort(d$faltan_mantencion[d$en_riesgo])
  if (length(brechas) < MIN_REGIONES - seguras) return(NA_real_)  # no alcanza aunque complete todas
  sum(brechas[seq_len(MIN_REGIONES - seguras)])
}

resumen <- base |>
  group_by(sigla, corte) |>
  summarise(gini_penetracion = gini(tasa[constituido]),
            pct_rm = afiliados[region == "Metropolitana de Santiago"] / sum(afiliados),
            faltan_para_ocho = faltan_para_ocho(pick(everything())),
            regiones_riesgo = paste(region[en_riesgo], collapse = ", "),
            cumple_constitucion = sum(cumple_constitucion),
            no_cumple_constitucion = sum(constituido) - cumple_constitucion,
            seguras = sum(segura), en_riesgo = sum(en_riesgo),
            faltan_todas = sum(faltan_mantencion),
            afiliados = sum(afiliados),
            constituido = sum(constituido),
            .groups = "drop") |>
  mutate(nacionalizacion = 1 - gini_penetracion,
         alcanza_ocho = seguras >= MIN_REGIONES)

ult <- max(resumen$corte)
tabla <- resumen |> filter(corte == ult) |> arrange(desc(seguras), en_riesgo)
print(as.data.frame(select(tabla, sigla, afiliados, constituido, seguras, en_riesgo,
                           cumple_constitucion, faltan_todas, faltan_para_ocho, nacionalizacion)))
escribir(tabla, "01_resumen_partidos.csv")

# H5: con el umbral de constitución, ¿cuántos partidos no reunirían ocho regiones?
h5 <- resumen |> group_by(corte) |>
  summarise(partidos = n(),
            sin_ocho_mantencion = sum(seguras < MIN_REGIONES),
            sin_ocho_constitucion = sum(cumple_constitucion < MIN_REGIONES),
            regiones_bajo_mantencion = sum(en_riesgo),
            regiones_bajo_constitucion = sum(no_cumple_constitucion), .groups = "drop")
print(as.data.frame(h5)); escribir(h5, "01_doble_umbral.csv")

# Cambio entre cortes --------------------------------------------------------------
cambios <- base |> select(sigla, region, corte, afiliados, segura, constituido) |>
  mutate(corte = if_else(corte == min(corte), "jul", "sep")) |>
  pivot_wider(names_from = corte, values_from = c(afiliados, segura))
transiciones <- cambios |> filter(constituido, segura_jul != segura_sep)
print(as.data.frame(transiciones)); escribir(transiciones, "01_cambios_de_estado.csv")
cambio_partido <- resumen |> select(sigla, corte, afiliados, seguras) |>
  pivot_wider(names_from = corte, values_from = c(afiliados, seguras))
escribir(cambio_partido, "01_cambio_entre_cortes.csv")

# H1: nacionalización de la afiliación y regiones en riesgo ----------------------
h1 <- tabla |> filter(constituido == 16)
ct <- cor.test(h1$nacionalizacion, h1$en_riesgo, method = "spearman", exact = FALSE)
cat(sprintf("H1: Spearman nacionalización vs. regiones en riesgo = %.2f (p = %.3f, n = %d)\n",
            ct$estimate, ct$p.value, nrow(h1)))
ct2 <- cor.test(h1$afiliados, h1$en_riesgo, method = "spearman", exact = FALSE)
cat(sprintf("    Spearman afiliados nacionales vs. regiones en riesgo = %.2f (p = %.3f)\n",
            ct2$estimate, ct2$p.value))
escribir(tibble(prueba = c("nacionalizacion", "afiliados_nacionales"),
                rho = c(ct$estimate, ct2$estimate), p = c(ct$p.value, ct2$p.value), n = nrow(h1)),
         "01_h1_correlaciones.csv")

# Matriz partido x región (último corte) para la figura ----------------------------
matriz <- base |> filter(corte == ult) |>
  mutate(estado = case_when(!constituido ~ "No constituido",
                            cumple_constitucion ~ "Sobre 0,3 %",
                            segura ~ "Entre 0,15 % y 0,3 %",
                            TRUE ~ "Bajo 0,15 %"),
         razon = afiliados / piso_mantencion)
escribir(select(matriz, sigla, region, constituido, afiliados, padron_definitivo, tasa, estado, faltan_mantencion),
         "01_matriz_partido_region.csv")
saveRDS(list(base = base, resumen = resumen, matriz = matriz), file.path(DIR_PROC, "cumplimiento.rds"))

# Esfuerzo de afiliación: afiliados que faltan respecto de la militancia actual y
# del ritmo observado entre julio y septiembre de 2026 -------------------------
meses_obs <- as.numeric(diff(range(resumen$corte))) / 30.44
esfuerzo <- resumen |>
  select(sigla, corte, afiliados, faltan_todas, faltan_para_ocho, seguras, en_riesgo) |>
  pivot_wider(names_from = corte, values_from = c(afiliados, faltan_todas, faltan_para_ocho, seguras, en_riesgo)) |>
  rename_with(~ str_replace(.x, "_2026-07-31", "_jul") |> str_replace("_2026-09-30", "_sep")) |>
  mutate(pct_faltan_todas = faltan_todas_sep / afiliados_sep,
         pct_faltan_ocho = faltan_para_ocho_sep / afiliados_sep,
         ritmo_mensual_neto = (afiliados_sep - afiliados_jul) / meses_obs,
         ritmo_requerido_18m = faltan_todas_sep / 18) |>
  arrange(desc(pct_faltan_todas))
print(as.data.frame(select(esfuerzo, sigla, afiliados_sep, en_riesgo_sep, faltan_todas_sep, pct_faltan_todas,
                           faltan_para_ocho_sep, ritmo_mensual_neto, ritmo_requerido_18m)))
escribir(esfuerzo, "01_esfuerzo_afiliacion.csv")
