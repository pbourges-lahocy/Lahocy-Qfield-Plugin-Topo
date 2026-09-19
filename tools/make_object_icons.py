# -*- coding: utf-8 -*-
"""
Icônes de la palette dessinées à partir du catalogue (couleur du standard) :
  - symboles : rendu du SVG du bloc (blocs/<ID>.svg) dans la couleur de l'objet,
    avec le nombre de points de levé en badge ;
  - linéaires : trait avec les tirets et les textes du type de ligne ;
  - hachures : carré rempli du motif ;
  - textes : lettres.
À lancer avec le Python de QGIS (Qt) :
    C:\\OSGeo4W\\bin\\python-qgis-ltr.bat tools\\make_object_icons.py plugin\\theme
"""
import json
import math
import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from qgis.PyQt.QtCore import QByteArray, QPointF, QRectF, Qt  # noqa: E402
from qgis.PyQt.QtGui import QColor, QFont, QGuiApplication, QImage, QPainter, QPen, QBrush, QPainterPath  # noqa: E402
from qgis.PyQt.QtSvg import QSvgRenderer  # noqa: E402

SIZE = 96


def new_image():
    img = QImage(SIZE, SIZE, QImage.Format.Format_ARGB32 if hasattr(QImage, "Format") else QImage.Format_ARGB32)
    img.fill(QColor("white"))
    return img


def painter(img):
    p = QPainter(img)
    try:
        p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        p.setRenderHint(QPainter.RenderHint.TextAntialiasing, True)
    except AttributeError:
        p.setRenderHint(QPainter.Antialiasing, True)
    return p


def badge(p, text):
    if not text:
        return
    p.setPen(QPen(QColor("#404040")))
    f = QFont("Arial", 9)
    f.setBold(True)
    p.setFont(f)
    p.drawText(QRectF(SIZE - 26, SIZE - 18, 24, 16), Qt.AlignmentFlag.AlignRight if hasattr(Qt, "AlignmentFlag") else Qt.AlignRight, text)


def icon_symbole(o, theme_dir, color):
    svg_path = os.path.join(theme_dir, "blocs", o["code"] + ".svg")
    if not os.path.exists(svg_path):
        return None
    svg = open(svg_path, encoding="utf-8").read()
    svg = svg.replace("param(outline) #000000", color).replace("param(fill) #000000", color)
    # trait visible quelle que soit la taille du bloc : ~2,5 % de la vue
    import re
    m = re.search(r'viewBox="(-?[\d.]+) (-?[\d.]+) ([\d.]+) ([\d.]+)"', svg)
    if m:
        w = float(m.group(3))
        svg = re.sub(r'stroke-width="param\(outline-width\) [\d.]+"', 'stroke-width="%.4f"' % (w * 0.025), svg)
    img = new_image()
    p = painter(img)
    r = QSvgRenderer(QByteArray(svg.encode("utf-8")))
    r.render(p, QRectF(8, 8, SIZE - 16, SIZE - 16))
    pts = (o.get("methode") or {}).get("points", 1)
    badge(p, str(pts) + " pts" if pts and pts > 1 else "")
    p.end()
    return img


def icon_lineaire(o, color):
    st = o.get("style") or {}
    img = new_image()
    p = painter(img)
    pen = QPen(QColor(color))
    pen.setWidthF(3.0)
    pen.setCapStyle(Qt.PenCapStyle.FlatCap if hasattr(Qt, "PenCapStyle") else Qt.FlatCap)
    lt = st.get("ltype")
    x0, y0, x1, y1 = 6.0, 62.0, 90.0, 34.0
    length_px = math.hypot(x1 - x0, y1 - y0)
    ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
    texts = []
    if lt and lt.get("elements"):
        total = float(lt.get("longueur") or 1.0) or 1.0
        scale = length_px / (1.15 * total)      # px par mètre : ~1 motif dans l'icône
        dashes = []
        pos = 0.0
        for e in lt["elements"]:
            L = float(e.get("len", 0))
            if e.get("type") == "text":
                texts.append((pos + abs(L) / 2.0, e.get("text", ""), float(e.get("echelle", 0.254)) or 0.254))
                kind, l = "gap", abs(L)
            elif L > 0:
                kind, l = "dash", L
            elif L < 0:
                kind, l = "gap", -L
            else:
                kind, l = "dash", 0.02
            want_dash = (len(dashes) % 2 == 0)
            if (kind == "dash") == want_dash:
                dashes.append(l)
            elif dashes:
                dashes[-1] += l
            else:
                dashes.extend([0.0, l])
            pos += abs(L)
        if len(dashes) % 2 == 1:
            dashes.append(0.0)
        if any(v > 0 for v in dashes[1::2]):
            pen.setDashPattern([max(v * scale / 3.0, 0.1) for v in dashes])
        p.setPen(pen)
        p.drawLine(QPointF(x0, y0), QPointF(x1, y1))
        for offset, text, h in texts:
            if not text.strip():
                continue
            t = offset * scale / length_px
            cx, cy = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            p.save()
            p.translate(cx, cy)
            p.rotate(ang)
            f = QFont("Arial", max(7, min(12, int(h * scale * 0.9))))
            p.setFont(f)
            p.setPen(QPen(QColor(color)))
            p.drawText(QRectF(-30, -8, 60, 16), Qt.AlignmentFlag.AlignCenter if hasattr(Qt, "AlignmentFlag") else Qt.AlignCenter, text)
            p.restore()
    else:
        p.setPen(pen)
        p.drawLine(QPointF(x0, y0), QPointF(x1, y1))
    p.end()
    return img


def icon_hachure(o, color):
    st = o.get("style") or {}
    h = st.get("hachure") or {}
    img = new_image()
    p = painter(img)
    rect = QRectF(10, 18, 76, 60)
    p.setPen(QPen(QColor(color), 2))
    p.drawRect(rect)
    p.setClipRect(rect)
    lignes = h.get("lignes") or [[45, 0, 0, 0, 1]]
    sc = float(h.get("echelle") or 1.0)
    spacings = [abs(float(l[4])) * sc for l in lignes if abs(float(l[4])) > 0]
    px_per_m = 9.0 / min(spacings) if spacings else 9.0
    for ln in lignes:
        angle = float(ln[0]) + float(h.get("angle", 0))
        dy = abs(float(ln[4])) * sc * px_per_m or 9.0
        dashes = [abs(float(v)) * sc * px_per_m for v in ln[5:]]
        pen = QPen(QColor(color), 1.2)
        if dashes and any(dashes[1::2]):
            pen.setDashPattern([max(v / 1.2, 0.1) for v in (dashes + ([0.0] if len(dashes) % 2 else []))])
        p.setPen(pen)
        a = math.radians(angle)
        ux, uy = math.cos(a), -math.sin(a)      # direction de la ligne (y écran vers le bas)
        nx, ny = -uy, ux                        # normale
        cx, cy = rect.center().x(), rect.center().y()
        k = -12
        while k <= 12:
            ox, oy = cx + nx * dy * k, cy + ny * dy * k
            p.drawLine(QPointF(ox - ux * 120, oy - uy * 120), QPointF(ox + ux * 120, oy + uy * 120))
            k += 1
    p.end()
    return img


def icon_texte(o, color):
    img = new_image()
    p = painter(img)
    f = QFont("Arial", 26)
    f.setItalic(True)
    p.setFont(f)
    p.setPen(QPen(QColor(color)))
    p.drawText(QRectF(0, 0, SIZE, SIZE), Qt.AlignmentFlag.AlignCenter if hasattr(Qt, "AlignmentFlag") else Qt.AlignCenter, "Abc")
    p.end()
    return img


def main():
    theme_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join("plugin", "theme")
    app = QGuiApplication([])  # noqa: F841  (polices, rendu)
    theme = json.load(open(os.path.join(theme_dir, "theme.json"), encoding="utf-8"))
    icons_dir = os.path.join(theme_dir, "icons")
    os.makedirs(icons_dir, exist_ok=True)
    n = 0
    for code, o in theme["objets"].items():
        fam = o.get("famille")
        color = (o.get("style") or {}).get("couleur", "#202020")
        if fam in ("symbole", "escalier"):
            img = icon_symbole(o, theme_dir, color)
        elif fam == "lineaire":
            img = icon_hachure(o, color) if (o.get("style") or {}).get("hachure") else icon_lineaire(o, color)
        elif fam == "texte":
            img = icon_texte(o, color)
        else:
            img = None
        if img is not None:
            img.save(os.path.join(icons_dir, code + ".png"), "PNG")
            n += 1
    print(n, "icônes écrites dans", icons_dir)


if __name__ == "__main__":
    main()
