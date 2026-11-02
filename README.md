# Entrar y permanecer: el doble umbral de afiliación de la reforma al sistema político y la oferta partidaria de 2028

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23895805.svg)](https://doi.org/10.5281/zenodo.23895805)

Código y datos del **Documento de trabajo N.° 3** de Lucas Bottinelli Baltra. El estudio evalúa, antes de su entrada en vigencia, cómo la reforma al sistema político (Boletín N.° 17.640-06) reconfigura la oferta partidaria de cara a las elecciones regionales y municipales de 2028: cumplimiento de los umbrales de afiliación por partido y región, exposición de la votación de 2024 y simulación D'Hondt del efecto mecánico de excluir a un partido.

**Autor:** Lucas Bottinelli Baltra · [lucasbb1.github.io](https://lucasbb1.github.io) · ORCID [0009-0000-4865-7261](https://orcid.org/0009-0000-4865-7261)

El documento está en `documento/` (Word y PDF) y en Zenodo: https://doi.org/10.5281/zenodo.23895854

## Resultados principales

- El cambio de denominador, de votantes a padrón, eleva el umbral efectivo de afiliación en 39,8%.
- Cuatro de los quince partidos constituidos no reúnen ocho regiones sobre el umbral de mantención (0,15%); con el de constitución (0,3%) no las reunirían trece.
- El riesgo depende del número total de afiliados y no de su concentración territorial.
- La reforma también expone la presencia regional de partidos medianos y grandes: el Partido Republicano está bajo el umbral en siete regiones, de donde provino el 81% de su voto de 2024 en concejales.

## Scripts

Correr en orden desde `Reforma-Sistema-Politico.Rproj`.

| Script | Qué hace |
|---|---|
| `00_funciones.R` | Paquetes, umbrales legales y funciones comunes (Gini, asignación D'Hondt) |
| `01_cumplimiento.R` | Cumplimiento de los umbrales por partido y región, cortes de julio y septiembre de 2026; nacionalización de la afiliación; esfuerzo de afiliación |
| `02_importar_2024.R` | Resultados por comuna de 2024: concejales, consejeros regionales, alcaldes y gobernadores |
| `02b_padron_2025.R` | Validación del padrón regional y comparación del umbral anterior y el nuevo |
| `03_exposicion_voto.R` | Proporción de la votación de 2024 de cada partido emitida en regiones expuestas; cargos mayoritarios |
| `04_simulacion_dhondt.R` | Validación D'Hondt, simulación de exclusión, fracción crítica y destino de los escaños |
| `05_figuras_tablas.R` | Figuras del documento |

Paquetes: `dplyr`, `tidyr`, `readr`, `purrr`, `stringr`, `ggplot2`, `readxl`.

## Datos

- `data/raw/`: archivos originales del SERVEL (no se versionan; ver `data/raw/LEEME.md`).
- `data/fuentes/`: afiliados por partido y región, padrón regional, universo de partidos y bloques de los pactos de 2024 (ver `data/fuentes/LEEME.md`).

## Cómo citar

Bottinelli Baltra, L. (2026). *Entrar y permanecer: el doble umbral de afiliación de la reforma al sistema político y la oferta partidaria de 2028* (Documento de trabajo N.° 3). https://doi.org/10.5281/zenodo.23895854

Código y datos: Bottinelli Baltra, L. (2026). *Reforma-Sistema-Politico* (Versión 1.0.0) [Software]. Zenodo. https://doi.org/10.5281/zenodo.23895805

## Licencias

Código: MIT (`LICENSE`). Datos procesados, tablas, figuras y texto: CC BY 4.0 (`LICENSE-DATOS.md`).
