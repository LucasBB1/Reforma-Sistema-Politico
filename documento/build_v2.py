# -*- coding: utf-8 -*-
# Arma el Documento de trabajo N.° 3 a partir de la plantilla de La Reina y los borradores en markdown.
import docx, copy, re, glob
from docx.shared import Pt, Inches, Emu
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

W = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
import sys
TPL = '/home/claude/entregables/Bottinelli-Baltra_2026_La-Reina-2028.docx'
OUT = sys.argv[1] if len(sys.argv) > 1 else '/home/claude/entregables/Bottinelli-Baltra_2026_Reforma-sistema-politico.docx'
DOI_DOC = '24030166'
DOI_COD = 'XXXXXXXX'
REPO = 'https://github.com/LucasBB1/Reforma-Sistema-Politico'
TITULO = 'Entrar y permanecer: el doble umbral de afiliación de la reforma al sistema político y la oferta partidaria de 2028'

MD = open('/home/claude/repo_reforma/documento/manuscrito.md').read()
md = {'Resumen': MD}

# ---------- plantilla ----------
d = docx.Document(TPL)
body = d.element.body
P = d.paragraphs
T = lambda el: ''.join(x.text or '' for x in el.iter() if x.tag == W + 't')

from docx.opc.constants import RELATIONSHIP_TYPE as RT

def separar_url(parts):
    out = []
    for txt, f in parts:
        for tok in re.split(r'(https?://\S+)', txt):
            if not tok: continue
            if tok.startswith('http'):
                m = re.match(r'(.*?)([.,;:)]*)$', tok)
                out.append((m.group(1), dict(f, url=m.group(1))))
                if m.group(2): out.append((m.group(2), f))
            else:
                out.append((tok, f))
    return out

def set_text(p, parts):
    parts = separar_url(parts)
    """parts: lista de (texto, dict) con claves b/i; reutiliza el formato del primer run."""
    runs = p.runs
    base = copy.deepcopy(runs[0]._r) if runs else None
    for r in runs: r._r.getparent().remove(r._r)
    for txt, f in parts:
        r = copy.deepcopy(base)
        for c in list(r):
            if c.tag != W + 'rPr': r.remove(c)
        rp = r.find(W + 'rPr')
        if rp is not None:
            for tag in ('b', 'bCs', 'i', 'iCs', 'vertAlign'):
                for x in rp.findall(W + tag): rp.remove(x)
        t = OxmlElement('w:t'); t.text = txt; t.set(qn('xml:space'), 'preserve'); r.append(t)
        if f.get('url'):
            h = OxmlElement('w:hyperlink')
            h.set(qn('r:id'), p.part.relate_to(f['url'], RT.HYPERLINK, is_external=True))
            h.append(r); p._p.append(h)
        else:
            p._p.append(r)
        run = docx.text.run.Run(r, p)
        if f.get('b'): run.bold = True
        if f.get('i'): run.italic = True
        if f.get('url'):
            run.font.color.rgb = docx.shared.RGBColor(0x05, 0x63, 0xC1); run.font.underline = True
        if f.get('sub'): run.font.subscript = True

def inline(s):
    """Convierte **negrita** y *cursiva* en partes."""
    parts = []
    for tok in re.split(r'(\*\*[^*]+\*\*|\*[^*]+\*)', s):
        if not tok: continue
        if tok.startswith('**'): parts.append((tok[2:-2], {'b': 1}))
        elif tok.startswith('*'): parts.append((tok[1:-1], {'i': 1}))
        else: parts.append((tok, {}))
    return parts

# plantillas de párrafo
tpl = {
    'h1': P[36]._p, 'h2': P[43]._p, 'body': P[37]._p, 'ref': P[154]._p,
    'lab': P[76]._p, 'tit': P[77]._p, 'nota': P[78]._p, 'draw': P[81]._p,
    'li': P[25]._p,
}
tpl = {k: copy.deepcopy(v) for k, v in tpl.items()}

def newp(kind, parts, anchor):
    el = copy.deepcopy(tpl[kind])
    anchor.addnext(el)
    p = docx.text.paragraph.Paragraph(el, d._body)
    if kind != 'draw': set_text(p, parts)
    return p, el

# ---------- portada y preliminares ----------
set_text(P[1], [('Documento de trabajo N.° 3 · Versión 2.0', {})])
set_text(P[4], [(TITULO, {'b': 1})])
set_text(P[12], [(f'Datos y código: {REPO}. Todas las cifras provienen de datos oficiales del SERVEL y son reproducibles con el código publicado. La versión 2.0 corrige el umbral vigente antes de la reforma, que la versión 1.0 calculó sobre el total de votantes y sin el mínimo de 500 afiliados, y precisa el calendario de 2028 y la interpretación de la norma sobre las regiones contiguas.', {'i': 1})])

res = re.search(r'## Resumen\n\n(.+?)\n\n\*\*Palabras clave:\*\* (.+?)\n', md['Resumen'], re.S)
abs_ = re.search(r'## Abstract\n\n(.+?)\n\n\*\*Keywords:\*\* (.+?)\n', md['Resumen'], re.S)
set_text(P[18], [(res.group(1).strip(), {})])
P[19]._p.getparent().remove(P[19]._p)
set_text(P[20], [('Palabras clave:', {'i': 1}), (' ' + res.group(2).strip(), {})])
set_text(P[22], [(abs_.group(1).strip(), {})])
set_text(P[23], [('Keywords:', {'i': 1}), (' ' + abs_.group(2).strip(), {})])
set_text(P[24], [('Hallazgos principales', {})])

HALL = [
    ('El umbral efectivo sube 70%', ': al pasar de 0,25% de los votos válidamente emitidos a 0,3% del padrón, la cifra de afiliados exigida aumenta 70,2%, y no el 20% que sugiere el cambio de porcentaje.'),
    ('Cuatro partidos no reúnen ocho regiones', ': el Partido Liberal, Evópoli, la FRVS y el Partido Cristiano de Chile están bajo el umbral de mantención (0,15%) en tantas regiones que no alcanzan el mínimo legal; con la regla vigente, los tres primeros sí lo alcanzarían.'),
    ('Entrar es mucho más difícil que permanecer', ': con el umbral de mantención fallan 4 de los 15 partidos constituidos; con el de constitución fallarían 13.'),
    ('El riesgo depende del tamaño, no de la concentración', ': el número total de afiliados explica casi toda la variación en las regiones bajo el umbral, mientras que la nacionalización de la afiliación no la explica.'),
    ('La reforma también retira partidos grandes de algunas regiones', ': el Partido Republicano está bajo el umbral en siete regiones, de donde provino el 81% de su voto de 2024 en concejales; el PPD, el PDC y el Partido Radical tienen entre 40% y 54% de su voto expuesto.'),
    ('La exclusión tiene un efecto mecánico', ': en la simulación D\'Hondt, los pactos pierden concejales en una parte importante de las comunas expuestas incluso si la mayoría de los electores del partido excluido se queda en el pacto, y dos tercios de esos escaños irían a otros bloques.'),
]
for i, (a_, b_) in enumerate(HALL):
    set_text(P[25 + i], [(a_, {'b': 1}), (b_, {})])

set_text(P[32], [('Bottinelli Baltra, L. (2026). ', {}), (TITULO, {'i': 1}), (f' (Documento de trabajo N.° 3, versión 2.0). https://doi.org/10.5281/zenodo.{DOI_DOC}', {})])
set_text(P[34], [(f'Los datos procesados y el código en R (scripts 00 a 05) están disponibles en {REPO} bajo licencia MIT (código) y CC BY 4.0 (datos, tablas, figuras y texto). Los archivos originales del SERVEL se descargan de su sitio web; las tablas de afiliación por partido y región, el padrón regional y el universo de partidos usados en el análisis se incluyen en la carpeta data/fuentes del repositorio. El código y los datos de esta versión están archivados en Zenodo: https://doi.org/10.5281/zenodo.{DOI_COD}.', {})])
set_text(P[35], [(TITULO, {'b': 1})])

# borrar todo el cuerpo antiguo (desde "1. Introducción" hasta antes del sectPr final)
start = P[36]._p
el = start
while el is not None and el.tag != W + 'sectPr':
    nxt = el.getnext(); body.remove(el); el = nxt
anchor = P[35]._p

# ---------- tablas ----------
def border(tcPr, sides):
    b = OxmlElement('w:tcBorders')
    for s in ('top', 'left', 'bottom', 'right'):
        e = OxmlElement(f'w:{s}')
        if s in sides: e.set(qn('w:val'), 'single'); e.set(qn('w:sz'), '6'); e.set(qn('w:color'), '000000')
        else: e.set(qn('w:val'), 'nil')
        b.append(e)
    tcPr.append(b)

def make_table(rows, anchor, size=10, widths=None):
    ncol = len(rows[0])
    total = 9360
    if widths is None:
        lens = [max(min(len(r[j]), 60) for r in rows) + 4 for j in range(ncol)]
        widths = [int(total * l / sum(lens)) for l in lens]
    tbl = OxmlElement('w:tbl')
    tp = OxmlElement('w:tblPr')
    tw = OxmlElement('w:tblW'); tw.set(qn('w:w'), str(total)); tw.set(qn('w:type'), 'dxa'); tp.append(tw)
    lay = OxmlElement('w:tblLayout'); lay.set(qn('w:type'), 'fixed'); tp.append(lay)
    cm = OxmlElement('w:tblCellMar')
    for s, v in (('left', 80), ('right', 80)):
        e = OxmlElement(f'w:{s}'); e.set(qn('w:w'), str(v)); e.set(qn('w:type'), 'dxa'); cm.append(e)
    tp.append(cm); tbl.append(tp)
    g = OxmlElement('w:tblGrid')
    for w in widths:
        c = OxmlElement('w:gridCol'); c.set(qn('w:w'), str(w)); g.append(c)
    tbl.append(g)
    for i, row in enumerate(rows):
        tr = OxmlElement('w:tr')
        trPr = OxmlElement('w:trPr')
        if i == 0: trPr.append(OxmlElement('w:tblHeader'))
        cs = OxmlElement('w:cantSplit'); trPr.append(cs)
        tr.append(trPr)
        for j, txt in enumerate(row):
            tc = OxmlElement('w:tc'); tcPr = OxmlElement('w:tcPr')
            w_ = OxmlElement('w:tcW'); w_.set(qn('w:w'), str(widths[j])); w_.set(qn('w:type'), 'dxa'); tcPr.append(w_)
            sides = set()
            if i == 0: sides |= {'top', 'bottom'}
            if i == len(rows) - 1: sides.add('bottom')
            border(tcPr, sides)
            va = OxmlElement('w:vAlign'); va.set(qn('w:val'), 'center'); tcPr.append(va)
            tc.append(tcPr)
            p = OxmlElement('w:p'); pPr = OxmlElement('w:pPr')
            if len(rows) <= 15 or i == 0: pPr.append(OxmlElement('w:keepNext'))
            sp = OxmlElement('w:spacing'); sp.set(qn('w:before'), '40'); sp.set(qn('w:after'), '40'); sp.set(qn('w:line'), '240'); sp.set(qn('w:lineRule'), 'auto'); pPr.append(sp)
            ind = OxmlElement('w:ind'); ind.set(qn('w:firstLine'), '0'); pPr.append(ind)
            jc = OxmlElement('w:jc'); jc.set(qn('w:val'), 'left' if j == 0 or ncol >= 5 and j < 4 and len(txt) > 25 else 'center'); pPr.append(jc)
            p.append(pPr)
            para = docx.text.paragraph.Paragraph(p, d._body)
            tc.append(p)
            for txt_, f in inline(txt):
                r = para.add_run(txt_); r.font.size = Pt(size)
                if f.get('i'): r.italic = True
                if f.get('b'): r.bold = True
            tr.append(tc)
        tbl.append(tr)
    anchor.addnext(tbl)
    return tbl

def parse_table(lines):
    rows = []
    for l in lines:
        cells = [c.strip() for c in l.strip().strip('|').split('|')]
        if all(re.fullmatch(r'-+', c) for c in cells): continue
        rows.append(cells)
    return rows

# ---------- figuras ----------
FIG = {
    1: ('/home/claude/repo_reforma/output/figuras/fig1_matriz_cumplimiento.png', 'Situación de cada partido respecto de los umbrales de afiliación, por región, al 30 de septiembre de 2026',
        'Tasa de afiliación sobre el padrón electoral definitivo de 2025. Bajo 0,15%, el partido no podrá actuar en la región si no reúne los afiliados faltantes dentro del plazo transitorio. Partidos ordenados según el número de regiones sobre el umbral de mantención. Elaboración propia con datos del SERVEL (2025, 2026a, 2026b).'),
    2: ('/home/claude/repo_reforma/output/figuras/fig2_doble_umbral.png', 'Regiones en que cada partido cumple el umbral de mantención y el de constitución',
        'La línea punteada marca el mínimo de ocho regiones. El umbral de constitución (0,3%) rige para partidos nuevos y para la constitución en regiones nuevas; el de mantención (0,15%), para los partidos ya constituidos en cada región. Elaboración propia con datos del SERVEL (2025, 2026a, 2026b).'),
    3: ('/home/claude/repo_reforma/output/figuras/fig3_exposicion_voto.png', 'Proporción de la votación de 2024 de cada partido emitida en regiones donde hoy está expuesto',
        'Votación de los candidatos afiliados. Una región está expuesta si el partido no está constituido en ella o sus afiliados están bajo el 0,15% del padrón al 30 de septiembre de 2026. Elaboración propia con datos del SERVEL (2026a, s. f.).'),
    4: ('/home/claude/repo_reforma/output/figuras/fig4_fraccion_critica.png', 'Fracción crítica de la votación del partido excluido en la elección de concejales',
        'Cada punto es una comuna de una región expuesta en que el pacto pierde un concejal al retirar la votación del partido. La fracción crítica es la menor proporción de esa votación que debe salir del pacto para que pierda el escaño. Se incluyen los partidos con al menos cuatro casos. Elaboración propia con datos del SERVEL (s. f.).'),
}
FIG_AFTER = {
    'Afiliados que votan en el territorio nacional.': [1],
    'El contraste con H4 se observa en la Figura 2.': [2],
    'Votación de los candidatos afiliados a cada partido. Una región': [3],
    'La fracción crítica muestra que el resultado': [4],
}

def add_figure(n, anchor):
    f, tit, nota = FIG[n]
    p, a = newp('lab', [(f'Figura {n}', {'b': 1})], anchor); p.paragraph_format.keep_with_next = True
    p, a = newp('tit', [(tit, {'i': 1})], a); p.paragraph_format.keep_with_next = True
    p, a = newp('draw', [], a)
    for r in list(p.runs): r._r.getparent().remove(r._r)
    p.add_run().add_picture(f, width=Inches(6.3))
    p.paragraph_format.keep_with_next = True
    p, a = newp('nota', [('Nota.', {'i': 1}), (' ' + nota, {})], a)
    return a

# ---------- ecuaciones ----------
EQ = {
    'Retiene': [('Retiene', {'i': 1}), ('ct', {'i': 1, 'sub': 1}), (' = β ', {}), ('Límite', {'i': 1}), ('ct', {'i': 1, 'sub': 1}),
                (' + γ', {}), ('t', {'i': 1, 'sub': 1}), (' + ', {}), ('X', {'i': 1}), ('ct', {'i': 1, 'sub': 1}), ('′δ + ε', {}), ('ct', {'i': 1, 'sub': 1}), ('\t(1)', {})],
    'Y_': [('Y', {'i': 1}), ('cgt', {'i': 1, 'sub': 1}), (' = β (', {}), ('Tratada', {'i': 1}), ('cg', {'i': 1, 'sub': 1}), (' × ', {}),
           ('Límite', {'i': 1}), ('gt', {'i': 1, 'sub': 1}), (') + α', {}), ('cg', {'i': 1, 'sub': 1}), (' + γ', {}), ('gt', {'i': 1, 'sub': 1}),
           (' + ε', {}), ('cgt', {'i': 1, 'sub': 1}), ('\t(2)', {})],
}

def add_eq(key, anchor):
    p, a = newp('body', EQ[key], anchor)
    pf = p.paragraph_format; pf.first_line_indent = 0; pf.alignment = WD_ALIGN_PARAGRAPH.CENTER
    pf.tab_stops.add_tab_stop(Inches(6.5), alignment=2)  # derecha
    pf.alignment = WD_ALIGN_PARAGRAPH.LEFT
    pf.left_indent = Inches(1.0)
    return a

# ---------- títulos de tablas de anexos ----------
ANEXO_TAB = {
    'Anexo A': ('Tabla A1', 'Partidos constituidos, en formación y en trámite'),
    'Anexo B': ('Tabla B1', 'Umbral de mantención antes y después de la reforma, por región'),
    'Anexo C': ('Tabla C1', 'Clasificación de los pactos de 2024 en bloques'),
    'Anexo D': ('Tabla D1', 'Exposición y simulación con independientes del cupo, y alcaldes electos en 2024'),
}

def heading_kind(txt):
    m = re.match(r'^(\d+(?:\.\d+)*)\.?\s+(.*)$', txt)
    if not m: return 'h1', txt
    num, rest = m.groups()
    lvl = num.count('.') + 1
    return ('h1' if lvl == 1 else 'h2' if lvl == 2 else 'h3'), f'{num}. {rest}'

def emit(text, anchor, section_tag=None):
    lines = text.split('\n')
    i = 0; cur_anexo = None; pending_tab = None; in_refs = False
    while i < len(lines):
        l = lines[i]
        if not l.strip(): i += 1; continue
        if l.startswith('Borrador para'): i += 1; continue
        if l.startswith('```'):
            j = i + 1
            while not lines[j].startswith('```'): j += 1
            code = ' '.join(lines[i + 1:j])
            anchor = add_eq('Retiene' if 'Retiene' in code else 'Y_', anchor)
            i = j + 1; continue
        if l.startswith('#'):
            lvl = len(l) - len(l.lstrip('#')); txt = l.lstrip('#').strip()
            if re.match(r'^(1–3|5–7)\.|^Resumen y anexos|^Resumen$|^Abstract$', txt) and lvl == 1: i += 1; continue
            if txt in ('Resumen', 'Abstract'):
                # saltar hasta el siguiente encabezado
                i += 1
                while i < len(lines) and not lines[i].startswith('#'): i += 1
                continue
            if txt == 'Referencias' or txt.startswith('Anexo'):
                p, anchor = newp('h1', [(txt, {})], anchor); p.paragraph_format.page_break_before = True
                in_refs = txt == 'Referencias'
                cur_anexo = txt[:7] if txt.startswith('Anexo') else None
                i += 1; continue
            kind, t2 = heading_kind(txt)
            if kind == 'h3':
                p, anchor = newp('h2', [(t2, {'b': 1, 'i': 1})], anchor)
            else:
                p, anchor = newp(kind, [(t2, {})], anchor)
            i += 1; continue
        if l.startswith('|'):
            j = i
            while j < len(lines) and lines[j].startswith('|'): j += 1
            rows = parse_table(lines[i:j])
            if pending_tab is None and cur_anexo in ANEXO_TAB:
                pending_tab = ANEXO_TAB[cur_anexo]
            if pending_tab:
                p, anchor = newp('lab', [(pending_tab[0], {'b': 1})], anchor); p.paragraph_format.keep_with_next = True
                p, anchor = newp('tit', [(pending_tab[1], {'i': 1})], anchor); p.paragraph_format.keep_with_next = True
                pending_tab = None
            size = 9 if cur_anexo else 10
            widths = None
            if cur_anexo == 'Anexo A': widths = [4200, 1100, 4060]
            if cur_anexo == 'Anexo C': widths = [1700, 7660]
            if len(rows[0]) == 3 and rows[0][0] == 'Trámite': widths = [2600, 2000, 4760]
            if len(rows[0]) >= 7: size = 8.5
            if widths is None and len(rows[0]) >= 5:
                k = len(rows[0]) - 1; first = 2300; rest = (9360 - first) // k
                widths = [first] + [rest] * k
            anchor = make_table(rows, anchor, size=size, widths=widths)
            i = j; continue
        m = re.match(r'^\*\*Tabla (\d+)\.\*\* (.+)$', l)
        if m:
            pending_tab = (f'Tabla {m.group(1)}', m.group(2).strip()); i += 1; continue
        if l.startswith('*Nota.*') or l.startswith('Nota.'):
            rest = re.sub(r'^\*?Nota\.\*?\s*', '', l)
            p, anchor = newp('nota', [('Nota.', {'i': 1}), (' ', {})] + inline(rest), anchor)
            for k, figs in FIG_AFTER.items():
                if rest.startswith(k):
                    for n in figs: anchor = add_figure(n, anchor)
            i += 1; continue
        if l.startswith('- '):
            p, anchor = newp('li', inline(l[2:].strip()), anchor)
            i += 1; continue
        # párrafo normal
        kind = 'ref' if in_refs else 'body'
        p, anchor = newp(kind, inline(l.strip()), anchor)
        for k, figs in FIG_AFTER.items():
            if l.startswith(k):
                for n in figs: anchor = add_figure(n, anchor)
        i += 1
    return anchor

cuerpo = MD[MD.index('## 1. Introducción'):]
anchor = emit(cuerpo, anchor)

# primer párrafo tras encabezado: sangría igual que el resto (APA). Ajuste del primer H1 del cuerpo: sin salto.
d.save(OUT)
print('ok', OUT)
