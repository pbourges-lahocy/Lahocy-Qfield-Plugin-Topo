# -*- coding: utf-8 -*-
"""
Lecture des blocs d'un DXF (nomenclature GéoBretagne) et écriture d'un SVG par bloc
pour le rendu QGIS / QField (marqueur SVG paramétré).

Repère du SVG : le point d'insertion du bloc est au centre de la vue
(viewBox -M -M 2M 2M, M = demi-taille en mètres) ; l'axe X du bloc (direction du
1er vers le 2e point de levé) pointe vers le HAUT du SVG, son axe Y vers la GAUCHE.
Ainsi, avec une rotation QGIS égale au gisement du 1er vers le 2e point (sens
horaire depuis le nord), le bloc se place correctement. La variante « _m » est
la symétrie par rapport à l'axe X (3e point levé à droite de l'axe).

Entités gérées : LINE, LWPOLYLINE (arcs par bulge), POLYLINE/VERTEX, CIRCLE, ARC,
ELLIPSE, HATCH (contours polyligne ou arêtes ligne / arc, remplis), TEXT / MTEXT.
Les arcs sont approchés par des segments (SVG petit et robuste).
"""
import math
import os
import re

BLOCK_RE = re.compile(r"^[A-Z][A-Z]_\d{4}$")


def _entity(lines, start):
    """Couples (code, valeur) d'une entité, dans l'ordre du fichier ; renvoie (liste, index suivant)."""
    pairs = []
    j = start
    n = len(lines) - 1
    while j < n and lines[j].strip() != "0":
        pairs.append((lines[j].strip(), lines[j + 1].strip()))
        j += 2
    return pairs, j


def read_blocks(dxf_path):
    """Renvoie {nom: [(type, [(code, valeur), ...])]} pour les blocs nommés selon le standard."""
    with open(dxf_path, encoding="latin-1") as f:
        lines = f.read().split("\n")
    blocks = {}
    i, cur = 0, None
    n = len(lines) - 1
    while i < n:
        code, val = lines[i].strip(), lines[i + 1].strip()
        if code == "0" and val == "BLOCK":
            pairs, j = _entity(lines, i + 2)
            name = next((v for c, v in pairs if c == "2"), "")
            cur = name if BLOCK_RE.match(name) else None
            if cur:
                blocks[cur] = []
            i = j
            continue
        if code == "0" and val == "ENDBLK":
            cur = None
        elif code == "0" and cur:
            pairs, j = _entity(lines, i + 2)
            blocks[cur].append((val, pairs))
            i = j
            continue
        i += 2
    return blocks


# ------------------------------------------------------------------ géométrie (repère du bloc, y vers le haut)

def _first(pairs, code, default=0.0):
    for c, v in pairs:
        if c == code:
            try:
                return float(v)
            except ValueError:
                return default
    return default


def _arc_points(cx, cy, r, a0, a1, seg_deg=10.0):
    """Points d'un arc de a0 à a1 (degrés, sens trigonométrique)."""
    while a1 <= a0:
        a1 += 360.0
    steps = max(2, int((a1 - a0) / seg_deg) + 1)
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * k / steps)),
             cy + r * math.sin(math.radians(a0 + (a1 - a0) * k / steps))) for k in range(steps + 1)]


def _bulge_points(p1, p2, bulge):
    """Points d'un segment de polyligne à bulge (arc), p1 exclu, p2 inclus."""
    if abs(bulge) < 1e-9:
        return [p2]
    (x1, y1), (x2, y2) = p1, p2
    chord = math.hypot(x2 - x1, y2 - y1)
    if chord < 1e-12:
        return [p2]
    theta = 4.0 * math.atan(abs(bulge))         # angle au centre
    r = chord / (2.0 * math.sin(theta / 2.0))
    mx, my = (x1 + x2) / 2.0, (y1 + y2) / 2.0
    h = math.sqrt(max(r * r - (chord / 2.0) ** 2, 0.0))
    nx, ny = -(y2 - y1) / chord, (x2 - x1) / chord  # normale à gauche du segment
    # centre : à gauche si bulge > 0 et angle < 180°, sinon à droite (et inversement)
    left = (bulge > 0) == (theta <= math.pi)
    cx, cy = (mx + h * nx, my + h * ny) if left else (mx - h * nx, my - h * ny)
    a0 = math.degrees(math.atan2(y1 - cy, x1 - cx))
    a1 = math.degrees(math.atan2(y2 - cy, x2 - cx))
    if bulge > 0:
        pts = _arc_points(cx, cy, r, a0, a1)
    else:
        pts = _arc_points(cx, cy, r, a1, a0)[::-1]
    return pts[1:]


def _polyline(verts, closed):
    """verts : [(x, y, bulge)] -> points (le bulge s'applique au segment qui suit le sommet)."""
    if not verts:
        return []
    pts = [(verts[0][0], verts[0][1])]
    for k in range(1, len(verts)):
        pts += _bulge_points((verts[k - 1][0], verts[k - 1][1]), (verts[k][0], verts[k][1]), verts[k - 1][2])
    if closed and len(verts) > 2:
        pts += _bulge_points((verts[-1][0], verts[-1][1]), (verts[0][0], verts[0][1]), verts[-1][2])
    return pts


def _lw_vertices(pairs):
    """Sommets d'une LWPOLYLINE dans l'ordre : (x, y, bulge)."""
    verts = []
    for c, v in pairs:
        if c == "10":
            verts.append([float(v), 0.0, 0.0])
        elif c == "20" and verts:
            verts[-1][1] = float(v)
        elif c == "42" and verts:
            verts[-1][2] = float(v)
    return [tuple(t) for t in verts]


def _hatch_loops(pairs):
    """Contours d'une HATCH lus séquentiellement : boucles polyligne (92 & 2) ou arêtes (72 : 1 ligne, 2 arc)."""
    loops = []
    i, n = 0, len(pairs)

    def val(k):
        return float(pairs[k][1])

    # aller jusqu'au nombre de boucles (91)
    while i < n and pairs[i][0] != "91":
        i += 1
    if i >= n:
        return loops
    nloops = int(val(i))
    i += 1
    for _ in range(nloops):
        while i < n and pairs[i][0] != "92":
            i += 1
        if i >= n:
            break
        flags = int(val(i))
        i += 1
        if flags & 2:  # polyligne
            has_bulge = closed = False
            nv = 0
            while i < n and pairs[i][0] != "93":
                if pairs[i][0] == "72":
                    has_bulge = val(i) == 1
                if pairs[i][0] == "73":
                    closed = val(i) == 1
                i += 1
            if i < n:
                nv = int(val(i))
                i += 1
            verts = []
            while i < n and len(verts) < nv:
                if pairs[i][0] == "10":
                    x = val(i)
                    y = val(i + 1) if i + 1 < n and pairs[i + 1][0] == "20" else 0.0
                    b = 0.0
                    if has_bulge and i + 2 < n and pairs[i + 2][0] == "42":
                        b = val(i + 2)
                    verts.append((x, y, b))
                i += 1
            pts = _polyline(verts, True)
            if len(pts) >= 3:
                loops.append(pts)
        else:  # arêtes
            while i < n and pairs[i][0] != "93":
                i += 1
            ne = int(val(i)) if i < n else 0
            i += 1
            pts = []
            ok = True
            for _e in range(ne):
                while i < n and pairs[i][0] != "72":
                    i += 1
                if i >= n:
                    ok = False
                    break
                et = int(val(i))
                i += 1
                seg = {}
                while i < n and pairs[i][0] not in ("72", "97", "92", "75", "98"):
                    seg.setdefault(pairs[i][0], []).append(float(pairs[i][1]))
                    i += 1
                if et == 1:
                    pts += [(seg["10"][0], seg["20"][0]), (seg["11"][0], seg["21"][0])]
                elif et == 2:
                    cx, cy, r = seg["10"][0], seg["20"][0], seg["40"][0]
                    a0, a1 = seg["50"][0], seg["51"][0]
                    ccw = seg.get("73", [1])[0] == 1
                    arc = _arc_points(cx, cy, r, a0, a1) if ccw else _arc_points(cx, cy, r, a1, a0)[::-1]
                    pts += arc
                else:
                    ok = False
            if ok and len(pts) >= 3:
                loops.append(pts)
        # fin de boucle : 97 + références 330
        while i < n and pairs[i][0] in ("97", "330"):
            i += 1
    return loops


def block_shapes(entities):
    """Convertit les entités en formes : {'lines': [[(x,y)...]], 'fills': [[(x,y)...]], 'texts': [(x,y,h,rot,txt)]}."""
    lines, fills, texts = [], [], []
    poly = None
    for typ, pairs in entities:
        if typ == "LINE":
            lines.append([(_first(pairs, "10"), _first(pairs, "20")), (_first(pairs, "11"), _first(pairs, "21"))])
        elif typ == "LWPOLYLINE":
            verts = _lw_vertices(pairs)
            if verts:
                lines.append(_polyline(verts, int(_first(pairs, "70")) & 1 == 1))
        elif typ == "POLYLINE":
            poly = {"verts": [], "closed": int(_first(pairs, "70")) & 1 == 1}
        elif typ == "VERTEX" and poly is not None:
            poly["verts"].append((_first(pairs, "10"), _first(pairs, "20"), _first(pairs, "42")))
        elif typ == "SEQEND" and poly is not None:
            if poly["verts"]:
                lines.append(_polyline(poly["verts"], poly["closed"]))
            poly = None
        elif typ == "CIRCLE":
            lines.append(_arc_points(_first(pairs, "10"), _first(pairs, "20"), _first(pairs, "40"), 0.0, 360.0))
        elif typ == "ARC":
            lines.append(_arc_points(_first(pairs, "10"), _first(pairs, "20"), _first(pairs, "40"), _first(pairs, "50"), _first(pairs, "51")))
        elif typ == "ELLIPSE":
            cx, cy = _first(pairs, "10"), _first(pairs, "20")
            ax, ay = _first(pairs, "11"), _first(pairs, "21")
            ratio = _first(pairs, "40", 1.0)
            p0, p1 = _first(pairs, "41"), _first(pairs, "42", 2 * math.pi)
            a = math.hypot(ax, ay)
            b = a * ratio
            rot = math.atan2(ay, ax)
            pts = []
            for k in range(49):
                t = p0 + (p1 - p0) * k / 48
                ex, ey = a * math.cos(t), b * math.sin(t)
                pts.append((cx + ex * math.cos(rot) - ey * math.sin(rot), cy + ex * math.sin(rot) + ey * math.cos(rot)))
            lines.append(pts)
        elif typ == "HATCH":
            fills += _hatch_loops(pairs)
        elif typ in ("TEXT", "MTEXT"):
            txt = "".join(v for c, v in pairs if c == "3") + next((v for c, v in pairs if c == "1"), "")
            txt = re.sub(r"\\[A-Za-z][^;]*;|[{}]", "", txt).replace("\\P", " ")
            try:
                txt = txt.encode("latin-1").decode("utf-8")   # textes UTF-8 dans un DXF lu en latin-1
            except (UnicodeEncodeError, UnicodeDecodeError):
                pass
            if txt.strip():
                rot = _first(pairs, "50")
                if typ == "MTEXT" and any(c == "11" for c, v in pairs):
                    rot = math.degrees(math.atan2(_first(pairs, "21"), _first(pairs, "11")))
                texts.append((_first(pairs, "10"), _first(pairs, "20"), _first(pairs, "40", 0.1), rot, txt.strip()))
    return {"lines": lines, "fills": fills, "texts": texts}


def block_extent(shapes):
    xs, ys = [], []
    for poly in shapes["lines"] + shapes["fills"]:
        for x, y in poly:
            xs.append(x)
            ys.append(y)
    for x, y, h, rot, txt in shapes["texts"]:
        xs += [x, x + 0.6 * h * len(txt)]
        ys += [y, y + h]
    if not xs:
        return None
    return (min(xs), max(xs), min(ys), max(ys))


# ------------------------------------------------------------------ SVG

def _fmt(v):
    return ("%.4f" % v).rstrip("0").rstrip(".") if abs(v) > 1e-9 else "0"


def _esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def write_svg(path, shapes, half, mirror=False, stroke="#000000", fill="#000000"):
    """Écrit le SVG d'un bloc. half = demi-taille de la vue (m). Axe X du bloc vers le haut."""
    def tr(p):
        x, y = p
        return ((y if mirror else -y), -x)

    def path_of(pts, close=False):
        segs = []
        for k, p in enumerate(pts):
            sx, sy = tr(p)
            segs.append(("M" if k == 0 else "L") + _fmt(sx) + " " + _fmt(sy))
        return " ".join(segs) + (" Z" if close else "")

    sw = max(half * 0.03, 0.004)
    out = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="%s %s %s %s" width="%s" height="%s">'
           % (_fmt(-half), _fmt(-half), _fmt(2 * half), _fmt(2 * half), _fmt(2 * half), _fmt(2 * half))]
    if shapes["fills"]:
        out.append('<g fill="param(fill) %s" fill-opacity="0.25" stroke="none">' % fill)
        for poly in shapes["fills"]:
            out.append('<path d="%s"/>' % path_of(poly, True))
        out.append("</g>")
    out.append('<g fill="none" stroke="param(outline) %s" stroke-width="param(outline-width) %s" stroke-linecap="round" stroke-linejoin="round">' % (stroke, _fmt(sw)))
    for poly in shapes["lines"]:
        if not poly:
            continue
        closed = len(poly) > 2 and abs(poly[0][0] - poly[-1][0]) < 1e-9 and abs(poly[0][1] - poly[-1][1]) < 1e-9
        out.append('<path d="%s"/>' % path_of(poly[:-1] if closed else poly, closed))
    out.append("</g>")
    if shapes["texts"]:
        out.append('<g font-family="sans-serif" fill="param(outline) %s" stroke="none">' % stroke)
        for x, y, h, rot, txt in shapes["texts"]:
            sx, sy = tr((x, y))
            ang = -90.0 - rot if not mirror else -90.0 + rot
            out.append('<text x="%s" y="%s" font-size="%s" transform="rotate(%s %s %s)">%s</text>'
                       % (_fmt(sx), _fmt(sy), _fmt(h), _fmt(ang), _fmt(sx), _fmt(sy), _esc(txt)))
        out.append("</g>")
    out.append("</svg>\n")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))


def export_blocks(dxf_path, out_dir, max_half=25.0):
    """Génère <ID>.svg et <ID>_m.svg pour chaque bloc ; renvoie {ID: {xmin, xmax, ymin, ymax, half}}."""
    os.makedirs(out_dir, exist_ok=True)
    dims = {}
    for name, ents in read_blocks(dxf_path).items():
        shapes = block_shapes(ents)
        # garde-fou : une forme aberrante (contour mal lu) ne doit pas dilater le bloc
        for key in ("lines", "fills"):
            shapes[key] = [poly for poly in shapes[key] if all(abs(x) < max_half and abs(y) < max_half for x, y in poly)]
        ext = block_extent(shapes)
        if ext is None:
            shapes = {"lines": [_arc_points(0, 0, 0.1, 0, 360)], "fills": [], "texts": []}
            ext = (-0.1, 0.1, -0.1, 0.1)
        xmin, xmax, ymin, ymax = ext
        half = max(abs(xmin), abs(xmax), abs(ymin), abs(ymax)) * 1.05 + 0.01
        write_svg(os.path.join(out_dir, name + ".svg"), shapes, half, mirror=False)
        write_svg(os.path.join(out_dir, name + "_m.svg"), shapes, half, mirror=True)
        dims[name] = {"xmin": xmin, "xmax": xmax, "ymin": ymin, "ymax": ymax, "half": half}
    return dims


if __name__ == "__main__":
    import sys
    d = export_blocks(sys.argv[1], sys.argv[2])
    big = sorted(d.items(), key=lambda kv: -kv[1]["half"])[:5]
    print(len(d), "blocs écrits dans", sys.argv[2], "; plus grands :", [(k, round(v["half"], 2)) for k, v in big])
