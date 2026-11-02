# data/fuentes/

Tablas de entrada construidas a partir de documentos oficiales del Servicio Electoral (SERVEL), consolidadas en la planilla de seguimiento del proyecto.

| Archivo | Contenido | Fuente |
|---|---|---|
| `afiliacion_region.csv` | Afiliados por partido y región, cortes al 31 de julio y al 30 de septiembre de 2026; si el partido está constituido en la región | SERVEL, "Total de afiliados a partidos políticos" (https://www.servel.cl/total-de-afiliados-a-partidos-politicos/), corte publicado el 15 de octubre de 2026; SERVEL, "Partidos políticos legalmente constituidos: fecha de constitución en cada región" (23 de julio de 2026) |
| `padron_region.csv` | Padrón electoral definitivo por región, elecciones de 2025 (territorio nacional) | SERVEL, "Padrón definitivo elecciones 2025 en el territorio nacional" (https://www.servel.cl/padron-definitivo-elecciones-2025-en-el-territorio-nacional/), agregado por región |
| `universo_partidos.csv` | Partidos constituidos, en formación y en trámite, con su estado legal | SERVEL, Registro de Partidos Políticos (23 de julio de 2026); resoluciones de disolución (12 de febrero de 2026) |

Los afiliados regionales excluyen a quienes votan en el extranjero, que no cuentan para el umbral de ninguna región; por eso las sumas regionales son algo menores que los totales nacionales publicados.
