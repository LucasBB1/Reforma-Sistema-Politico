# =============================================================================
# 05_figuras_tablas.R — figuras del documento de trabajo
# Entradas  data/processed/*.rds, output/tablas/03_exposicion_voto.csv
# Salidas   output/figuras/fig1-fig4 (.png)
# =============================================================================

source(file.path("R", "00_funciones.R"))
cump <- readRDS(file.path(DIR_PROC, "cumplimiento.rds"))
sim <- readRDS(file.path(DIR_PROC, "simulacion.rds"))$sim
expo <- leer_csv2(file.path(DIR_TAB, "03_exposicion_voto.csv"))

AZUL <- "#20587F"; GRIS <- "#8C8C8C"; CELESTE <- "#9DB9D3"; ROJO <- "#B5543C"
tema <- theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(), legend.position = "bottom",
        plot.title = element_blank(), plot.caption = element_blank())
guardar <- function(g, nombre, w = 8, h = 5.2) ggsave(file.path(DIR_FIG, nombre), g, width = w, height = h, dpi = 300, bg = "white")

orden <- cump$resumen |> filter(corte == max(corte)) |> arrange(seguras, desc(en_riesgo)) |> pull(sigla)

# Figura 1: matriz de cumplimiento por partido y región ---------------------------
abrev <- c("Arica y Parinacota" = "Arica", "Tarapacá" = "Tarapacá", "Antofagasta" = "Antofagasta",
           "Atacama" = "Atacama", "Coquimbo" = "Coquimbo", "Valparaíso" = "Valparaíso",
           "Metropolitana de Santiago" = "Metropolitana", "O'Higgins" = "O'Higgins", "Maule" = "Maule",
           "Ñuble" = "Ñuble", "Biobío" = "Biobío", "La Araucanía" = "Araucanía", "Los Ríos" = "Los Ríos",
           "Los Lagos" = "Los Lagos", "Aysén" = "Aysén", "Magallanes" = "Magallanes")
m <- cump$matriz |>
  mutate(sigla = factor(sigla, levels = orden),
         region = factor(abrev[as.character(region)], levels = abrev),
         estado = factor(estado, levels = c("Sobre 0,3 %", "Entre 0,15 % y 0,3 %", "Bajo 0,15 %", "No constituido")))
g1 <- ggplot(m, aes(region, sigla, fill = estado)) +
  geom_tile(color = "white", linewidth = 0.6) +
  scale_fill_manual(values = c("Sobre 0,3 %" = AZUL, "Entre 0,15 % y 0,3 %" = CELESTE,
                               "Bajo 0,15 %" = ROJO, "No constituido" = "#E3E3E3"), name = NULL) +
  labs(x = NULL, y = NULL) + tema +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), panel.grid = element_blank())
guardar(g1, "fig1_matriz_cumplimiento.png", w = 9, h = 5.6)

# Figura 2: doble umbral, regiones que cumplen cada estándar ----------------------
d2 <- cump$resumen |> filter(corte == max(corte)) |>
  transmute(sigla = factor(sigla, levels = orden), `Umbral de mantención (0,15 %)` = seguras,
            `Umbral de constitución (0,3 %)` = cumple_constitucion) |>
  pivot_longer(-sigla, names_to = "umbral", values_to = "regiones")
g2 <- ggplot(d2, aes(regiones, sigla)) +
  geom_vline(xintercept = MIN_REGIONES, linetype = "dashed", color = GRIS) +
  geom_line(aes(group = sigla), color = "#C8C8C8", linewidth = 1) +
  geom_point(aes(color = umbral), size = 3) +
  scale_color_manual(values = c(`Umbral de mantención (0,15 %)` = AZUL, `Umbral de constitución (0,3 %)` = ROJO), name = NULL) +
  scale_x_continuous(breaks = seq(0, 16, 2), limits = c(0, 16)) +
  annotate("text", x = MIN_REGIONES + 0.2, y = length(orden) + 0.7, label = "Mínimo legal: 8 regiones", hjust = 0, size = 3.3, color = "grey30") +
  coord_cartesian(clip = "off", ylim = c(1, length(orden) + 0.8)) +
  labs(x = "Regiones donde el partido cumple el umbral", y = NULL) + tema
guardar(g2, "fig2_doble_umbral.png")

# Figura 3: exposición del voto de 2024 ---------------------------------------------
d3 <- expo |> filter(def == "militantes", eleccion %in% c("concejales", "core"), pct_expuesto > 0) |>
  mutate(eleccion = recode(eleccion, concejales = "Concejales", core = "Consejeros regionales"),
         sigla = factor(sigla, levels = rev(expo |> filter(def == "militantes", eleccion == "concejales") |>
                                              arrange(pct_expuesto) |> pull(sigla) |> rev())))
g3 <- ggplot(d3, aes(100 * pct_expuesto, sigla, fill = eleccion)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.7) +
  scale_fill_manual(values = c(Concejales = AZUL, `Consejeros regionales` = CELESTE), name = NULL) +
  labs(x = "Porcentaje del voto 2024 del partido emitido en regiones expuestas", y = NULL) + tema
guardar(g3, "fig3_exposicion_voto.png")

# Figura 4: fracción crítica en concejales --------------------------------------------
d4 <- sim |> filter(def == "militantes", eleccion == "concejales", pierde_escano) |>
  group_by(sigla) |> filter(n() >= 4) |> ungroup() |>
  mutate(sigla = reorder(sigla, fraccion_critica, median))
g4 <- ggplot(d4, aes(100 * fraccion_critica, sigla)) +
  geom_boxplot(outlier.shape = NA, fill = "#EEF3F7", color = AZUL, width = 0.55) +
  geom_jitter(height = 0.12, width = 0, size = 1.3, alpha = 0.55, color = AZUL) +
  scale_x_continuous(limits = c(0, 100)) +
  labs(x = "Porcentaje del voto del partido que debe salir del pacto para que pierda un concejal", y = NULL) + tema
guardar(g4, "fig4_fraccion_critica.png")
message("Figuras en output/figuras")
